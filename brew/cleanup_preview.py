#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BREWFILE_PATH = SCRIPT_DIR / "Brewfile"


def main() -> None:
    result = subprocess.run(
        ("brew", "bundle", "cleanup", "--file", str(BREWFILE_PATH)),
        cwd=SCRIPT_DIR,
        check=False,
    )
    sys.exit(0 if result.returncode == 1 else result.returncode)


if __name__ == "__main__":
    main()
