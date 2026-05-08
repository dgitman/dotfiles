#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BREWFILE_PATH = SCRIPT_DIR / "Brewfile"
# Brewfile may be a symlink; resolve to the actual file for git operations
BREWFILE_REAL = BREWFILE_PATH.resolve()
GIT_DIR = next(
    p for p in [BREWFILE_REAL.parent, *BREWFILE_REAL.parents]
    if (p / ".git").exists()
)


def run(*args: str, cwd: Path) -> None:
    subprocess.run(args, cwd=cwd, check=True)


def has_staged_changes() -> bool:
    result = subprocess.run(
        ("git", "diff", "--cached", "--quiet"),
        cwd=GIT_DIR,
        check=False,
    )
    return result.returncode != 0


def main() -> None:
    run("brew", "bundle", "dump", "--describe", "--file", str(BREWFILE_REAL), "-f", cwd=SCRIPT_DIR)
    run("git", "add", str(BREWFILE_REAL.relative_to(GIT_DIR)), cwd=GIT_DIR)

    if not has_staged_changes():
        print("Brewfile is already up to date.")
        return

    run("git", "commit", "-m", "Brewfile update", cwd=GIT_DIR)
    run("git", "push", cwd=GIT_DIR)


if __name__ == "__main__":
    main()
