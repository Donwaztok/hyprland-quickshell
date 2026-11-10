//! xdg-desktop-portal FileChooser backend that opens Donwaztok Files.
//!
//! Each call writes $XDG_RUNTIME_DIR/donwaztok-portal/<id>/request.json, asks the shell to show
//! the picker (`qs ipc call fileManager pick <id>`) and waits for result.json next to it.

use percent_encoding::{utf8_percent_encode, AsciiSet, NON_ALPHANUMERIC};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};
use zbus::interface;
use zbus::zvariant::{ObjectPath, OwnedValue, Value as Var};

const BUS_NAME: &str = "org.freedesktop.impl.portal.desktop.donwaztok";
const OBJECT_PATH: &str = "/org/freedesktop/portal/desktop";
const POLL: Duration = Duration::from_millis(50);

type Options<'a> = HashMap<&'a str, Var<'a>>;
type Reply = (u32, HashMap<String, OwnedValue>);

// What Python's pathlib.as_uri() leaves unescaped.
const URI_SAFE: &AsciiSet = &NON_ALPHANUMERIC.remove(b'/').remove(b'-').remove(b'_').remove(b'.').remove(b'~');

fn runtime_root() -> PathBuf {
    let base = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
        format!("/run/user/{}", fs::metadata("/proc/self").map(|m| m.uid()).unwrap_or(0))
    });
    Path::new(&base).join("donwaztok-portal")
}

fn expand_user(p: &str) -> PathBuf {
    match p.strip_prefix('~') {
        Some(rest) if rest.is_empty() || rest.starts_with('/') => {
            PathBuf::from(format!("{}{rest}", std::env::var("HOME").unwrap_or_default()))
        }
        _ => PathBuf::from(p),
    }
}

/// Like pathlib's resolve(strict=False): a save target does not exist yet, so resolve its folder.
fn path_to_uri(path: &str) -> String {
    let p = expand_user(path);
    let resolved = fs::canonicalize(&p).unwrap_or_else(|_| {
        match (p.parent().and_then(|d| fs::canonicalize(d).ok()), p.file_name()) {
            (Some(dir), Some(name)) => dir.join(name),
            _ => p.clone(),
        }
    });
    format!("file://{}", utf8_percent_encode(&resolved.to_string_lossy(), URI_SAFE))
}

fn get<'a, T: TryFrom<Var<'a>>>(o: &Options<'a>, key: &str) -> Option<T> {
    o.get(key)?.try_clone().ok()?.try_into().ok()
}

fn decode_ay(raw: Vec<u8>) -> String {
    let raw = raw.strip_suffix(b"\0").unwrap_or(&raw);
    String::from_utf8_lossy(raw).into_owned()
}

fn parse_filters(o: &Options) -> Vec<Value> {
    let filters: Vec<(String, Vec<(u32, String)>)> = get(o, "filters").unwrap_or_default();
    let out: Vec<Value> = filters
        .into_iter()
        .map(|(name, rules)| {
            // kind 0 = glob; 1 = mime type, which the picker cannot match
            let mut patterns: Vec<String> =
                rules.into_iter().filter(|(k, p)| *k == 0 && !p.is_empty()).map(|(_, p)| p).collect();
            if patterns.is_empty() {
                patterns.push("*".into());
            }
            json!({"name": if name.is_empty() { "Files".into() } else { name }, "patterns": patterns})
        })
        .collect();
    if out.is_empty() {
        vec![json!({"name": "All files", "patterns": ["*"]})]
    } else {
        out
    }
}

fn request_id() -> String {
    fs::read_to_string("/proc/sys/kernel/random/uuid").unwrap_or_default().trim().replace('-', "")
}

/// Writes request.json and returns (id, path of result.json).
fn build_request(mode: &str, title: &str, o: &Options) -> std::io::Result<(String, PathBuf)> {
    let id = request_id();
    let folder = runtime_root().join(&id);
    fs::create_dir_all(&folder)?;
    let result_path = folder.join("result.json");
    let _ = fs::remove_file(&result_path);

    let mut current_folder = get(o, "current_folder").map(decode_ay).unwrap_or_default();
    let current_file = get(o, "current_file").map(decode_ay).unwrap_or_default();
    let mut current_name: String = get(o, "current_name").unwrap_or_default();
    if current_name.is_empty() && !current_file.is_empty() {
        let f = Path::new(&current_file);
        current_name = f.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        if current_folder.is_empty() {
            current_folder = f.parent().map(|d| d.to_string_lossy().into_owned()).unwrap_or_default();
        }
    }
    let files: Vec<String> = if mode == "saveFiles" {
        get::<Vec<Vec<u8>>>(o, "files")
            .unwrap_or_default()
            .into_iter()
            .filter_map(|f| Path::new(&decode_ay(f)).file_name().map(|n| n.to_string_lossy().into_owned()))
            .collect()
    } else {
        vec![]
    };
    let payload = json!({
        "id": id,
        "mode": mode,
        "title": title,
        "acceptLabel": get::<String>(o, "accept_label").unwrap_or_default().replace('_', ""),
        "multiple": get(o, "multiple").unwrap_or(false),
        "directory": get(o, "directory").unwrap_or(false),
        "currentFolder": current_folder,
        "currentName": current_name,
        "filters": parse_filters(o),
        "files": files,
    });
    fs::write(folder.join("request.json"), payload.to_string())?;
    Ok((id, result_path))
}

/// Polls instead of blocking: the executor also serves other portal calls meanwhile.
async fn launch_picker(id: &str) -> bool {
    let child = Command::new("qs")
        .args(["-c", "donwaztok", "ipc", "call", "fileManager", "pick", id])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn();
    let mut child = match child {
        Ok(c) => c,
        Err(e) => {
            eprintln!("donwaztok-portal: failed to launch picker: {e}");
            return false;
        }
    };
    let deadline = Instant::now() + Duration::from_secs(15);
    let status = loop {
        match child.try_wait() {
            Ok(Some(s)) => break s,
            Ok(None) if Instant::now() < deadline => async_io::Timer::after(POLL).await,
            _ => {
                let _ = child.kill();
                let _ = child.wait();
                eprintln!("donwaztok-portal: failed to launch picker: qs ipc timed out");
                return false;
            }
        };
    };
    if !status.success() {
        let mut out = String::new();
        let _ = child.stderr.take().map(|mut e| e.read_to_string(&mut out));
        if out.is_empty() {
            let _ = child.stdout.take().map(|mut o| o.read_to_string(&mut out));
        }
        eprintln!("donwaztok-portal: qs ipc failed ({}): {out}", status.code().unwrap_or(-1));
        return false;
    }
    true
}

async fn wait_result(path: &Path) -> Option<Value> {
    let deadline = Instant::now() + Duration::from_secs(600);
    while Instant::now() < deadline {
        if let Some(v) = fs::read_to_string(path).ok().and_then(|t| serde_json::from_str::<Value>(&t).ok()) {
            if v.get("response").is_some() {
                return Some(v);
            }
        }
        async_io::Timer::after(POLL).await;
    }
    None
}

fn reply(response: u32, uris: Option<Vec<String>>) -> Reply {
    let mut results = HashMap::new();
    if let Some(uris) = uris {
        results.insert("uris".to_string(), Var::from(uris).try_into().expect("as has no fds"));
    }
    (response, results)
}

async fn choose(mode: &str, title: &str, o: Options<'_>) -> Reply {
    let (id, result_path) = match build_request(mode, title, &o) {
        Ok(r) => r,
        Err(e) => {
            eprintln!("donwaztok-portal: cannot write request: {e}");
            return reply(2, None);
        }
    };
    if !launch_picker(&id).await {
        return reply(2, None);
    }
    let result = wait_result(&result_path).await;
    if let Some(dir) = result_path.parent() {
        let _ = fs::remove_dir_all(dir);
    }
    let Some(result) = result else { return reply(2, None) };
    match result["response"].as_f64().map(|r| r as i64).unwrap_or(2) {
        0 => {}
        1 => return reply(1, None),
        _ => return reply(2, None),
    }
    let uris: Vec<String> = result
        .get("uris")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .filter(|s| !s.is_empty())
        .map(|s| if s.starts_with("file:") { s.to_string() } else { path_to_uri(s) })
        .collect();
    if uris.is_empty() {
        return reply(1, None);
    }
    reply(0, Some(uris))
}

struct FileChooser;

#[interface(name = "org.freedesktop.impl.portal.FileChooser")]
impl FileChooser {
    // Spelled out, not `Reply`: zbus only splits a literal tuple into two out args.
    #[zbus(out_args("response", "results"))]
    async fn open_file(&self, _handle: ObjectPath<'_>, _app_id: &str, _parent: &str, title: &str, options: Options<'_>) -> (u32, HashMap<String, OwnedValue>) {
        choose("open", title, options).await
    }

    #[zbus(out_args("response", "results"))]
    async fn save_file(&self, _handle: ObjectPath<'_>, _app_id: &str, _parent: &str, title: &str, options: Options<'_>) -> (u32, HashMap<String, OwnedValue>) {
        choose("save", title, options).await
    }

    #[zbus(out_args("response", "results"))]
    async fn save_files(&self, _handle: ObjectPath<'_>, _app_id: &str, _parent: &str, title: &str, options: Options<'_>) -> (u32, HashMap<String, OwnedValue>) {
        choose("saveFiles", title, options).await
    }

    #[zbus(property, name = "version")]
    fn version(&self) -> u32 {
        4
    }
}

fn main() {
    let conn = zbus::blocking::connection::Builder::session()
        .and_then(|b| b.name(BUS_NAME))
        .and_then(|b| b.serve_at(OBJECT_PATH, FileChooser))
        .and_then(|b| b.build());
    let _conn = conn.unwrap_or_else(|e| {
        eprintln!("donwaztok-portal: cannot own {BUS_NAME}: {e}");
        std::process::exit(1);
    });
    // zbus serves calls on its own thread; this one only keeps the process alive.
    loop {
        std::thread::park();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn uri_quotes_like_pathlib() {
        assert_eq!(path_to_uri("/tmp/a b/ç#.txt"), "file:///tmp/a%20b/%C3%A7%23.txt");
    }

    #[test]
    fn options_become_request() {
        let mut o: Options = HashMap::new();
        o.insert("current_file", Var::from(b"/tmp/dir/name.txt\0".to_vec()));
        o.insert("filters", Var::from(vec![("Images".to_string(), vec![(0u32, "*.png".to_string()), (1, "image/png".into())]), ("".into(), vec![(1, "text/plain".into())])]));
        o.insert("accept_label", Var::from("_Save"));
        let (id, result) = build_request("save", "T", &o).unwrap();
        let req: Value = serde_json::from_str(&fs::read_to_string(result.with_file_name("request.json")).unwrap()).unwrap();
        fs::remove_dir_all(result.parent().unwrap()).unwrap();
        assert_eq!(id.len(), 32);
        assert_eq!(req["currentName"], "name.txt");
        assert_eq!(req["currentFolder"], "/tmp/dir");
        assert_eq!(req["acceptLabel"], "Save");
        assert_eq!(req["multiple"], false);
        assert_eq!(req["filters"], json!([{"name": "Images", "patterns": ["*.png"]}, {"name": "Files", "patterns": ["*"]}]));
    }
}
