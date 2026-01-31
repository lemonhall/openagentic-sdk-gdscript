use std::fs::File;
use std::io::Read;
use std::process;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn canonicalize(input: &str) -> String {
    let mut out = String::new();
    for b in input.trim().bytes() {
        match b {
            b'0'..=b'9' => out.push(b as char),
            b'A'..=b'Z' => out.push(b as char),
            b'a'..=b'z' => out.push((b - 32) as char),
            _ => {}
        }
    }
    out
}

pub fn is_valid_canonical(code: &str) -> bool {
    let c = code.trim();
    if c.len() < 6 || c.len() > 16 {
        return false;
    }
    c.bytes().all(|b| matches!(b, b'0'..=b'9' | b'A'..=b'Z'))
}

pub fn generate() -> String {
    const ALPHABET: &[u8; 32] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    let mut buf = [0u8; 8];
    if !try_fill_from_urandom(&mut buf) {
        buf = fallback_entropy();
    }

    let mut bits = u64::from_le_bytes(buf);
    let mut out = String::with_capacity(10);
    for _ in 0..10 {
        let idx = (bits & 0b1_1111) as usize;
        out.push(ALPHABET[idx] as char);
        bits >>= 5;
    }
    out
}

fn try_fill_from_urandom(buf: &mut [u8]) -> bool {
    let mut f = match File::open("/dev/urandom") {
        Ok(f) => f,
        Err(_) => return false,
    };
    f.read_exact(buf).is_ok()
}

fn fallback_entropy() -> [u8; 8] {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos() as u128)
        .unwrap_or(0);
    let pid = process::id() as u128;
    let mixed = nanos ^ (pid << 64) ^ (nanos >> 32);
    (mixed as u64).to_le_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonicalize_keeps_alnum_and_uppercases() {
        assert_eq!(canonicalize("abCD-1234"), "ABCD1234");
        assert_eq!(canonicalize("  a_b c  "), "ABC");
    }

    #[test]
    fn validates_length_and_charset() {
        assert!(!is_valid_canonical(""));
        assert!(!is_valid_canonical("ABCDE"));
        assert!(is_valid_canonical("ABCDEF"));
        assert!(is_valid_canonical("ABCD1234"));
        assert!(!is_valid_canonical("ABCDEF1234567890123"));
        assert!(!is_valid_canonical("ABCDEF-1234"));
    }

    #[test]
    fn generate_produces_valid_code() {
        let c = generate();
        assert!(is_valid_canonical(&c));
    }
}

