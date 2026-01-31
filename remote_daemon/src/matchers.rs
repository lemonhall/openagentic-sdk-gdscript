use crate::device_code;

pub fn channel_matches_device_code(channel: &str, device_code_raw: &str) -> bool {
    let code = device_code::canonicalize(device_code_raw);
    if !device_code::is_valid_canonical(&code) {
        return false;
    }

    let ch = channel.trim().to_ascii_lowercase();
    let code_l = code.to_ascii_lowercase();
    if !ch.starts_with("#oa_") {
        return false;
    }

    let needle = format!("_dev_{}", code_l);
    match ch.find(&needle) {
        None => false,
        Some(idx) => {
            let end = idx + needle.len();
            end == ch.len() || ch.as_bytes().get(end) == Some(&b'_')
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_expected_channel_shape() {
        assert!(channel_matches_device_code(
            "#oa_desk_desk_1_dev_abcd1234_1a2b3c",
            "ABCD-1234"
        ));
        assert!(!channel_matches_device_code("#random", "ABCD1234"));
        assert!(!channel_matches_device_code("#oa_ws_x", "ABCD1234"));
    }
}

