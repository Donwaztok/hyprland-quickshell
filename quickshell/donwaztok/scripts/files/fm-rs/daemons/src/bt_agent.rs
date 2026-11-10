//! BlueZ pairing agent for the shell (replaces blueman-applet's).
//!
//! Requests go out as JSON lines on stdout ({"type", "id", "device", ...}); the shell answers
//! on stdin with {"id": n, "ok": bool, "value": str}. Types that need an answer: pin, passkey,
//! confirm, authorize, service. Notices without an id: display, cancel, done, ready.

use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::BufRead;
use std::sync::{Arc, Mutex};
use zbus::zvariant::{ObjectPath, OwnedValue};
use zbus::{interface, Connection};

const AGENT_PATH: &str = "/org/donwaztok/bluetooth_agent";
const CAPABILITY: &str = "KeyboardDisplay";

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.Error")]
enum AgentError {
    Rejected(String),
    Canceled(String),
}

enum Answer {
    Pin(String),
    Passkey(u32),
    Accept,
}

type Pending = async_channel::Sender<Result<Answer, AgentError>>;

#[derive(Default)]
struct State {
    seq: u64,
    pending: HashMap<u64, (&'static str, Pending)>,
}

#[derive(Clone)]
struct Agent {
    state: Arc<Mutex<State>>,
    emit: Arc<dyn Fn(Value) + Send + Sync>,
}

async fn device_name(conn: &Connection, path: &str) -> String {
    let alias = async {
        let reply = conn
            .call_method(Some("org.bluez"), path, Some("org.freedesktop.DBus.Properties"), "Get", &("org.bluez.Device1", "Alias"))
            .await?;
        Ok::<_, zbus::Error>(String::try_from(reply.body().deserialize::<OwnedValue>()?)?)
    };
    alias.await.unwrap_or_else(|_| {
        let last = path.rsplit('/').next().unwrap_or(path);
        last.strip_prefix("dev_").unwrap_or(last).replace('_', ":")
    })
}

impl Agent {
    fn new(emit: impl Fn(Value) + Send + Sync + 'static) -> Self {
        Agent { state: Arc::default(), emit: Arc::new(emit) }
    }

    async fn ask(&self, conn: &Connection, kind: &'static str, device: &ObjectPath<'_>, extra: Value) -> Result<Answer, AgentError> {
        let name = device_name(conn, device).await;
        let (tx, rx) = async_channel::bounded(1);
        {
            // Register and emit under one lock, so an answer can never find its id missing.
            let mut st = self.state.lock().unwrap();
            st.seq += 1;
            let id = st.seq;
            st.pending.insert(id, (kind, tx));
            let mut msg = json!({"type": kind, "id": id, "device": name});
            if let (Some(m), Value::Object(e)) = (msg.as_object_mut(), extra) {
                m.extend(e);
            }
            (self.emit)(msg);
        }
        rx.recv().await.unwrap_or_else(|_| Err(AgentError::Canceled("Canceled".into())))
    }

    fn answer(&self, msg: &Value) {
        let Some(id) = msg.get("id").and_then(Value::as_u64) else { return };
        let Some((kind, tx)) = self.state.lock().unwrap().pending.remove(&id) else { return };
        let ok = matches!(msg.get("ok"), Some(Value::Bool(true)));
        let value = match msg.get("value") {
            Some(Value::String(s)) => s.trim().to_string(),
            Some(v) => v.to_string(),
            None => String::new(),
        };
        let result = if !ok {
            Err(AgentError::Rejected("Rejected by user".into()))
        } else {
            match kind {
                "pin" => Ok(Answer::Pin(value)),
                "passkey" => match value.parse::<u32>() {
                    Ok(n) if value.bytes().all(|b| b.is_ascii_digit()) => Ok(Answer::Passkey(n)),
                    _ => Err(AgentError::Rejected("Passkey must be a number".into())),
                },
                _ => Ok(Answer::Accept),
            }
        };
        let _ = tx.try_send(result);
    }
}

#[interface(name = "org.bluez.Agent1")]
impl Agent {
    fn release(&self) {}

    async fn request_pin_code(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>) -> Result<String, AgentError> {
        match self.ask(conn, "pin", &device, json!({})).await? {
            Answer::Pin(p) => Ok(p),
            _ => Err(AgentError::Rejected("Rejected by user".into())),
        }
    }

    async fn request_passkey(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>) -> Result<u32, AgentError> {
        match self.ask(conn, "passkey", &device, json!({})).await? {
            Answer::Passkey(n) => Ok(n),
            _ => Err(AgentError::Rejected("Passkey must be a number".into())),
        }
    }

    async fn display_passkey(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>, passkey: u32, entered: u16) {
        let name = device_name(conn, &device).await;
        (self.emit)(json!({"type": "display", "device": name, "code": format!("{passkey:06}"), "entered": entered}));
    }

    async fn display_pin_code(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>, pincode: String) {
        let name = device_name(conn, &device).await;
        (self.emit)(json!({"type": "display", "device": name, "code": pincode, "entered": 0}));
    }

    async fn request_confirmation(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>, passkey: u32) -> Result<(), AgentError> {
        self.ask(conn, "confirm", &device, json!({"code": format!("{passkey:06}")})).await.map(|_| ())
    }

    async fn request_authorization(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>) -> Result<(), AgentError> {
        self.ask(conn, "authorize", &device, json!({})).await.map(|_| ())
    }

    async fn authorize_service(&self, #[zbus(connection)] conn: &Connection, device: ObjectPath<'_>, uuid: String) -> Result<(), AgentError> {
        self.ask(conn, "service", &device, json!({"uuid": uuid})).await.map(|_| ())
    }

    fn cancel(&self) {
        for (_, (_, tx)) in self.state.lock().unwrap().pending.drain() {
            let _ = tx.try_send(Err(AgentError::Canceled("Canceled by remote".into())));
        }
        (self.emit)(json!({"type": "cancel"}));
    }
}

fn register(conn: &zbus::blocking::Connection, agent: &Agent) {
    let path = ObjectPath::from_static_str_unchecked(AGENT_PATH);
    let (dest, obj, iface) = (Some("org.bluez"), "/org/bluez", Some("org.bluez.AgentManager1"));
    let result = conn
        .call_method(dest, obj, iface, "RegisterAgent", &(&path, CAPABILITY))
        .and_then(|_| conn.call_method(dest, obj, iface, "RequestDefaultAgent", &(&path,)));
    match result {
        Ok(_) => (agent.emit)(json!({"type": "ready", "bus": conn.unique_name().map(|n| n.to_string())})),
        Err(e) => eprintln!("bluetooth agent: register failed: {e}"),
    }
}

fn main() -> zbus::Result<()> {
    let agent = Agent::new(|msg| println!("{msg}"));
    let conn = zbus::blocking::connection::Builder::system()?.serve_at(AGENT_PATH, agent.clone())?.build()?;

    // Registers at start and whenever bluetoothd (re)appears; its agents die with it.
    let (c, a) = (conn.clone(), agent.clone());
    let dbus = zbus::blocking::fdo::DBusProxy::new(&conn)?;
    let owners = dbus.receive_name_owner_changed_with_args(&[(0, "org.bluez")])?;
    if dbus.name_has_owner("org.bluez".try_into()?)? {
        register(&c, &a);
    }
    std::thread::spawn(move || {
        for sig in owners {
            if sig.args().is_ok_and(|s| s.new_owner().is_some()) {
                register(&c, &a);
            }
        }
    });

    // Closes the "type this code" notice once the device is paired.
    let rule = zbus::MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .interface("org.freedesktop.DBus.Properties")?
        .member("PropertiesChanged")?
        .build();
    let props = zbus::blocking::MessageIterator::for_match_rule(rule, &conn, None)?;
    let (c, a) = (conn.clone(), agent.clone());
    std::thread::spawn(move || {
        for msg in props.flatten() {
            let Ok((iface, changed, _)) = msg.body().deserialize::<(String, HashMap<String, OwnedValue>, Vec<String>)>() else { continue };
            let paired = changed.get("Paired").and_then(|v| bool::try_from(v).ok()).unwrap_or(false);
            if iface == "org.bluez.Device1" && paired {
                let path = msg.header().path().map(|p| p.to_string()).unwrap_or_default();
                (a.emit)(json!({"type": "done", "device": zbus::block_on(device_name(c.inner(), &path))}));
            }
        }
    });

    for line in std::io::stdin().lock().lines() {
        let Ok(line) = line else { break };
        if let Ok(msg) = serde_json::from_str::<Value>(&line) {
            agent.answer(&msg);
        }
    }
    Ok(()) // stdin closed: the shell went away
}

/// Exports the agent on the session bus (the system bus does not let a user call it) and plays
/// BlueZ's part: each call must reach the shell as a JSON request and return the shell's answer.
#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    const DEVICE: &str = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF";

    struct Harness {
        agent: Agent,
        sent: Arc<Mutex<Vec<Value>>>,
        server: zbus::blocking::Connection,
        client: zbus::blocking::Connection,
    }

    impl Harness {
        fn new() -> Self {
            let sent = Arc::new(Mutex::new(Vec::new()));
            let s = sent.clone();
            let agent = Agent::new(move |m| s.lock().unwrap().push(m));
            let server = zbus::blocking::connection::Builder::session().unwrap().serve_at(AGENT_PATH, agent.clone()).unwrap().build().unwrap();
            let client = zbus::blocking::Connection::session().unwrap();
            Harness { agent, sent, server, client }
        }

        fn last(&self) -> Value {
            self.sent.lock().unwrap().last().cloned().unwrap_or(Value::Null)
        }

        /// Answers the next request the agent emits with reply (merged with its id).
        fn answering(&self, reply: Value) {
            let (agent, sent) = (self.agent.clone(), self.sent.clone());
            std::thread::spawn(move || loop {
                let id = {
                    let st = agent.state.lock().unwrap();
                    let id = sent.lock().unwrap().last().and_then(|m| m.get("id")).and_then(Value::as_u64);
                    id.filter(|id| st.pending.contains_key(id))
                };
                if let Some(id) = id {
                    let mut r = reply.clone();
                    r["id"] = id.into();
                    agent.answer(&r);
                    return;
                }
                std::thread::sleep(Duration::from_millis(5));
            });
        }

        /// Calls the agent like BlueZ would; Err holds the D-Bus error name.
        fn call<B: zbus::export::serde::Serialize + zbus::zvariant::DynamicType>(&self, method: &str, body: &B) -> Result<zbus::message::Message, String> {
            let dest = self.server.unique_name().unwrap().to_owned();
            self.client.call_method(Some(dest), AGENT_PATH, Some("org.bluez.Agent1"), method, body).map_err(|e| match e {
                zbus::Error::MethodError(name, _, _) => name.to_string(),
                e => e.to_string(),
            })
        }
    }

    fn dev() -> ObjectPath<'static> {
        ObjectPath::from_static_str_unchecked(DEVICE)
    }

    #[test]
    fn agent_relays_bluez_calls() {
        let h = Harness::new();

        h.answering(json!({"ok": true}));
        h.call("RequestConfirmation", &(dev(), 42u32)).unwrap();
        let last = h.last();
        assert_eq!((last["type"].as_str(), last["code"].as_str()), (Some("confirm"), Some("000042")), "{last}");
        assert_eq!(last["device"], "AA:BB:CC:DD:EE:FF", "no BlueZ here: falls back to the address");

        h.answering(json!({"ok": true, "value": "123456"}));
        let reply = h.call("RequestPasskey", &(dev(),)).unwrap();
        assert_eq!(reply.body().deserialize::<u32>().unwrap(), 123456);

        h.answering(json!({"ok": true, "value": "12a"}));
        assert_eq!(h.call("RequestPasskey", &(dev(),)).unwrap_err(), "org.bluez.Error.Rejected");

        h.answering(json!({"ok": true, "value": "0000"}));
        let reply = h.call("RequestPinCode", &(dev(),)).unwrap();
        assert_eq!(reply.body().deserialize::<String>().unwrap(), "0000");

        h.answering(json!({"ok": false}));
        let err = h.call("AuthorizeService", &(dev(), "0000110b-0000-1000-8000-00805f9b34fb")).unwrap_err();
        assert_eq!(err, "org.bluez.Error.Rejected");
        assert_eq!(h.last()["type"], "service");

        h.call("DisplayPasskey", &(dev(), 7u32, 2u16)).unwrap();
        assert_eq!(h.last(), json!({"type": "display", "device": "AA:BB:CC:DD:EE:FF", "code": "000007", "entered": 2}));
    }

    #[test]
    fn cancel_fails_waiting_requests() {
        let h = Harness::new();
        let dest = h.server.unique_name().unwrap().to_string();
        let client = h.client.clone();
        let waiting = std::thread::spawn(move || {
            client.call_method(Some(dest.as_str()), AGENT_PATH, Some("org.bluez.Agent1"), "RequestConfirmation", &(dev(), 1u32))
        });
        while h.agent.state.lock().unwrap().pending.is_empty() {
            std::thread::sleep(Duration::from_millis(5));
        }
        h.call("Cancel", &()).unwrap();
        match waiting.join().unwrap() {
            Err(zbus::Error::MethodError(name, _, _)) => assert_eq!(name.as_str(), "org.bluez.Error.Canceled"),
            other => panic!("expected Canceled, got {other:?}"),
        }
        assert!(h.agent.state.lock().unwrap().pending.is_empty());
        assert_eq!(h.last(), json!({"type": "cancel"}));
    }

    #[test]
    fn passkey_and_answers() {
        let a = Agent::new(|_| {});
        let (tx, rx) = async_channel::bounded(1);
        a.state.lock().unwrap().pending.insert(9, ("passkey", tx));
        a.answer(&json!({"id": 9, "ok": true, "value": " 4294967296 "})); // overflows u32
        assert!(matches!(rx.try_recv(), Ok(Err(AgentError::Rejected(_)))));
        a.answer(&json!({"id": 9, "ok": true})); // already answered: ignored
        a.answer(&json!("not an object"));
    }
}
