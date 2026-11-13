#!/usr/bin/env python3
"""Live dictation for modules/shell/dictation/Dictation.qml.

Usage: dictate.py   (dictate.py --self-test checks the phrase splitter)

Records the default mic with ffmpeg, starts whisper-server on a free port, cuts the speech into phrases at
pauses, types each phrase into the focused window with wtype, and prints one event per line:
  level <dB>       loudest of the last ~100 ms, for the waveform
  partial <text>   the phrase still being spoken, re-transcribed about once a second
  commit <text>    a finished phrase, already typed
  download <0-100> the model is missing and being fetched (first use only; resumes if interrupted)
  error <message>
SIGTERM finishes (the phrase in progress is still typed), SIGINT cancels it. After a few seconds of
silence it stops by itself. ffmpeg and whisper-server die with this process, so nothing stays loaded.
"""

import array
import collections
import ctypes
import io
import math
import os
import queue
import re
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
import wave

RATE = 16000
FRAME = 512  # samples, 32 ms
FRAME_S = FRAME / RATE
SPEECH_DB = -44.0  # RMS above this counts as voice
PAUSE_S = 1.0  # silence that ends a phrase
PREROLL_S = 0.3  # audio kept from before the first voiced frame
MIN_VOICE_S = 0.25  # shorter blips (a click, a cough) are dropped: whisper invents words for them
PARTIAL_EVERY_S = 1.0
MAX_PHRASE_S = 25.0  # whisper sees 30 s windows
IDLE_STOP_S = 4.0  # silence after the last phrase that ends the session
FIRST_WORD_WAIT_S = 8.0
MODEL = os.path.expanduser("~/.local/share/donwaztok/whisper/ggml-large-v3-turbo-q5_0.bin")
MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + os.path.basename(MODEL)
LEVEL_EVERY = 3  # frames per waveform update (~100 ms): faster reads as flicker


def emit(kind, value=""):
    print(f"{kind} {value}".rstrip(), flush=True)


class Segmenter:
    """Splits the frame stream into phrases. feed() returns the jobs it produced: ("partial"|"commit", pcm)."""

    def __init__(self):
        self.t = 0.0
        self.phrase = bytearray()
        self.voiced = 0.0
        self.preroll = collections.deque(maxlen=round(PREROLL_S / FRAME_S))
        self.last_voice = None
        self.last_partial = 0.0

    def feed(self, frame, db):
        self.t += FRAME_S
        if db > SPEECH_DB:
            if not self.phrase:
                self.phrase = bytearray(b"".join(self.preroll))
                self.last_partial = self.t
            self.last_voice = self.t
            self.voiced += FRAME_S
        if not self.phrase:
            self.preroll.append(frame)
            return []
        self.phrase += frame
        if self.t - self.last_voice >= PAUSE_S or len(self.phrase) >= MAX_PHRASE_S * RATE * 2:
            return self.flush()
        speaking = self.last_voice == self.t  # no partials during a pause: the commit is coming
        if speaking and self.t - self.last_partial >= PARTIAL_EVERY_S and self.voiced >= MIN_VOICE_S:
            self.last_partial = self.t
            return [("partial", bytes(self.phrase))]
        return []

    def flush(self):
        jobs = [("commit", bytes(self.phrase))] if self.voiced >= MIN_VOICE_S else []
        self.phrase = bytearray()
        self.voiced = 0.0
        self.preroll.clear()
        return jobs

    def idle(self):
        if self.phrase:
            return False
        if self.last_voice is None:
            return self.t >= FIRST_WORD_WAIT_S
        return self.t - self.last_voice >= IDLE_STOP_S


def level_db(frame):
    samples = array.array("h", frame)
    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) / 32768
    return 20 * math.log10(rms) if rms > 0 else -math.inf


def clean(text):
    # Drop non-speech markers like [BLANK_AUDIO] or (music), and the "..." whisper writes for a hesitation
    # ("do... das"), then join the segments.
    text = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", text)
    text = re.sub(r"\s*(\.{2,}|…)", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text if re.search(r"\w", text) else ""  # a lone "." or "..." is not speech


def transcribe(port, pcm):
    wav = io.BytesIO()
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm)
    b = uuid.uuid4().hex
    body = (
        f'--{b}\r\nContent-Disposition: form-data; name="response_format"\r\n\r\ntext\r\n'
        f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="a.wav"\r\n'
        "Content-Type: audio/wav\r\n\r\n"
    ).encode() + wav.getvalue() + f"\r\n--{b}--\r\n".encode()
    req = urllib.request.Request(
        f"http://127.0.0.1:{port}/inference", body, {"Content-Type": f"multipart/form-data; boundary={b}"}
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return clean(r.read().decode())


def wait_ready(server, port):
    while server.poll() is None:
        try:
            socket.create_connection(("127.0.0.1", port), timeout=1).close()
            return
        except OSError:
            time.sleep(0.05)
    raise RuntimeError(f"whisper-server exited with code {server.returncode} (is the model in place?)")


def worker(jobs, server, port, state):
    try:
        wait_ready(server, port)
        typed = False
        while True:
            kind, pcm = jobs.get()
            if kind == "stop":
                return
            if kind == "partial" and not jobs.empty():
                continue  # a newer partial or the commit is already waiting
            text = transcribe(port, pcm)
            if kind == "partial":
                emit("partial", text)
            elif text:
                emit("commit", text)
                type_text((" " if typed else "") + text)
                typed = True
    except Exception as e:  # report, then let the main loop wind down
        emit("error", str(e).replace("\n", " "))
        state["stop"] = "cancel"


def type_text(text):
    # wtype's virtual keyboard reuses low keycodes, which Hyprland matches against the Escape bind of the
    # "dictation" submap (Dictation.qml), so typing would close the session. Leave the submap meanwhile.
    hypr = ["hyprctl", "-q", "dispatch"]
    subprocess.run(hypr + ['hl.dsp.submap("reset")'], check=False)
    subprocess.run(["wtype", "--", text], check=False)
    subprocess.run(hypr + ['hl.dsp.submap("dictation")'], check=False)


def download_model(state):
    """Fetch MODEL into a .part file (resuming one left by an earlier try), then move it in place."""
    part = MODEL + ".part"
    os.makedirs(os.path.dirname(MODEL), exist_ok=True)
    have = os.path.getsize(part) if os.path.exists(part) else 0
    emit("download", 0)  # before connecting, which can take a second
    req = urllib.request.Request(MODEL_URL, headers={"Range": f"bytes={have}-"} if have else {})
    with urllib.request.urlopen(req, timeout=30) as r, open(part, "ab" if r.status == 206 else "wb") as out:
        have = have if r.status == 206 else 0
        total = have + int(r.headers["Content-Length"])
        shown = -1
        while state["stop"] is None:
            chunk = r.read(1 << 20)
            if not chunk:
                break
            out.write(chunk)
            have += len(chunk)
            if have * 100 // total != shown:
                shown = have * 100 // total
                emit("download", shown)
    if have != total:
        return False  # stopped, or the connection dropped: the next try resumes
    os.replace(part, MODEL)
    return True


def die_with_parent():
    ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG: no orphaned server holding VRAM


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def main():
    state = {"stop": None}
    signal.signal(signal.SIGTERM, lambda *_: state.update(stop="finish"))
    signal.signal(signal.SIGINT, lambda *_: state.update(stop="cancel"))

    if not os.path.exists(MODEL):
        try:
            if not download_model(state):
                if state["stop"] is None:
                    emit("error", "the model download was cut short; try again to resume it")
                return 0 if state["stop"] else 1
        except OSError as e:
            emit("error", f"could not download the model: {e}")
            return 1

    port = free_port()
    try:
        server = subprocess.Popen(
            ["whisper-server", "-m", MODEL, "--port", str(port), "-l", "auto", "-nt", "-sns"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent,
        )
        rec = subprocess.Popen(
            ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-f", "pulse", "-i", "default",
             "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
            stdout=subprocess.PIPE, preexec_fn=die_with_parent,
        )
    except FileNotFoundError as e:
        emit("error", f"{e.filename} not found")
        return 1

    jobs = queue.Queue()
    thread = threading.Thread(target=worker, args=(jobs, server, port, state))
    thread.start()
    seg = Segmenter()
    loudest = []
    while state["stop"] is None and not seg.idle():
        frame = rec.stdout.read(FRAME * 2)
        if len(frame) < FRAME * 2:
            if state["stop"] is None:
                emit("error", "the microphone stopped")
            break
        db = level_db(frame)
        loudest.append(db)
        if len(loudest) == LEVEL_EVERY:
            emit("level", f"{max(loudest):.1f}")
            loudest.clear()
        for job in seg.feed(frame, db):
            jobs.put(job)
    rec.terminate()
    if state["stop"] == "cancel":
        while not jobs.empty():
            jobs.get_nowait()
    else:
        for job in seg.flush():
            jobs.put(job)
    jobs.put(("stop", b""))
    thread.join()
    server.terminate()
    server.wait()
    return 0


def self_test():
    silence, voice = bytes(FRAME * 2), array.array("h", [3000] * FRAME).tobytes()
    seg = Segmenter()
    jobs = []
    for _ in range(10):
        jobs += seg.feed(silence, level_db(silence))
    assert jobs == [] and not seg.idle()
    for _ in range(round(1.5 / FRAME_S)):  # 1.5 s of speech
        jobs += seg.feed(voice, level_db(voice))
    assert [k for k, _ in jobs] == ["partial"], jobs
    for _ in range(round(PAUSE_S / FRAME_S) + 1):
        jobs += seg.feed(silence, level_db(silence))
    assert [k for k, _ in jobs] == ["partial", "commit"]
    assert len(jobs[1][1]) > 1.5 * RATE * 2  # the commit holds the preroll, the speech and the pause
    seg.feed(voice, level_db(voice))  # a 32 ms click is dropped, not transcribed
    assert all(seg.feed(silence, level_db(silence)) == [] for _ in range(round(PAUSE_S / FRAME_S) + 1))
    while not seg.idle():
        seg.feed(silence, level_db(silence))
    assert seg.t - seg.last_voice >= IDLE_STOP_S
    assert clean(" [BLANK_AUDIO] Olá,  mundo (risos) ") == "Olá, mundo"
    assert clean(" . ") == "" and clean("...") == ""
    assert clean("Ainda acontece do... das barrinhas…") == "Ainda acontece do das barrinhas"
    print("ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        sys.exit(main())
