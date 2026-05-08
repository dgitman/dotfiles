#!/usr/bin/env python3
from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BREWFILE_PATH = SCRIPT_DIR / "Brewfile"
HOMEBREW_INSTALL_URL = "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"


def find_brew() -> str | None:
    existing = shutil.which("brew")
    if existing:
        return existing

    for candidate in ("/opt/homebrew/bin/brew", "/usr/local/bin/brew"):
        if Path(candidate).exists():
            return candidate

    return None


def run(*args: str) -> None:
    subprocess.run(args, cwd=SCRIPT_DIR, check=True)


def install_homebrew() -> str:
    with urllib.request.urlopen(HOMEBREW_INSTALL_URL) as response:
        installer = response.read()

    with tempfile.NamedTemporaryFile("wb", delete=False) as file:
        file.write(installer)
        installer_path = Path(file.name)

    try:
        os.chmod(installer_path, 0o700)
        run("/bin/bash", str(installer_path))
    finally:
        installer_path.unlink(missing_ok=True)

    brew = find_brew()
    if not brew:
        raise RuntimeError("Homebrew install finished, but brew was not found.")

    return brew


def main() -> None:
    brew = find_brew()
    if brew:
        run(brew, "update")
    else:
        brew = install_homebrew()

    check = subprocess.run(
        (brew, "bundle", "check", "--file", str(BREWFILE_PATH)),
        cwd=SCRIPT_DIR,
        check=False,
    )
    if check.returncode == 0:
        return

    run(brew, "bundle", "install", "--file", str(BREWFILE_PATH))


if __name__ == "__main__":
    main()
