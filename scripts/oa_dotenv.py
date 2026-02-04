from __future__ import annotations

import os
from pathlib import Path


def _strip_quotes(v: str) -> str:
    v = v.strip()
    if len(v) >= 2 and ((v[0] == v[-1] == '"') or (v[0] == v[-1] == "'")):
        return v[1:-1]
    return v


def load_dotenv_file(path: str | Path, *, override: bool = False) -> bool:
    p = Path(path)
    if not p.is_file():
        return False

    for raw_line in p.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if not key:
            continue
        value = _strip_quotes(value)
        if not override and key in os.environ:
            continue
        os.environ[key] = value
    return True


def load_repo_dotenv(*, override: bool = False) -> bool:
    root = Path(__file__).resolve().parent.parent
    return load_dotenv_file(root / ".env", override=override)

