//! Newline-delimited JSON protocol shared with QML.

use serde::Serialize;
use serde_json::Value;
use std::io::{self, Write};
use std::process;

pub fn emit(obj: &Value) {
    let mut out = io::stdout().lock();
    let _ = serde_json::to_writer(&mut out, obj);
    let _ = out.write_all(b"\n");
    let _ = out.flush();
}

pub fn progress(pct: f64, message: &str) {
    let pct = pct.clamp(0.0, 1.0);
    emit(&serde_json::json!({
        "type": "progress",
        "progress": pct,
        "message": message,
    }));
}

pub fn out_ok(obj: impl Serialize) {
    let mut v = serde_json::to_value(obj).unwrap_or(Value::Null);
    if let Value::Object(ref mut map) = v {
        map.entry("ok".to_string()).or_insert(Value::Bool(true));
        map.entry("type".to_string())
            .or_insert(Value::String("done".into()));
    }
    emit(&v);
}

pub fn err_exit(msg: &str) -> ! {
    emit(&serde_json::json!({
        "type": "error",
        "ok": false,
        "error": msg,
    }));
    process::exit(1);
}

pub fn expand_user(s: &str) -> std::path::PathBuf {
    if s.starts_with("~/") || s == "~" {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/".into());
        if s == "~" {
            return std::path::PathBuf::from(home);
        }
        return std::path::PathBuf::from(home).join(&s[2..]);
    }
    std::path::PathBuf::from(s)
}
