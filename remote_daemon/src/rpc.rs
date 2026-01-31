use std::collections::HashMap;
use std::time::{Duration, Instant};

use crate::oa1;

#[derive(Debug, Clone)]
pub struct RpcConfig {
    pub max_request_bytes: usize,
    pub max_response_bytes: usize,
    pub max_frame_payload_bytes: usize,
    pub partial_timeout: Duration,
}

#[derive(Debug, Clone)]
pub struct Request {
    pub channel: String,
    pub sender: String,
    pub req_id: String,
    pub command: String,
}

#[derive(Debug, Clone)]
struct InflightReq {
    sender: String,
    last_update: Instant,
    max_seq: u32,
    got_final: bool,
    bytes: usize,
    chunks: HashMap<u32, String>,
}

pub struct RpcState {
    cfg: RpcConfig,
    inflight: HashMap<(String, String), InflightReq>,
}

pub fn build_res_frames(cfg: &RpcConfig, req_id: &str, payload_text: &str) -> Vec<String> {
    build_frames(cfg, "RES", req_id, payload_text)
}

pub fn build_err_frames(cfg: &RpcConfig, req_id: &str, message: &str) -> Vec<String> {
    build_frames(cfg, "ERR", req_id, message)
}

fn build_frames(cfg: &RpcConfig, typ: &str, req_id: &str, payload_text: &str) -> Vec<String> {
    let (text, truncated) = truncate_utf8_to_bytes(payload_text, cfg.max_response_bytes);
    let mut full = text;
    if truncated {
        if !full.ends_with('\n') {
            full.push('\n');
        }
        full.push_str("...[truncated]...");
    }

    let escaped = oa1::escape_payload(&full);
    let chunks = oa1::chunk_utf8_by_bytes(&escaped, cfg.max_frame_payload_bytes);
    let mut out = Vec::new();
    for (i, ch) in chunks.iter().enumerate() {
        let seq = (i as u32) + 1;
        let more = i + 1 < chunks.len();
        out.push(oa1::make_frame(typ, req_id, seq, more, ch));
    }
    if out.is_empty() {
        out.push(oa1::make_frame(typ, req_id, 1, false, ""));
    }
    out
}

fn truncate_utf8_to_bytes(s: &str, max_bytes: usize) -> (String, bool) {
    if max_bytes == 0 {
        return (String::new(), !s.is_empty());
    }
    if s.as_bytes().len() <= max_bytes {
        return (s.to_string(), false);
    }

    let mut end = max_bytes;
    while end > 0 && !s.is_char_boundary(end) {
        end -= 1;
    }
    if end == 0 {
        return (String::new(), true);
    }
    (s[..end].to_string(), true)
}

impl RpcState {
    pub fn new(cfg: RpcConfig) -> Self {
        Self {
            cfg,
            inflight: HashMap::new(),
        }
    }

    pub fn ingest_req_frame(
        &mut self,
        channel: &str,
        sender: &str,
        frame: &oa1::Frame,
        now: Instant,
    ) -> Option<Result<Request, String>> {
        if frame.typ != "REQ" {
            return None;
        }
        if frame.req_id.trim().is_empty() || frame.seq == 0 {
            return Some(Err("invalid_frame".to_string()));
        }

        let key = (channel.to_string(), frame.req_id.clone());
        let ent = self.inflight.entry(key.clone()).or_insert_with(|| InflightReq {
            sender: sender.to_string(),
            last_update: now,
            max_seq: 0,
            got_final: false,
            bytes: 0,
            chunks: HashMap::new(),
        });

        // Basic trust/safety: don't allow sender changes mid-stream.
        if ent.sender != sender {
            self.inflight.remove(&key);
            return Some(Err("sender_changed".to_string()));
        }

        ent.last_update = now;
        ent.max_seq = ent.max_seq.max(frame.seq);

        if !ent.chunks.contains_key(&frame.seq) {
            ent.bytes = ent
                .bytes
                .saturating_add(frame.payload.as_bytes().len());
            ent.chunks.insert(frame.seq, frame.payload.clone());
        }

        if ent.bytes > self.cfg.max_request_bytes {
            self.inflight.remove(&key);
            return Some(Err("too_large".to_string()));
        }

        if !frame.more {
            ent.got_final = true;
        }

        if !ent.got_final {
            return None;
        }

        let max_seq = ent.max_seq;
        for seq in 1..=max_seq {
            if !ent.chunks.contains_key(&seq) {
                self.inflight.remove(&key);
                return Some(Err("missing_chunk".to_string()));
            }
        }

        let mut joined = String::new();
        for seq in 1..=max_seq {
            if let Some(p) = ent.chunks.get(&seq) {
                joined.push_str(p);
            }
        }
        self.inflight.remove(&key);

        let command = oa1::unescape_payload(&joined);
        Some(Ok(Request {
            channel: channel.to_string(),
            sender: sender.to_string(),
            req_id: frame.req_id.clone(),
            command,
        }))
    }

    pub fn reap_timeouts(&mut self, now: Instant) -> Vec<(String, String)> {
        let mut expired: Vec<(String, String)> = Vec::new();
        let timeout = self.cfg.partial_timeout;
        self.inflight.retain(|(ch, req_id), ent| {
            if now.duration_since(ent.last_update) > timeout {
                expired.push((ch.clone(), req_id.clone()));
                false
            } else {
                true
            }
        });
        expired
    }

    pub fn build_res_frames(&self, req_id: &str, payload_text: &str) -> Vec<String> {
        build_res_frames(&self.cfg, req_id, payload_text)
    }

    pub fn build_err_frames(&self, req_id: &str, message: &str) -> Vec<String> {
        build_err_frames(&self.cfg, req_id, message)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cfg() -> RpcConfig {
        RpcConfig {
            max_request_bytes: 128 * 1024,
            max_response_bytes: 128 * 1024,
            max_frame_payload_bytes: 8,
            partial_timeout: Duration::from_secs(10),
        }
    }

    #[test]
    fn reassembles_two_chunk_req() {
        let mut st = RpcState::new(cfg());
        let now = Instant::now();

        let f1 = oa1::Frame {
            typ: "REQ".to_string(),
            req_id: "r1".to_string(),
            seq: 1,
            more: true,
            payload: oa1::escape_payload("echo "),
        };
        let f2 = oa1::Frame {
            typ: "REQ".to_string(),
            req_id: "r1".to_string(),
            seq: 2,
            more: false,
            payload: oa1::escape_payload("hi"),
        };

        assert!(st.ingest_req_frame("#c", "desk", &f1, now).is_none());
        let done = st
            .ingest_req_frame("#c", "desk", &f2, now)
            .expect("completion");
        let req = done.expect("ok request");
        assert_eq!(req.command, "echo hi");
    }

    #[test]
    fn response_frames_are_chunked_and_mark_more() {
        let st = RpcState::new(cfg());
        let frames = st.build_res_frames("r1", "0123456789abcdef");
        assert!(frames.len() >= 2);
        assert!(frames[0].contains(" 1 1 "));
        assert!(frames.last().unwrap().contains(" 0 "));
    }
}
