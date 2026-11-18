#!/usr/bin/env python3
"""Check that example-api.env sets every variable docker-compose.yml uses without a default.

Usage: test/check_env_template.py

Compose lists the variables (`docker compose config --variables`), so the check
does not depend on how docker-compose.yml writes them.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    # --env-file /dev/null: a local .env must not affect the result
    result = subprocess.run(
        ["docker", "compose", "--env-file", "/dev/null", "config", "--variables", "--format", "json"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stderr, end="")
        sys.exit(result.returncode)
    variables = json.loads(result.stdout)
    template = (ROOT / "example-api.env").read_text(encoding="utf-8")
    defined = set(re.findall(r"^([A-Za-z_][A-Za-z0-9_]*)=", template, re.MULTILINE))

    needed = sorted(name for name, v in variables.items() if not v["DefaultValue"])
    missing = [name for name in needed if name not in defined]
    for name in missing:
        print(f"FAIL docker-compose.yml uses {name} without a default, and example-api.env does not set it")
    if missing:
        sys.exit(1)
    print(f"ok   example-api.env sets all {len(needed)} variables docker-compose.yml uses without a default")


if __name__ == "__main__":
    main()
