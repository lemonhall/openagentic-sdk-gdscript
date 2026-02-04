# v57 index

Goal: fix "Unicode parsing error" when streaming content that includes non-ASCII (e.g. Chinese) by ensuring SSE/HTTP body chunks are decoded as UTF-8 only after reassembling complete newline-terminated lines.

## Artifacts

- Plan: `docs/plan/v57-openai-responses-utf8-safe-stream-decoding.md`

