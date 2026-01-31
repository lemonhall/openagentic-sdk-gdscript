#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Frame {
    pub typ: String,
    pub req_id: String,
    pub seq: u32,
    pub more: bool,
    pub payload: String,
}

pub fn escape_payload(s: &str) -> String {
    let mut out = String::new();
    for ch in s.chars() {
        match ch {
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            _ => out.push(ch),
        }
    }
    out
}

pub fn unescape_payload(s: &str) -> String {
    let mut out = String::new();
    let mut it = s.chars();
    while let Some(ch) = it.next() {
        if ch != '\\' {
            out.push(ch);
            continue;
        }
        match it.next() {
            Some('n') => out.push('\n'),
            Some('r') => out.push('\r'),
            Some('t') => out.push('\t'),
            Some('\\') => out.push('\\'),
            Some(other) => {
                out.push('\\');
                out.push(other);
            }
            None => out.push('\\'),
        }
    }
    out
}

pub fn chunk_utf8_by_bytes(s: &str, max_bytes: usize) -> Vec<String> {
    if s.is_empty() {
        return vec![String::new()];
    }
    if max_bytes == 0 {
        return vec![String::new()];
    }

    let bytes_len = s.as_bytes().len();
    let mut chunks: Vec<String> = Vec::new();
    let mut start: usize = 0;

    while start < bytes_len {
        let mut end = usize::min(start + max_bytes, bytes_len);
        while end > start && !s.is_char_boundary(end) {
            end -= 1;
        }
        if end == start {
            // Fallback: max_bytes is too small for at least one char; take one char.
            let ch_len = s[start..]
                .chars()
                .next()
                .map(|c| c.len_utf8())
                .unwrap_or(1);
            end = usize::min(start + ch_len, bytes_len);
        }
        chunks.push(s[start..end].to_string());
        start = end;
    }

    if chunks.is_empty() {
        chunks.push(String::new());
    }
    chunks
}

pub fn parse_frame(_text: &str) -> Option<Frame> {
    let text = _text.trim_end();
    let mut it = text.splitn(6, ' ');

    let marker = it.next()?;
    if marker != "OA1" {
        return None;
    }
    let typ = it.next()?.to_string();
    let req_id = it.next()?.to_string();
    let seq: u32 = it.next()?.parse().ok()?;
    let more_raw: u32 = it.next()?.parse().ok()?;
    let payload = it.next().unwrap_or("").to_string();

    Some(Frame {
        typ,
        req_id,
        seq,
        more: more_raw != 0,
        payload,
    })
}

pub fn make_frame(typ: &str, req_id: &str, seq: u32, more: bool, payload: &str) -> String {
    format!(
        "OA1 {} {} {} {} {}",
        typ,
        req_id,
        seq,
        if more { 1 } else { 0 },
        payload
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn escaping_roundtrip() {
        let s = "a\\b\nc\rd\t";
        let esc = escape_payload(s);
        let back = unescape_payload(&esc);
        assert_eq!(back, s);
    }

    #[test]
    fn parse_and_make_roundtrip() {
        let line = make_frame("REQ", "abc123", 1, false, escape_payload("echo hi").as_str());
        let fr = parse_frame(&line).expect("parse_frame");
        assert_eq!(fr.typ, "REQ");
        assert_eq!(fr.req_id, "abc123");
        assert_eq!(fr.seq, 1);
        assert_eq!(fr.more, false);
        assert_eq!(unescape_payload(&fr.payload), "echo hi");
    }

    #[test]
    fn chunks_by_utf8_bytes() {
        // "你好" is 6 bytes in UTF-8.
        let s = "你好";
        let chunks = chunk_utf8_by_bytes(s, 3);
        assert_eq!(chunks.len(), 2);
        assert_eq!(chunks.join(""), s);
    }
}
