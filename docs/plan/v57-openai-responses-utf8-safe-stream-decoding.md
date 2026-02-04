# v57 — OpenAI Responses: UTF-8 safe stream decoding

## Problem

Sending or receiving non-ASCII text (e.g. `你好啊`) could produce runtime errors like:

- `Unicode parsing error ... Missing e4 UTF-8 continuation byte`
- `Unicode parsing error ... Invalid UTF-8 leading byte (bd)`
- `Unicode parsing error ... Invalid UTF-8 leading byte (a0)`

These bytes (`E4 BD A0`) correspond to the UTF-8 encoding of `你`. The errors indicate the byte stream was decoded in the middle of a multi-byte character.

## Root cause

`OAOpenAIResponsesProvider` decoded each `HTTPClient.read_response_body_chunk()` chunk directly with `chunk.get_string_from_utf8()`. HTTP chunks can split UTF-8 sequences arbitrarily, so decoding per-chunk can produce invalid UTF-8 and replacement characters (U+FFFD).

## Approach

1. Add a regression test that simulates chunk-splitting inside a multi-byte character and expects the decoded line to remain intact.
2. Update provider to buffer raw bytes, split on newline (`0x0A`), then decode each full line as UTF-8.
3. Keep behavior consistent for tail flush and error-body capture.

## Changes

- `addons/openagentic/providers/OAOpenAIResponsesProvider.gd`
  - Add `_test_decode_lines_from_chunks()` helper for tests/debugging.
  - Stream decoding: buffer `PackedByteArray`, split by `'\n'`, decode per-line.
  - Error-body draining: accumulate bytes and decode safely (with truncation).
- `tests/addons/openagentic/test_utf8_chunk_line_decode.gd`
  - Red/Green regression for UTF-8 chunk splitting.

## Verification

Run:

- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_utf8_chunk_line_decode.gd`
- `scripts/run_godot_tests.sh --one tests/addons/openagentic/test_sse_parser.gd`

Expected: both `PASS`.

