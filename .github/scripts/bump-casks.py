"""Run Homebrew's deterministic version bumps on a disposable macOS runner."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys

UPSTREAM = "Homebrew/homebrew-cask"
FORK = "dgitman/homebrew-cask"


def run(*args, cwd=None):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=3600)
    # Never print environment variables or credential-bearing git remote URLs.
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    result.check_returncode()
    return result.stdout


def summary(message):
    print(message)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
        output.write(message + "\n\n")


def candidate(output):
    """Only accept scalar versions; Homebrew's complex variants need review."""
    current = re.search(r"^Current cask version:\s+(\S+)\s*$", output, re.M)
    latest = re.search(r"^Bump-ready version:\s+(\S+)\s*$", output, re.M)
    latest = latest or re.search(r"^Latest livecheck version:\s+(\S+)\s*$", output, re.M)
    if not current or not latest or current[1] == latest[1]:
        return None
    if not re.fullmatch(r"[0-9][A-Za-z0-9.,_+:-]*", latest[1]):
        return None
    if "newer than upstream" in output.lower():
        return None
    if not re.search(r"^Duplicate pull requests:\s+none\s*$", output, re.M):
        return None
    if not re.search(r"^Open bump pull requests:\s+none\s*$", output, re.M):
        return None
    if re.search(r"^\s*(arm|intel|linux arm|linux intel):", output, re.M):
        return None
    return latest[1]


def search(query):
    return run("gh", "api", "--method", "GET", "search/issues",
               "-f", "q=" + query, "--jq", ".total_count").strip() != "0"


def draft_body(template, macos_version):
    # Keep upstream wording and all human-review checkboxes intact.
    for checklist in (
        "- [ ] `brew audit --cask --online <cask>` is error-free.",
        "- [ ] `brew style --fix <cask>` reports no offenses.",
    ):
        if checklist not in template:
            raise ValueError("Upstream cask template changed; review its checklist")
        template = template.replace(checklist, checklist.replace("[ ]", "[x]"), 1)
    return (
        "Built and tested on macOS " + macos_version + ".\n\n"
        + template.rstrip() + "\n\n"
        + "Homebrew generated the version/checksum changes. Codex (GPT-6) assisted "
        "with the automation. Online audit, style, installation and uninstall checks "
        "passed automatically. Contributor review of the release and unchanged zap "
        "paths is pending; maintainer replies will be written by the contributor.\n"
    )


def main():
    # Conservatively keep only one automated upstream PR open, including drafts.
    if search("repo:" + UPSTREAM + " is:pr is:open author:dgitman"):
        summary("An upstream PR is already open; no additional PR was created.")
        return
    run("gh", "api", "repos/" + FORK, "--jq", ".full_name")
    tap = Path(run("brew", "--repository", "homebrew/cask").strip())
    base = run("git", "rev-parse", "HEAD", cwd=tap).strip()
    run("git", "config", "user.name", "David Gitman", cwd=tap)
    run("git", "config", "user.email", "1743448+dgitman@users.noreply.github.com", cwd=tap)
    # bundle list reads declarations; it does not install the Mac-local tap.
    names = run("brew", "bundle", "list", "--cask", "--file=dot_Brewfile").splitlines()
    failures = []
    for name in sorted(set(names)):
        if not re.fullmatch(r"[a-z0-9@+._-]+(?:/[a-z0-9@+._-]+){0,2}", name):
            raise ValueError("Unexpected cask token")
        if "/" in name and not name.startswith("homebrew/cask/"):
            summary("Third-party cask needs a separate tap workflow: " + name)
            continue
        token = name.rsplit("/", 1)[-1]
        qualified = "homebrew/cask/" + token
        try:
            output = run("brew", "bump", "--cask", qualified)
            version = candidate(output)
            if not version:
                continue
            query = "repo:" + UPSTREAM + ' is:pr "' + token + '" in:title '
            if search(query + "is:open"):
                summary("Existing PR found for " + token + "; skipped.")
                continue
            if search(query + "is:closed is:unmerged"):
                summary("Closed unmerged PR history needs review for " + token + "; skipped.")
                continue
            title = token + " " + version
            if len(title) > 50:
                summary("Commit title needs manual shortening: " + title)
                continue
            # Homebrew checks eligibility, computes checksums and runs audit/style.
            run("brew", "bump-cask-pr", qualified, "--version=" + version, "--write-only")
            changed = run("git", "diff", "--name-only", cwd=tap).splitlines()
            if len(changed) != 1 or not changed[0].startswith("Casks/") or not changed[0].endswith("/" + token + ".rb"):
                raise ValueError("Expected exactly the selected cask to change")
            diff = run("git", "diff", "--unified=0", "--", changed[0], cwd=tap)
            # Reject stanza churn and retain zap paths unchanged.
            for line in diff.splitlines():
                if line[:1] in ("+", "-") and not line.startswith(("+++", "---")):
                    if not re.match(r'^[+-]\s*(version|sha256|url)\s+', line):
                        raise ValueError("Diff needs manual review beyond version/checksum/URL")
            run("brew", "audit", "--cask", "--online", qualified)
            before_style = run("git", "diff", "--", changed[0], cwd=tap)
            run("brew", "style", "--fix", qualified)
            if before_style != run("git", "diff", "--", changed[0], cwd=tap):
                raise ValueError("Style changed the cask beyond the prepared bump")
            # Failed installation or removal prevents any push or PR.
            run("brew", "install", "--cask", qualified)
            run("brew", "uninstall", "--cask", qualified)
            branch = "codex/bump-" + token.replace("@", "-") + "-" + hashlib.sha256(title.encode()).hexdigest()[:12]
            run("git", "switch", "-c", branch, cwd=tap)
            run("git", "add", "--", changed[0], cwd=tap)
            run("git", "commit", "-m", title, cwd=tap)
            # Commit the exact tested file instead of re-running upstream detection.
            run("git", "push", "https://github.com/" + FORK + ".git", "HEAD:refs/heads/" + branch, cwd=tap)
            body = Path(os.environ["RUNNER_TEMP"]) / "cask-pr-body.md"
            body.write_text(draft_body(
                (tap / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(),
                run("sw_vers", "-productVersion").strip(),
            ))
            url = run("gh", "pr", "create", "--repo", UPSTREAM, "--head", "dgitman:" + branch,
                      "--title", title, "--body-file", str(body), "--draft").strip()
            summary("Created draft for contributor review: " + url)
            return
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as error:
            failures.append(token)
            summary("Cask needs attention: " + token + " (" + type(error).__name__ + ")")
        finally:
            # This is a disposable runner checkout, never the user's local files.
            run("git", "switch", "--detach", base, cwd=tap)
            run("git", "restore", "--source=" + base, "--staged", "--worktree", ".", cwd=tap)
    if failures:
        raise RuntimeError("Failed casks: " + ", ".join(failures))
    summary("No eligible cask update was submitted.")


if __name__ == "__main__":
    main()
