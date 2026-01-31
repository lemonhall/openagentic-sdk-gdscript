use std::io::Read;
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct ExecConfig {
    pub enable_bash: bool,
    pub bash_timeout: Duration,
    pub max_capture_bytes: usize,
}

pub fn execute(command: &str, cfg: &ExecConfig) -> Result<String, String> {
    let cmd = command.trim();
    if cmd.is_empty() {
        return Ok(String::new());
    }
    if !cfg.enable_bash {
        return Ok(format!("ECHO: {}", cmd));
    }
    run_bash(cmd, cfg)
}

fn run_bash(command: &str, cfg: &ExecConfig) -> Result<String, String> {
    let mut child = Command::new("bash")
        .arg("-lc")
        .arg(command)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("spawn_failed: {}", e))?;

    let stdout = child.stdout.take().ok_or("missing_stdout")?;
    let stderr = child.stderr.take().ok_or("missing_stderr")?;

    let max = cfg.max_capture_bytes;
    let t_out = thread::spawn(move || drain_with_limit(stdout, max));
    let t_err = thread::spawn(move || drain_with_limit(stderr, max));

    let start = Instant::now();
    let mut timed_out = false;
    let status = loop {
        match child.try_wait().map_err(|e| format!("wait_failed: {}", e))? {
            Some(st) => break st,
            None => {
                if start.elapsed() > cfg.bash_timeout {
                    timed_out = true;
                    let _ = child.kill();
                    break child
                        .wait()
                        .map_err(|e| format!("wait_failed: {}", e))?;
                }
                thread::sleep(Duration::from_millis(50));
            }
        }
    };

    let (out_bytes, out_trunc) = t_out
        .join()
        .map_err(|_| "read_stdout_failed".to_string())?
        .map_err(|e| format!("read_stdout_failed: {}", e))?;
    let (err_bytes, err_trunc) = t_err
        .join()
        .map_err(|_| "read_stderr_failed".to_string())?
        .map_err(|e| format!("read_stderr_failed: {}", e))?;

    let mut text = String::new();
    if !out_bytes.is_empty() {
        text.push_str(&String::from_utf8_lossy(&out_bytes));
    }
    if !err_bytes.is_empty() {
        if !text.is_empty() && !text.ends_with('\n') {
            text.push('\n');
        }
        text.push_str(&String::from_utf8_lossy(&err_bytes));
    }

    if out_trunc || err_trunc {
        if !text.is_empty() && !text.ends_with('\n') {
            text.push('\n');
        }
        text.push_str("...[truncated]...");
    }

    if timed_out {
        if !text.is_empty() && !text.ends_with('\n') {
            text.push('\n');
        }
        text.push_str("timeout");
        return Err(text);
    }

    if !status.success() {
        let code = status.code().unwrap_or(-1);
        if !text.is_empty() && !text.ends_with('\n') {
            text.push('\n');
        }
        text.push_str(&format!("(exit code: {})", code));
    }

    Ok(text)
}

fn drain_with_limit<R: Read>(mut r: R, max_bytes: usize) -> std::io::Result<(Vec<u8>, bool)> {
    let mut out: Vec<u8> = Vec::new();
    let mut tmp = [0u8; 4096];
    let mut truncated = false;

    loop {
        let n = r.read(&mut tmp)?;
        if n == 0 {
            break;
        }
        if max_bytes == 0 {
            truncated = true;
            continue;
        }
        if out.len() < max_bytes {
            let take = usize::min(max_bytes - out.len(), n);
            out.extend_from_slice(&tmp[..take]);
            if take < n {
                truncated = true;
            }
        } else {
            truncated = true;
        }
    }

    Ok((out, truncated))
}

