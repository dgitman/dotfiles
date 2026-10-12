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


TEMPLATE = "-----\n\n<!-- Do not tick a checkbox if you haven’t performed its action. Honesty is indispensable for a smooth review process. -->\n<!-- Use [x] to mark item done before creation, or just click the checkboxes with device pointer after creation -->\n<!-- In the following questions `<cask>` is the token of the cask you're editing. -->\n\nAfter making any changes to a cask, existing or new, verify:\n\n- [ ] The submission is for [a stable version](https://docs.brew.sh/Acceptable-Casks#stable-versions) or [documented exception](https://docs.brew.sh/Acceptable-Casks#but-there-is-no-stable-version).\n- [ ] `brew audit --cask --online <cask>` is error-free.\n- [ ] `brew style --fix <cask>` reports no offenses.\n\nAdditionally, if adding a new cask:\n\n- [ ] Named the cask according to the [token reference](https://docs.brew.sh/Cask-Cookbook#token-reference).\n- [ ] Checked the cask was not [already refused](https://github.com/search?q=repo%3AHomebrew%2Fhomebrew-cask+is%3Aclosed+is%3Aunmerged+&type=pullrequests) (add your cask's name to the end of the search field).\n- [ ] `brew audit --cask --new <cask>` worked successfully.\n- [ ] `HOMEBREW_NO_INSTALL_FROM_API=1 brew install --cask <cask>` worked successfully.\n- [ ] `brew uninstall --cask <cask>` worked successfully.\n\n-----\n\n- [ ] I did not use AI/LLM to create this PR, or I disclosed the tool/model below and reviewed its output, including [`zap` stanza](https://docs.brew.sh/Cask-Cookbook#stanza-zap) paths; I did not attribute commits to AI and will answer maintainer questions and review comments myself without AI/LLM.\n\n<!-- If AI was used, explain below how it was used and how you verified the changes. Non-maintainers may only have one AI-assisted PR open at a time. See https://docs.brew.sh/Responsible-AI-Usage for guidance. -->\n\n-----\n"


class SubmissionGates(unittest.TestCase):
    def test_template_preserves_human_review_and_new_cask_checkboxes(self):
        body = bump.draft_body(TEMPLATE, "26.0")
        self.assertIn("- [x] `brew audit --cask --online <cask>` is error-free.", body)
        self.assertIn("- [x] `brew style --fix <cask>` reports no offenses.", body)
        self.assertIn("- [ ] The submission is for", body)
        self.assertIn("- [ ] I did not use AI/LLM", body)
        self.assertIn("- [ ] `brew audit --cask --new <cask>`", body)
        self.assertEqual(body.count("- [x]"), 2)

    def test_changed_template_fails_instead_of_inventing_checkboxes(self):
        with self.assertRaises(ValueError):
            bump.draft_body("Unexpected template", "26.0")

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
            template_path = Path(temp) / ".github" / "PULL_REQUEST_TEMPLATE.md"
            template_path.parent.mkdir()
            template_path.write_text(TEMPLATE)
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
