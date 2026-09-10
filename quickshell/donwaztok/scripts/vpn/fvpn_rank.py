#!/usr/bin/env python3
"""Background FastestVPN ranking with separate latency/speed caches."""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SPEED_BYTES = 5_000_000
DOWN_URL = f"https://speed.cloudflare.com/__down?bytes={SPEED_BYTES}"
UP_URL = "https://speed.cloudflare.com/__up"


def real_home() -> str:
    home = os.environ.get("HOME") or str(Path.home())
    pkexec_uid = os.environ.get("PKEXEC_UID")
    sudo_user = os.environ.get("SUDO_USER")
    try:
        import pwd

        if pkexec_uid:
            home = pwd.getpwuid(int(pkexec_uid)).pw_dir
        elif sudo_user:
            home = pwd.getpwnam(sudo_user).pw_dir
    except Exception:
        pass
    return home


def cache_dir() -> Path:
    home = real_home()
    if os.environ.get("PKEXEC_UID") or os.environ.get("SUDO_USER") or os.geteuid() == 0:
        xdg = str(Path(home) / ".cache")
    else:
        xdg = os.environ.get("XDG_CACHE_HOME") or str(Path(home) / ".cache")
    return Path(xdg) / "donwaztok" / "fvpn-cache"


def job_file() -> Path:
    return cache_dir() / "job.json"


def mode_file(mode: str) -> Path:
    return cache_dir() / f"{mode}.json"


def pid_file() -> Path:
    return cache_dir() / "rank.pid"


def _chown_user(path: Path) -> None:
    if os.geteuid() != 0:
        return
    try:
        import pwd

        pkexec_uid = os.environ.get("PKEXEC_UID")
        sudo_user = os.environ.get("SUDO_USER")
        if pkexec_uid:
            pw = pwd.getpwuid(int(pkexec_uid))
        elif sudo_user:
            pw = pwd.getpwnam(sudo_user)
        else:
            return
        os.chown(path, pw.pw_uid, pw.pw_gid)
    except Exception:
        pass


def write_json(path: Path, data: dict) -> None:
    cache_dir().mkdir(parents=True, exist_ok=True)
    _chown_user(cache_dir())
    data["updatedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    tmp = path.with_suffix(path.suffix + ".tmp")
    try:
        tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        tmp.replace(path)
    except PermissionError:
        # Leftover root-owned files from older elevated runs
        try:
            path.unlink(missing_ok=True)
            path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        except Exception as e:
            raise PermissionError(f"cannot write {path}: {e}") from e
    _chown_user(path)


def read_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def parse_ts(value: str | None) -> float | None:
    if not value:
        return None
    try:
        return time.mktime(time.strptime(value, "%Y-%m-%dT%H:%M:%S"))
    except Exception:
        return None


def age_sec(value: str | None) -> int | None:
    ts = parse_ts(value)
    if ts is None:
        return None
    return max(0, int(time.time() - ts))


def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def migrate_legacy() -> None:
    legacy = cache_dir() / "rank.json"
    if not legacy.exists():
        return
    data = read_json(legacy)
    if not data:
        return
    mode = data.get("mode") or "latency"
    if data.get("status") == "done" and data.get("results") and not mode_file(mode).exists():
        write_json(
            mode_file(mode),
            {
                "mode": mode,
                "proto": data.get("proto") or "udp",
                "startedAt": data.get("startedAt"),
                "finishedAt": data.get("updatedAt") or data.get("startedAt"),
                "durationSec": None,
                "results": data.get("results") or [],
            },
        )


def empty_mode() -> dict:
    return {
        "mode": "",
        "updatedAt": None,
        "finishedAt": None,
        "startedAt": None,
        "durationSec": None,
        "ageSec": None,
        "results": [],
        "count": 0,
    }


def summarize_mode(mode: str) -> dict:
    data = read_json(mode_file(mode)) or {}
    finished = data.get("finishedAt") or data.get("updatedAt")
    return {
        "mode": mode,
        "updatedAt": data.get("updatedAt"),
        "finishedAt": finished,
        "startedAt": data.get("startedAt"),
        "durationSec": data.get("durationSec"),
        "ageSec": age_sec(finished),
        "results": data.get("results") or [],
        "count": len(data.get("results") or []),
    }


def read_job() -> dict:
    data = read_json(job_file()) or {
        "status": "idle",
        "mode": "",
        "progress": None,
        "pid": None,
        "error": None,
    }
    pid = data.get("pid")
    if data.get("status") == "running" and isinstance(pid, int) and not pid_alive(pid):
        updated = data.get("updatedAt") or ""
        stale = True
        ts = parse_ts(updated)
        if ts is not None:
            stale = (time.time() - ts) > 20
        if stale:
            data["status"] = "error"
            data["error"] = data.get("error") or "Ranking process stopped unexpectedly"
            write_json(job_file(), data)
    return data


def status() -> dict:
    migrate_legacy()
    job = read_job()
    latency = summarize_mode("latency")
    speed = summarize_mode("speed")
    # Prefer showing the active job mode, else whichever cache is newer.
    view = job.get("mode") if job.get("status") == "running" and job.get("mode") else None
    if not view:
        la = latency.get("ageSec")
        sa = speed.get("ageSec")
        if la is None and sa is None:
            view = "latency"
        elif la is None:
            view = "speed"
        elif sa is None:
            view = "latency"
        else:
            view = "speed" if sa <= la else "latency"
    return {
        "job": job,
        "latency": latency,
        "speed": speed,
        "view": view,
        # Back-compat fields used by older UI briefly:
        "status": job.get("status") or "idle",
        "mode": job.get("mode") or view,
        "progress": job.get("progress"),
        "results": (speed if view == "speed" else latency).get("results") or [],
    }


def stop() -> dict:
    job = read_job()
    pid = job.get("pid")
    if isinstance(pid, int) and pid_alive(pid):
        try:
            os.kill(pid, 15)
            time.sleep(0.3)
            if pid_alive(pid):
                os.kill(pid, 9)
        except OSError:
            pass
    try:
        pid_file().unlink(missing_ok=True)
    except Exception:
        pass
    job = read_job()
    if job.get("status") == "running":
        job["status"] = "stopped"
        job["error"] = None
        job["progress"] = job.get("progress")
        write_json(job_file(), job)
    return {"ok": True}


def parse_remote(conf: Path) -> tuple[str, int] | None:
    try:
        for line in conf.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("remote "):
                parts = line.split()
                if len(parts) >= 3:
                    return parts[1], int(parts[2])
    except Exception:
        return None
    return None


def latency_ms(host: str, port: int) -> float:
    best = None
    for _ in range(2):
        s = socket.socket()
        s.settimeout(1.5)
        t0 = time.perf_counter()
        try:
            s.connect((host, port))
            ms = (time.perf_counter() - t0) * 1000
            best = ms if best is None else min(best, ms)
        except Exception:
            pass
        finally:
            s.close()
    return float(f"{best:.1f}") if best is not None else 9999.0


def measure_throughput() -> tuple[float | None, float | None]:
    """Measure Mbps through the current default route (expected: VPN tunnel)."""
    down = None
    up = None
    ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    try:
        r = subprocess.run(
            [
                "curl",
                "-sS",
                "-L",
                "-A",
                ua,
                "-o",
                "/dev/null",
                "-w",
                "%{speed_download}",
                "--max-time",
                "30",
                DOWN_URL,
            ],
            capture_output=True,
            text=True,
            timeout=35,
        )
        if r.returncode == 0 and r.stdout.strip():
            bps = float(r.stdout.strip())
            if bps > 0:
                down = round((bps * 8) / 1_000_000, 2)
        elif r.stderr:
            with open(cache_dir() / "rank.log", "a", encoding="utf-8") as f:
                f.write(f"download measure failed: {r.stderr.strip()}\n")
    except Exception as e:
        try:
            with open(cache_dir() / "rank.log", "a", encoding="utf-8") as f:
                f.write(f"download measure failed: {e}\n")
        except Exception:
            pass

    payload_path = cache_dir() / "upload.bin"
    try:
        cache_dir().mkdir(parents=True, exist_ok=True)
        size = min(SPEED_BYTES, 2_000_000)
        with open(payload_path, "wb") as f:
            f.write(b"0" * size)
        r = subprocess.run(
            [
                "curl",
                "-sS",
                "-L",
                "-A",
                ua,
                "-o",
                "/dev/null",
                "-w",
                "%{speed_upload}",
                "--max-time",
                "30",
                "-X",
                "POST",
                "-H",
                "Content-Type: application/octet-stream",
                "--data-binary",
                f"@{payload_path}",
                UP_URL,
            ],
            capture_output=True,
            text=True,
            timeout=35,
        )
        if r.returncode == 0 and r.stdout.strip():
            bps = float(r.stdout.strip())
            if bps > 0:
                up = round((bps * 8) / 1_000_000, 2)
        elif r.stderr:
            with open(cache_dir() / "rank.log", "a", encoding="utf-8") as f:
                f.write(f"upload measure failed: {r.stderr.strip()}\n")
    except Exception as e:
        try:
            with open(cache_dir() / "rank.log", "a", encoding="utf-8") as f:
                f.write(f"upload measure failed: {e}\n")
        except Exception:
            pass
    finally:
        try:
            payload_path.unlink(missing_ok=True)
        except Exception:
            pass
    return down, up


def list_servers(proto: str) -> list[tuple[str, Path]]:
    base = Path("/etc/openvpn") / ("udp_files" if proto == "udp" else "tcp_files")
    if not base.is_dir():
        return []
    return [(conf.stem, conf) for conf in sorted(base.glob("*.ovpn"))]


def sort_results(results: list[dict], prefer_speed: bool) -> list[dict]:
    if prefer_speed and any(r.get("downloadMbps") is not None for r in results):
        return sorted(
            results,
            key=lambda r: (
                -(r.get("downloadMbps") if r.get("downloadMbps") is not None else -1),
                r.get("latencyMs") or 9999,
            ),
        )
    return sorted(results, key=lambda r: r.get("latencyMs") if r.get("latencyMs") is not None else 9999)


def fvpn_bin() -> str:
    return str(Path(__file__).resolve().with_name("fvpn"))


def run_fvpn(*args: str) -> bool:
    try:
        r = subprocess.run([fvpn_bin(), *args], capture_output=True, text=True, timeout=90)
        return r.returncode == 0
    except Exception:
        return False


def update_job(**kwargs) -> dict:
    job = read_job()
    job.update(kwargs)
    write_json(job_file(), job)
    return job


def save_mode_cache(mode: str, proto: str, started_at: str, results: list[dict], t0: float) -> None:
    finished = time.strftime("%Y-%m-%dT%H:%M:%S")
    write_json(
        mode_file(mode),
        {
            "mode": mode,
            "proto": proto,
            "startedAt": started_at,
            "finishedAt": finished,
            "durationSec": int(max(0, time.time() - t0)),
            "results": results,
        },
    )


def auth_file() -> Path:
    return Path(real_home()) / ".config" / "fastestvpn" / "auth"


def has_openvpn_caps() -> bool:
    import shutil

    ovpn = shutil.which("openvpn")
    if not ovpn:
        return False
    try:
        r = subprocess.run(["getcap", ovpn], capture_output=True, text=True, timeout=5)
        return "cap_net_admin" in (r.stdout or "")
    except Exception:
        return False


def ensure_openvpn_caps() -> bool:
    if has_openvpn_caps():
        return True
    update_job(
        status="running",
        mode="speed",
        progress={"current": 0, "total": 0, "server": "", "phase": "auth"},
        error=None,
    )
    fvpn = Path(__file__).resolve().parent / "fvpn"
    try:
        r = subprocess.run(
            ["pkexec", str(fvpn), "ensure-caps"],
            capture_output=True,
            text=True,
            timeout=300,
        )
        return r.returncode == 0 and has_openvpn_caps()
    except Exception as e:
        update_job(status="error", error=str(e))
        return False


def runtime_dir() -> Path:
    pkexec_uid = os.environ.get("PKEXEC_UID")
    sudo_uid = os.environ.get("SUDO_UID")
    if pkexec_uid:
        return Path(f"/run/user/{pkexec_uid}")
    if sudo_uid:
        return Path(f"/run/user/{sudo_uid}")
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if xdg:
        return Path(xdg)
    return Path(f"/run/user/{os.getuid()}")


def openvpn_pid_path() -> Path:
    return runtime_dir() / "fvpn.pid"


def openvpn_log_path() -> Path:
    return cache_dir() / "openvpn.log"


def openvpn_extra_args() -> list[str]:
    # Avoid Polkit/DNS hangs: provider pushes dhcp-option DNS + block-outside-dns,
    # which runs dns-updown and asks for admin on every connect.
    return [
        "--dns-updown",
        "disable",
        "--pull-filter",
        "ignore",
        "block-outside-dns",
        "--pull-filter",
        "ignore",
        "dhcp-option DNS",
        "--pull-filter",
        "ignore",
        "dhcp-option DNS6",
        "--script-security",
        "1",
    ]


def openvpn_up(conf: Path, auth: Path) -> bool:
    pid_path = openvpn_pid_path()
    log_path = openvpn_log_path()
    try:
        cache_dir().mkdir(parents=True, exist_ok=True)
        try:
            runtime_dir().mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        if pid_path.exists():
            try:
                os.kill(int(pid_path.read_text().strip()), 15)
            except Exception:
                pass
            pid_path.unlink(missing_ok=True)
            time.sleep(0.3)
        # Legacy root path
        legacy = Path("/run/openvpn-fvpn.pid")
        if legacy.exists():
            try:
                os.kill(int(legacy.read_text().strip()), 15)
            except Exception:
                pass
            legacy.unlink(missing_ok=True)
        cmd = [
            "openvpn",
            "--config",
            str(conf),
            "--auth-user-pass",
            str(auth),
            "--daemon",
            "openvpn-fvpn",
            "--writepid",
            str(pid_path),
            "--log-append",
            str(log_path),
            "--verb",
            "3",
            *openvpn_extra_args(),
        ]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            return False
        for _ in range(40):
            if Path("/sys/class/net/tun0").exists():
                # Wait for redirect-gateway routes before speedtest.
                time.sleep(1.5)
                return True
            if pid_path.exists():
                try:
                    os.kill(int(pid_path.read_text().strip()), 0)
                except OSError:
                    return False
            time.sleep(0.25)
        return Path("/sys/class/net/tun0").exists()
    except Exception:
        return False


def openvpn_down() -> None:
    pid_path = openvpn_pid_path()
    for path in (pid_path, Path("/run/openvpn-fvpn.pid")):
        try:
            if path.exists():
                os.kill(int(path.read_text().strip()), 15)
                time.sleep(0.3)
                try:
                    os.kill(int(path.read_text().strip()), 9)
                except OSError:
                    pass
                path.unlink(missing_ok=True)
        except Exception:
            pass
    subprocess.run(["pkill", "-f", "openvpn --config /etc/openvpn/udp_files/"], capture_output=True)
    subprocess.run(["pkill", "-f", "openvpn --config /etc/openvpn/tcp_files/"], capture_output=True)


def resolve_conf(name: str, proto: str) -> Path | None:
    base = Path("/etc/openvpn") / ("udp_files" if proto == "udp" else "tcp_files")
    for candidate in (f"{name}.ovpn", f"{name}"):
        p = base / candidate
        if p.exists():
            return p
    # try without suffix assumptions
    p = base / f"{name}.ovpn"
    return p if p.exists() else None


def speed_probe(proto: str, servers: list[str]) -> None:
    """Runs as the user (needs openvpn setcap once via fvpn ensure-caps)."""
    auth = auth_file()
    if not auth.exists():
        update_job(status="error", error="credentials missing")
        return

    lat = summarize_mode("latency")
    lat_map = {r["server"]: dict(r) for r in (lat.get("results") or [])}

    speed_started = time.strftime("%Y-%m-%dT%H:%M:%S")
    speed_t0 = time.time()
    total = len(servers)
    probed: list[dict] = []
    ok_count = 0

    for i, name in enumerate(servers, 1):
        update_job(
            status="running",
            mode="speed",
            progress={"current": i, "total": total, "server": name, "phase": "speed"},
            error=None,
        )
        conf = resolve_conf(name, proto)
        openvpn_down()
        time.sleep(0.3)
        ok = bool(conf) and openvpn_up(conf, auth)
        down = up = None
        if ok:
            time.sleep(1.2)
            down, up = measure_throughput()
            openvpn_down()
            time.sleep(0.3)
            if down is not None or up is not None:
                ok_count += 1

        base = lat_map.get(name) or {}
        row = {
            "server": name,
            "latencyMs": base.get("latencyMs"),
            "downloadMbps": down,
            "uploadMbps": up,
        }
        probed.append(row)
        ordered = sort_results(list(probed), prefer_speed=True)
        save_mode_cache("speed", proto, speed_started, ordered, speed_t0)

    openvpn_down()
    ordered = sort_results(list(probed), prefer_speed=True)
    save_mode_cache("speed", proto, speed_started, ordered, speed_t0)
    if ok_count == 0:
        update_job(
            status="error",
            progress={"current": total, "total": total, "server": "", "phase": "done"},
            error="speed probes failed — VPN connected but could not measure (check network/DNS)",
        )
        return
    update_job(
        status="done",
        progress={"current": total, "total": total, "server": "", "phase": "done"},
        error=None,
    )


def run_speed_probe(proto: str, servers: list[str]) -> bool:
    """Probe candidates in-process (no pkexec)."""
    try:
        speed_probe(proto, servers)
        job = read_job()
        return job.get("status") == "done"
    except Exception as e:
        update_job(status="error", error=str(e))
        return False


def worker(mode: str, proto: str) -> None:
    cache_dir().mkdir(parents=True, exist_ok=True)
    _chown_user(cache_dir())
    pid_file().write_text(str(os.getpid()), encoding="utf-8")
    _chown_user(pid_file())

    servers = list_servers(proto)
    total = len(servers)
    results_map: dict[str, dict] = {}
    started_at = time.strftime("%Y-%m-%dT%H:%M:%S")
    t0 = time.time()

    update_job(
        status="running",
        mode=mode,
        proto=proto,
        startedAt=started_at,
        pid=os.getpid(),
        error=None,
        progress={"current": 0, "total": total, "server": "", "phase": "latency"},
    )

    def one(item: tuple[str, Path]) -> dict:
        name, conf = item
        remote = parse_remote(conf)
        ms = latency_ms(remote[0], remote[1]) if remote else 9999.0
        return {
            "server": name,
            "latencyMs": ms,
            "downloadMbps": None,
            "uploadMbps": None,
        }

    done = 0
    with ThreadPoolExecutor(max_workers=12) as pool:
        futures = {pool.submit(one, s): s[0] for s in servers}
        for fut in as_completed(futures):
            row = fut.result()
            results_map[row["server"]] = row
            done += 1
            ordered = sort_results(list(results_map.values()), prefer_speed=False)
            update_job(
                progress={
                    "current": done,
                    "total": total,
                    "server": row["server"],
                    "phase": "latency",
                }
            )
            # Always keep latency cache fresh so UI can show live results.
            save_mode_cache("latency", proto, started_at, ordered, t0)

    latency_results = sort_results(list(results_map.values()), prefer_speed=False)
    save_mode_cache("latency", proto, started_at, latency_results, t0)

    if mode != "speed":
        update_job(
            status="done",
            progress={"current": total, "total": total, "server": "", "phase": "done"},
            error=None,
        )
        try:
            pid_file().unlink(missing_ok=True)
        except Exception:
            pass
        return

    # All servers that answered latency (skip timeouts). Full list — slow but complete.
    candidates = [r["server"] for r in latency_results if (r.get("latencyMs") or 9999) < 9000]
    if not candidates:
        update_job(status="error", error="no reachable servers for speed test")
        try:
            pid_file().unlink(missing_ok=True)
        except Exception:
            pass
        return

    # Seed speed cache with every reachable server (Mbps filled as each probe finishes).
    seed_rows = [dict(r) for r in latency_results if r["server"] in set(candidates)]
    for r in seed_rows:
        r["downloadMbps"] = None
        r["uploadMbps"] = None
    save_mode_cache("speed", proto, started_at, seed_rows, t0)

    if not ensure_openvpn_caps():
        job = read_job()
        if job.get("status") != "error":
            update_job(
                status="error",
                error="password dialog cancelled — approve once so download scans can connect",
            )
        try:
            pid_file().unlink(missing_ok=True)
        except Exception:
            pass
        return

    ok = run_speed_probe(proto, candidates)
    if not ok:
        job = read_job()
        if job.get("status") == "running":
            update_job(status="error", error=job.get("error") or "speed probe failed or was cancelled")
    try:
        pid_file().unlink(missing_ok=True)
    except Exception:
        pass


def start(mode: str, proto: str) -> dict:
    job = read_job()
    if job.get("status") == "running" and isinstance(job.get("pid"), int) and pid_alive(job["pid"]):
        return {"ok": False, "error": "already running"}

    cache_dir().mkdir(parents=True, exist_ok=True)
    _chown_user(cache_dir())
    seed = {
        "status": "running",
        "mode": mode,
        "proto": proto,
        "startedAt": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "progress": {"current": 0, "total": 0, "server": "", "phase": "starting"},
        "error": None,
        "pid": None,
    }
    write_json(job_file(), seed)

    log = cache_dir() / "rank.log"
    script = str(Path(__file__).resolve())
    with open(log, "a", encoding="utf-8") as logf:
        proc = subprocess.Popen(
            [sys.executable, script, "worker", mode, proto],
            stdout=logf,
            stderr=logf,
            start_new_session=True,
            close_fds=True,
        )
    seed["pid"] = proc.pid
    write_json(job_file(), seed)
    pid_file().write_text(str(proc.pid), encoding="utf-8")
    _chown_user(pid_file())
    _chown_user(log)
    return {"ok": True, "pid": proc.pid}


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: fvpn_rank.py <status|stop|start|worker|speed-probe> ...", file=sys.stderr)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "status":
        print(json.dumps(status()))
    elif cmd == "stop":
        print(json.dumps(stop()))
    elif cmd == "start":
        mode = sys.argv[2] if len(sys.argv) > 2 else "latency"
        proto = sys.argv[3] if len(sys.argv) > 3 else "udp"
        if mode not in ("latency", "speed"):
            print(json.dumps({"ok": False, "error": "mode must be latency|speed"}))
            sys.exit(1)
        print(json.dumps(start(mode, proto)))
    elif cmd == "worker":
        mode = sys.argv[2] if len(sys.argv) > 2 else "latency"
        proto = sys.argv[3] if len(sys.argv) > 3 else "udp"
        worker(mode, proto)
    elif cmd == "speed-probe":
        payload_path = Path(sys.argv[2]) if len(sys.argv) > 2 else None
        if not payload_path or not payload_path.exists():
            print("speed-probe requires candidates json", file=sys.stderr)
            sys.exit(1)
        data = read_json(payload_path) or {}
        speed_probe(data.get("proto") or "udp", list(data.get("servers") or []))
    else:
        print(f"unknown command: {cmd}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
