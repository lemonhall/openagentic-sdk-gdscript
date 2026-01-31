use std::collections::HashSet;
use std::io::{BufRead, BufReader, Write};
use std::net::TcpStream;
use std::time::{Duration, Instant};

use crate::matchers;

pub struct IrcConfig {
    pub host: String,
    pub port: u16,
    pub nick: String,
    pub user: String,
    pub realname: String,
    pub password: Option<String>,
    pub poll_interval: Duration,
}

pub fn run_polling_join_loop(cfg: IrcConfig, device_code: String) -> std::io::Result<()> {
    let addr = format!("{}:{}", cfg.host, cfg.port);
    let mut stream = TcpStream::connect(addr)?;
    stream.set_read_timeout(Some(Duration::from_millis(500)))?;
    stream.set_write_timeout(Some(Duration::from_secs(5)))?;

    // Clone for buffered read loop.
    let read_stream = stream.try_clone()?;
    let mut reader = BufReader::new(read_stream);

    if let Some(pass) = &cfg.password {
        send_line(&mut stream, &format!("PASS {}", pass))?;
    }
    send_line(&mut stream, &format!("NICK {}", cfg.nick))?;
    send_line(
        &mut stream,
        &format!("USER {} 0 * :{}", cfg.user, cfg.realname),
    )?;

    let mut buf = String::new();
    let mut registered = false;
    let mut joined: HashSet<String> = HashSet::new();
    let mut next_list = Instant::now() + Duration::from_secs(1);

    loop {
        buf.clear();
        match reader.read_line(&mut buf) {
            Ok(0) => return Ok(()),
            Ok(_) => {
                let line = buf.trim_end_matches(['\r', '\n']);
                if let Some(token) = parse_ping_token(line) {
                    send_line(&mut stream, &format!("PONG :{}", token))?;
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
                                send_line(&mut stream, &format!("JOIN {}", ch))?;
                            }
                        }
                    }
                }
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock || e.kind() == std::io::ErrorKind::TimedOut => {}
            Err(e) => return Err(e),
        }

        if registered && Instant::now() >= next_list {
            send_line(&mut stream, "LIST")?;
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

