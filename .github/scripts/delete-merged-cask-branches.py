"""Remove fork branches only when their exact tip belongs to a merged upstream PR."""
import json
import os
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

FORK = "dgitman/homebrew-cask"
UPSTREAM = "Homebrew/homebrew-cask"


def api(path, method="GET"):
    request = Request("https://api.github.com/" + path, method=method, headers={
        "Authorization": "Bearer " + os.environ["GH_TOKEN"],
        "Accept": "application/vnd.github+json",
    })
    with urlopen(request, timeout=60) as response:
        data = response.read()
        return json.loads(data) if data else None


def pages(path, **parameters):
    page = 1
    while True:
        batch = api(path + "?" + urlencode(dict(parameters, per_page=100, page=page)))
        yield from batch
        if len(batch) < 100:
            return
        page += 1


def eligible(pr, branch, sha):
    return (
        pr.get("merged_at") is not None
        and pr.get("state") == "closed"
        and pr.get("base", {}).get("repo", {}).get("full_name") == UPSTREAM
        and pr.get("head", {}).get("repo", {}).get("full_name") == FORK
        and pr.get("head", {}).get("ref") == branch
        and pr.get("head", {}).get("sha") == sha
    )


def main():
    dry_run = os.environ.get("DRY_RUN", "false") == "true"
    default_branch = api("repos/" + FORK)["default_branch"]
    results = []
    for branch in pages("repos/" + FORK + "/branches"):
        name = branch["name"]
        if name == default_branch or branch["protected"]:
            continue
        head = "dgitman:" + name
        candidates = list(pages("repos/" + UPSTREAM + "/pulls", state="closed", head=head))
        matches = [pr for pr in candidates if eligible(pr, name, branch["commit"]["sha"])]
        if not matches:
            continue
        # A branch reused by any open PR in either repository is retained.
        if any(list(pages("repos/" + repo + "/pulls", state="open", head=head))
               for repo in (UPSTREAM, FORK)):
            continue
        ref_path = "repos/" + FORK + "/git/ref/heads/" + quote(name, safe="")
        # Recheck the tip immediately before deletion to retain later work.
        try:
            current = api(ref_path)
        except HTTPError as error:
            if error.code == 404:
                continue
            raise
        if current["object"]["sha"] != branch["commit"]["sha"]:
            continue
        if not dry_run:
            api("repos/" + FORK + "/git/refs/heads/" + quote(name, safe=""), method="DELETE")
        results.append(("Would delete" if dry_run else "Deleted") + " branch " + name
                       + " after merged PR " + matches[0]["html_url"])
    text = "\n".join(results) or "No eligible merged branches to delete."
    print(text)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(text + "\n")


if __name__ == "__main__":
    main()
