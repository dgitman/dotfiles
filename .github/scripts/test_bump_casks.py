import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("bump", Path(__file__).with_name("bump-casks.py"))
bump = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bump)

PREVIEW = """Current cask version:     1.0
Latest livecheck version: 2.0
Duplicate pull requests:  none
Open bump pull requests:  none
"""


class SubmissionGates(unittest.TestCase):
    def test_no_downgrade_or_arch_variant(self):
        self.assertIsNone(bump.candidate(PREVIEW + "Current version is newer than upstream"))
        self.assertIsNone(bump.candidate(PREVIEW + "                          intel: 3.0\n"))

    def test_release_cooldown_uses_ready_version(self):
        self.assertEqual(bump.candidate(PREVIEW + "Bump-ready version:       1.5\n"), "1.5")

    def test_duplicates_do_not_submit(self):
        self.assertIsNone(bump.candidate(PREVIEW.replace("none", "https://github.com/example")))

    def exercise(self, failed_command):
        calls = []
        with tempfile.TemporaryDirectory() as temp:
            def fake_run(*args, cwd=None):
                calls.append(args)
                if args[:2] == ("brew", "--repository"):
                    return temp + "\n"
                if args[:3] == ("git", "rev-parse", "HEAD"):
                    return "base\n"
                if args[:3] == ("brew", "bundle", "list"):
                    return "example\n"
                if args[:2] == ("brew", "bump"):
                    return PREVIEW
                if args[:3] == ("git", "diff", "--name-only"):
                    return "Casks/e/example.rb\n"
                if args[:2] == ("git", "diff"):
                    return '@@ -1 +1 @@\n-version "1.0"\n+version "2.0"\n'
                if args[:2] == ("brew", failed_command):
                    raise subprocess.CalledProcessError(1, args)
                if args[:3] == ("gh", "pr", "create"):
                    return "https://github.com/Homebrew/homebrew-cask/pull/1\n"
                if args[:2] == ("sw_vers", "-productVersion"):
                    return "26.0\n"
                return ""
            with patch.object(bump, "run", fake_run), patch.object(bump, "search", return_value=False), patch.object(bump, "summary"), patch.dict(os.environ, {"RUNNER_TEMP": temp}):
                if failed_command:
                    with self.assertRaises(RuntimeError):
                        bump.main()
                else:
                    bump.main()
        return calls

    def test_failed_install_never_pushes_or_opens_pr(self):
        calls = self.exercise("install")
        self.assertFalse(any(c[:2] == ("git", "push") or c[:3] == ("gh", "pr", "create") for c in calls))

    def test_failed_uninstall_never_pushes_or_opens_pr(self):
        calls = self.exercise("uninstall")
        self.assertFalse(any(c[:2] == ("git", "push") or c[:3] == ("gh", "pr", "create") for c in calls))

    def test_passed_validation_creates_draft(self):
        calls = self.exercise(None)
        create = next(c for c in calls if c[:3] == ("gh", "pr", "create"))
        self.assertIn("--draft", create)
        self.assertLess(next(i for i, c in enumerate(calls) if c[:2] == ("brew", "uninstall")),
                        next(i for i, c in enumerate(calls) if c[:2] == ("git", "push")))


if __name__ == "__main__":
    unittest.main()
