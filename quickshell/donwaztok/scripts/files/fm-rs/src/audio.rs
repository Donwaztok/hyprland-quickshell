//! Sound cards and monitor sources from `pactl -f json` (for services/shell/Audio.qml).

use serde_json::{json, Map, Value};
use std::process::Command;

fn load_json_array(args: &[&str]) -> Vec<Value> {
    let Ok(out) = Command::new("timeout").arg("3").arg("pactl").args(["-f", "json", "list"]).args(args).output()
    else {
        return vec![];
    };
    let text = String::from_utf8_lossy(&out.stdout);
    match text.find('[').map(|i| serde_json::from_str(&text[i..])) {
        Some(Ok(Value::Array(a))) => a,
        _ => vec![],
    }
}

/// Python truthiness for the strings this reads: missing, null and "" are all absent.
fn text<'a>(v: Option<&'a Value>) -> Option<&'a str> {
    v.and_then(Value::as_str).filter(|s| !s.is_empty())
}

fn obj<'a>(v: &'a Value, key: &str) -> &'a Map<String, Value> {
    static EMPTY: std::sync::OnceLock<Map<String, Value>> = std::sync::OnceLock::new();
    v.get(key).and_then(Value::as_object).unwrap_or_else(|| EMPTY.get_or_init(Map::new))
}

fn int(v: Option<&Value>) -> i64 {
    match v {
        Some(Value::Number(n)) => n.as_i64().or_else(|| n.as_f64().map(|f| f as i64)).unwrap_or(0),
        Some(Value::String(s)) => s.trim().parse().unwrap_or(0),
        _ => 0,
    }
}

fn profile_available(info: &Value) -> bool {
    match info.get("available") {
        Some(Value::Bool(b)) => *b,
        None | Some(Value::Null) => true,
        Some(v) => {
            let t = v.as_str().map(str::to_string).unwrap_or_else(|| v.to_string());
            !matches!(t.trim().to_lowercase().as_str(), "no" | "false" | "0" | "unavailable")
        }
    }
}

fn profile_label(name: &str, info: &Value) -> String {
    if let Some(desc) = text(info.get("description")).filter(|d| !matches!(*d, "(null)" | "null" | "None")) {
        return desc.to_string();
    }
    match name {
        "off" => return "Off".into(),
        "pro-audio" => return "Pro Audio".into(),
        _ => {}
    }
    let parts: Vec<String> = name
        .split('+')
        .map(|chunk| {
            let chunk = chunk.trim();
            if let Some(rest) = chunk.strip_prefix("output:") {
                rest.replace('-', " ")
            } else if let Some(rest) = chunk.strip_prefix("input:") {
                format!("input {}", rest.replace('-', " "))
            } else {
                chunk.replace('-', " ")
            }
        })
        .collect();
    let label = parts.join(" + ");
    let label = label.trim();
    let mut chars = label.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().chain(chars).collect(),
        None => name.to_string(),
    }
}

fn best(current: &mut (i64, Option<String>), priority: i64, name: &str) {
    if priority > current.0 {
        *current = (priority, Some(name.to_string()));
    }
}

fn list_cards() -> Vec<Value> {
    let mut result = vec![];
    for card in load_json_array(&["cards"]) {
        let props = obj(&card, "properties");
        let active = text(card.get("active_profile")).unwrap_or("off").to_string();
        let (mut sink, mut source, mut duplex) = ((-1, None), (-1, None), (-1, None));
        let (mut has_sink, mut has_source) = (false, false);
        let mut profiles = vec![];

        for (name, info) in obj(&card, "profiles") {
            let (sinks, sources, priority) = (int(info.get("sinks")), int(info.get("sources")), int(info.get("priority")));
            let available = profile_available(info);
            profiles.push(json!({
                "name": name,
                "label": profile_label(name, info),
                "sinks": sinks,
                "sources": sources,
                "priority": priority,
                "available": available,
            }));
            if name == "off" || name == "pro-audio" || !available {
                continue;
            }
            if sinks > 0 && sources > 0 {
                best(&mut duplex, priority, name);
            }
            if sinks > 0 {
                has_sink = true;
                best(&mut sink, priority, name);
            }
            if sources > 0 {
                has_source = true;
                best(&mut source, priority, name);
            }
        }

        profiles.sort_by_key(|p| (p["name"] != "off", -p["priority"].as_i64().unwrap_or(0), p["name"].as_str().unwrap_or("").to_string()));
        let preferred = if active != "off" && active != "pro-audio" {
            active.clone()
        } else {
            sink.1.clone().or_else(|| source.1.clone()).unwrap_or_else(|| "off".into())
        };
        let active_label = profiles.iter().find(|p| p["name"] == active.as_str()).map(|p| p["label"].clone()).unwrap_or_else(|| active.clone().into());
        let card_name = text(card.get("name")).unwrap_or("");
        let description = ["device.description", "device.product.name", "device.nick"]
            .iter()
            .find_map(|k| text(props.get(*k)))
            .unwrap_or(if card_name.is_empty() { "Unknown" } else { card_name });

        result.push(json!({
            "index": card.get("index").cloned().unwrap_or(Value::Null),
            "name": card_name,
            "description": description,
            "activeProfile": active,
            "activeProfileLabel": active_label,
            "enabled": active != "off",
            "hasSink": has_sink,
            "hasSource": has_source,
            "preferredSinkProfile": sink.1.unwrap_or_else(|| preferred.clone()),
            "preferredSourceProfile": source.1.unwrap_or_else(|| preferred.clone()),
            "preferredDuplexProfile": duplex.1.unwrap_or_default(),
            "preferredProfile": preferred,
            "profiles": profiles,
        }));
    }
    result
}

/// `#index:<n>` keys, whether pactl wrote the index as a number or a string.
fn index_key(v: &Value) -> String {
    format!("#index:{}", v.as_str().map(str::to_string).unwrap_or_else(|| v.to_string()))
}

fn list_monitors() -> Vec<Value> {
    let mut sink_ids = std::collections::HashMap::new();
    for sink in load_json_array(&["sinks"]) {
        let props = obj(&sink, "properties");
        let id = ["object.id", "node.id"]
            .iter()
            .filter_map(|k| props.get(*k))
            .find_map(|v| match v {
                Value::String(s) => s.trim().parse::<i64>().ok(),
                Value::Number(n) => n.as_i64(),
                _ => None,
            })
            .unwrap_or(-1);
        if let Some(name) = text(sink.get("name")) {
            sink_ids.insert(name.to_string(), id);
        }
        if let Some(index) = sink.get("index").filter(|v| !v.is_null()) {
            sink_ids.insert(index_key(index), id);
        }
    }

    let mut result = vec![];
    for source in load_json_array(&["sources"]) {
        let props = obj(&source, "properties");
        let name = text(source.get("name")).unwrap_or("");
        if props.get("device.class").and_then(Value::as_str) != Some("monitor") && !name.ends_with(".monitor") {
            continue;
        }
        let sink_name = text(source.get("monitor_of_sink")).map(str::to_string).unwrap_or_else(|| name.strip_suffix(".monitor").unwrap_or(name).to_string());
        let mut sink_id = sink_ids.get(&sink_name).copied().unwrap_or(-1);
        if sink_id < 0 {
            if let Some(index) = source.get("monitor_of_sink_index").filter(|v| !v.is_null()) {
                sink_id = sink_ids.get(&index_key(index)).copied().unwrap_or(-1);
            }
        }
        let fallback = if sink_name.is_empty() { name } else { sink_name.as_str() };
        let raw = ["device.description", "device.nick", "node.nick"]
            .iter()
            .find_map(|k| text(props.get(*k)))
            .filter(|d| !matches!(*d, "(null)" | "null"))
            .unwrap_or(fallback);
        let description = match text(source.get("description")) {
            Some(d) if !matches!(d, "(null)" | "null") => d.to_string(),
            _ => format!("Monitor of {raw}"),
        };
        result.push(json!({
            "name": name,
            "sinkName": sink_name,
            "sinkId": sink_id,
            "description": description,
            "muted": source.get("mute").and_then(Value::as_bool).unwrap_or(false),
        }));
    }
    result
}

pub fn list() {
    println!("{}", json!({"cards": list_cards(), "monitors": list_monitors()}));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn labels_and_availability() {
        assert_eq!(profile_label("output:analog-stereo+input:analog-stereo", &json!({})), "Analog stereo + input analog stereo");
        assert_eq!(profile_label("x", &json!({"description": "(null)"})), "X");
        assert_eq!(profile_label("off", &json!({})), "Off");
        assert!(!profile_available(&json!({"available": "no"})));
        assert!(!profile_available(&json!({"available": 0})));
        assert!(profile_available(&json!({"available": null})));
        assert!(profile_available(&json!({})));
    }
}
