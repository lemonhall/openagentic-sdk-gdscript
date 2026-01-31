use std::collections::HashSet;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

use crate::exec;
use crate::matchers;
use crate::oa1;
use crate::rpc;

pub struct IrcConfig {
    pub host: String,
    pub port: u16,
    pub nick: String,
    pub user: String,
    pub realname: String,
    pub password: Option<String>,
    pub poll_interval: Duration,
}

pub fn run_polling_join_loop(
    cfg: IrcConfig,
    device_code: String,
    exec_cfg: exec::ExecConfig,
) -> std::io::Result<()> {
    let addr = format!("{}:{}", cfg.host, cfg.port);
    let stream = TcpStream::connect(addr)?;
    stream.set_read_timeout(Some(Duration::from_millis(500)))?;
    stream.set_write_timeout(Some(Duration::from_secs(5)))?;

    // Clone for buffered read loop.
    let read_stream = stream.try_clone()?;
    let mut reader = BufReader::new(read_stream);

    let (tx, rx) = mpsc::channel::<String>();
    let mut write_stream = stream;
    let _writer = thread::spawn(move || {
        for line in rx {
            if send_line(&mut write_stream, &line).is_err() {
                break;
            }
        }
    });

    if let Some(pass) = &cfg.password {
        let _ = tx.send(format!("PASS {}", pass));
    }
    let _ = tx.send(format!("NICK {}", cfg.nick));
    let _ = tx.send(format!("USER {} 0 * :{}", cfg.user, cfg.realname));

    let mut buf = String::new();
    let mut registered = false;
    let mut joined: HashSet<String> = HashSet::new();
    let mut next_list = Instant::now() + Duration::from_secs(1);

    let rpc_cfg = rpc::RpcConfig {
        max_request_bytes: 128 * 1024,
        max_response_bytes: 128 * 1024,
        max_frame_payload_bytes: 240,
        partial_timeout: Duration::from_secs(10),
    };
    let mut rpc_state = rpc::RpcState::new(rpc_cfg.clone());

    loop {
        let now = Instant::now();
        for (ch, req_id) in rpc_state.reap_timeouts(now) {
            for fr in rpc::build_err_frames(&rpc_cfg, &req_id, "timeout") {
                let _ = tx.send(format!("PRIVMSG {} :{}", ch, fr));
            }
        }

        buf.clear();
        match reader.read_line(&mut buf) {
            Ok(0) => {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::UnexpectedEof,
                    "irc connection closed by peer",
                ))
            }
            Ok(_) => {
                let line = buf.trim_end_matches(['\r', '\n']);
                if let Some(token) = parse_ping_token(line) {
                    let _ = tx.send(format!("PONG :{}", token));
                    continue;
                }

                if is_welcome_001(line) {
                    registered = true;
                    next_list = Instant::now();
                }

                if registered {
                    if let Some(ch) = parse_rpl_list_channel(line) {
                        if matchers::channel_matches_device_code(&ch, &device_code) {
                            let key = ch.to_ascii_lowercase();
                            if joined.insert(key) {
                                let _ = tx.send(format!("JOIN {}", ch));
                            }
                        }
                    }
                }

                if let Some((sender, target, text)) = parse_privmsg(line) {
                    if sender == cfg.nick {
                        continue;
                    }
                    if !text.starts_with("OA1 ") {
                        continue;
                    }
                    if !matchers::channel_matches_device_code(&target, &device_code) {
                        continue;
                    }
                    if !joined.contains(&target.to_ascii_lowercase()) {
                        continue;
                    }
                    let fr = match oa1::parse_frame(&text) {
                        Some(f) => f,
                        None => continue,
                    };
                    if fr.typ != "REQ" {
                        continue;
                    }

                    match rpc_state.ingest_req_frame(&target, &sender, &fr, Instant::now()) {
                        None => {}
                        Some(Ok(req)) => {
                            let tx2 = tx.clone();
                            let rpc_cfg2 = rpc_cfg.clone();
                            let exec_cfg2 = exec_cfg.clone();
                            thread::spawn(move || {
                                let res = exec::execute(&req.command, &exec_cfg2);
                                match res {
                                    Ok(out) => {
                                        for fr in rpc::build_res_frames(&rpc_cfg2, &req.req_id, &out) {
                                            let _ = tx2.send(format!(
                                                "PRIVMSG {} :{}",
                                                req.channel, fr
                                            ));
                                        }
                                    }
                                    Err(err) => {
                                        for fr in rpc::build_err_frames(&rpc_cfg2, &req.req_id, &err) {
                                            let _ = tx2.send(format!(
                                                "PRIVMSG {} :{}",
                                                req.channel, fr
                                            ));
                                        }
                                    }
                                }
                            });
                        }
                        Some(Err(err)) => {
                            for fr in rpc::build_err_frames(&rpc_cfg, &fr.req_id, &err) {
                                let _ = tx.send(format!("PRIVMSG {} :{}", target, fr));
                            }
                        }
                    }
                }
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {}
            Err(e) => return Err(e),
        }

        if registered && Instant::now() >= next_list {
            let _ = tx.send("LIST".to_string());
            next_list = Instant::now() + cfg.poll_interval;
        }
    }
}

fn send_line(stream: &mut TcpStream, line: &str) -> std::io::Result<()> {
    stream.write_all(line.as_bytes())?;
    stream.write_all(b"\r\n")?;
    stream.flush()
}

fn parse_ping_token(line: &str) -> Option<&str> {
    let s = line.trim();
    if !s.starts_with("PING") {
        return None;
    }
    // Typical shape: "PING :token"
    s.split_once(':').map(|(_, t)| t.trim())
}

fn is_welcome_001(line: &str) -> bool {
    // Typical shape: ":server 001 nick :welcome"
    let s = line.trim();
    let mut parts = s.split_whitespace();
    let first = parts.next().unwrap_or("");
    let second = parts.next().unwrap_or("");
    if first.starts_with(':') {
        second == "001"
    } else {
        first == "001"
    }
}

fn parse_rpl_list_channel(line: &str) -> Option<String> {
    // Typical shape:
    //   ":server 322 <nick> <channel> <users> :<topic>"
    // We want params[1] => channel.
    let s = line.trim();
    let mut parts = s.split_whitespace();
    let first = parts.next()?;
    let cmd = if first.starts_with(':') {
        parts.next()?
    } else {
        first
    };
    if cmd != "322" {
        return None;
    }
    let _nick = parts.next()?;
    let channel = parts.next()?;
    Some(channel.to_string())
}

fn parse_privmsg(line: &str) -> Option<(String, String, String)> {
    // Typical:
    //   ":nick!user@host PRIVMSG #chan :hello"
    let s = line.trim();
    if s.is_empty() {
        return None;
    }

    let (prefix, rest) = if s.starts_with(':') {
        let (p, r) = s.split_once(' ')?;
        (&p[1..], r)
    } else {
        ("", s)
    };

    let mut it = rest.splitn(2, ' ');
    let cmd = it.next()?;
    let rest2 = it.next().unwrap_or("");
    if cmd != "PRIVMSG" {
        return None;
    }

    let mut it2 = rest2.splitn(2, ' ');
    let target = it2.next()?.trim().to_string();
    let tail = it2.next().unwrap_or("").trim();
    let trailing = tail.strip_prefix(':').unwrap_or(tail).to_string();

    let sender = prefix_nick(prefix);
    Some((sender, target, trailing))
}

fn prefix_nick(prefix: &str) -> String {
    let p = prefix.trim();
    if p.is_empty() {
        return String::new();
    }
    if let Some((nick, _)) = p.split_once('!') {
        return nick.to_string();
    }
    if let Some((nick, _)) = p.split_once('@') {
        return nick.to_string();
    }
    p.to_string()
}
