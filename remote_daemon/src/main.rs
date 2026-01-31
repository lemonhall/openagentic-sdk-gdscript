mod device_code;
mod irc;
mod matchers;

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Duration;

fn main() -> std::io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.iter().any(|a| a == "--help" || a == "-h") {
        print_help();
        return Ok(());
    }

    let host = arg_or_env(&args, "--host", "OA_IRC_HOST").unwrap_or_else(|| "127.0.0.1".to_string());
    let port: u16 = arg_or_env(&args, "--port", "OA_IRC_PORT")
        .and_then(|v| v.parse().ok())
        .unwrap_or(6667);
    let instance = arg_or_env(&args, "--instance", "OA_REMOTE_INSTANCE").unwrap_or_else(|| "default".to_string());
    let poll_seconds: u64 = arg_or_env(&args, "--poll-seconds", "OA_REMOTE_POLL_SECONDS")
        .and_then(|v| v.parse().ok())
        .unwrap_or(30);
    let password = arg_or_env(&args, "--password", "OA_IRC_PASSWORD");
    let override_code = arg_or_env(&args, "--device-code", "OA_REMOTE_DEVICE_CODE");

    let data_home = arg_or_env(&args, "--data-home", "OA_REMOTE_DATA_HOME").map(PathBuf::from);
    let data_dir = resolve_data_dir(data_home, &instance)?;
    let device_code = load_or_create_device_code(&data_dir, override_code)?;

    let nick = arg_or_env(&args, "--nick", "OA_IRC_NICK")
        .unwrap_or_else(|| derive_default_nick(&device_code));
    let user = arg_or_env(&args, "--user", "OA_IRC_USER").unwrap_or_else(|| nick.clone());
    let realname = arg_or_env(&args, "--realname", "OA_IRC_REALNAME").unwrap_or_else(|| "OpenAgentic Remote".to_string());

    println!("Device code: {}", device_code);
    println!("Instance: {}", instance);
    println!("Data dir: {}", data_dir.display());
    println!("IRC: {}:{} as {}", host, port, nick);

    let cfg = irc::IrcConfig {
        host,
        port,
        nick,
        user,
        realname,
        password,
        poll_interval: Duration::from_secs(poll_seconds.max(5)),
    };

    irc::run_polling_join_loop(cfg, device_code)
}

fn print_help() {
    println!("openagentic_remote_daemon");
    println!();
    println!("Options:");
    println!("  --host <host>           (env OA_IRC_HOST)");
    println!("  --port <port>           (env OA_IRC_PORT, default 6667)");
    println!("  --password <pass>       (env OA_IRC_PASSWORD)");
    println!("  --nick <nick>           (env OA_IRC_NICK)");
    println!("  --user <user>           (env OA_IRC_USER)");
    println!("  --realname <name>       (env OA_IRC_REALNAME)");
    println!("  --poll-seconds <n>      (env OA_REMOTE_POLL_SECONDS, default 30)");
    println!("  --instance <name>       (env OA_REMOTE_INSTANCE, default 'default')");
    println!("  --device-code <code>    (env OA_REMOTE_DEVICE_CODE)");
    println!("  --data-home <dir>       (env OA_REMOTE_DATA_HOME)");
    println!("  -h, --help");
}

fn arg_or_env(args: &[String], flag: &str, env_key: &str) -> Option<String> {
    if let Some(v) = arg_value(args, flag) {
        return Some(v);
    }
    env::var(env_key).ok().filter(|s| !s.trim().is_empty())
}

fn arg_value(args: &[String], flag: &str) -> Option<String> {
    let mut it = args.iter();
    while let Some(a) = it.next() {
        if a == flag {
            return it.next().cloned();
        }
    }
    None
}

fn resolve_data_dir(data_home: Option<PathBuf>, instance: &str) -> std::io::Result<PathBuf> {
    let base = match data_home {
        Some(p) => p,
        None => default_data_home(),
    };
    let inst = sanitize_instance_name(instance);
    let dir = base.join(inst);
    fs::create_dir_all(&dir)?;
    Ok(dir)
}

fn default_data_home() -> PathBuf {
    if let Ok(p) = env::var("XDG_DATA_HOME") {
        if !p.trim().is_empty() {
            return PathBuf::from(p).join("openagentic_remote");
        }
    }
    if let Ok(home) = env::var("HOME") {
        if !home.trim().is_empty() {
            return PathBuf::from(home).join(".local").join("share").join("openagentic_remote");
        }
    }
    PathBuf::from(".openagentic_remote")
}

fn sanitize_instance_name(name: &str) -> String {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return "default".to_string();
    }
    let mut out = String::new();
    for b in trimmed.bytes() {
        match b {
            b'0'..=b'9' | b'A'..=b'Z' | b'a'..=b'z' | b'_' | b'-' => out.push(b as char),
            _ => out.push('_'),
        }
    }
    out
}

fn load_or_create_device_code(dir: &Path, override_code: Option<String>) -> std::io::Result<String> {
    let path = dir.join("device_code.txt");

    if let Some(c) = override_code {
        let canon = device_code::canonicalize(&c);
        if !device_code::is_valid_canonical(&canon) {
            return Err(std::io::Error::new(
                std::io::ErrorKind::InvalidInput,
                "invalid device code",
            ));
        }
        fs::write(&path, format!("{}\n", canon))?;
        return Ok(canon);
    }

    if let Ok(existing) = fs::read_to_string(&path) {
        let canon = device_code::canonicalize(&existing);
        if device_code::is_valid_canonical(&canon) {
            return Ok(canon);
        }
    }

    let gen = device_code::generate();
    fs::write(&path, format!("{}\n", gen))?;
    Ok(gen)
}

fn derive_default_nick(device_code: &str) -> String {
    let code = device_code.to_ascii_lowercase();
    let mut nick = format!("oa_remote_{}", code);
    if nick.len() > 15 {
        nick.truncate(15);
    }
    nick
}

