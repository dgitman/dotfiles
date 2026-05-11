#!/usr/bin/env python3
import ipaddress
import os
import re
import shlex
import subprocess
import sys
import urllib.error
import urllib.request


IPTABLES = "/sbin/iptables"
CHAIN = "PINGDOM"
PORT = 3306
FEED_URL = "https://my.pingdom.com/probes/feed"


def _usage() -> str:
    return (
        "Usage:\n"
        "  update-pingdom-iptables.py [-n]\n\n"
        "Options:\n"
        "  -n   Dry-run (print iptables commands; make no changes)\n"
    )


def _fetch_feed(url: str) -> str:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "update-pingdom-iptables.py",
            "Accept": "*/*",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            return resp.read().decode(charset, errors="replace")
    except (urllib.error.URLError, TimeoutError) as e:
        raise RuntimeError(f"Failed to fetch Pingdom feed from {url}: {e}") from e


def _extract_ipv4_ips(feed: str) -> list[str]:
    # Be tolerant: the feed contains <pingdom:ip> entries, but treat it as text
    # (namespace handling varies, and we want a simple/robust extraction).
    candidates = re.findall(r"<pingdom:ip>\s*([^<\s]+)\s*</pingdom:ip>", feed)
    ips: list[str] = []
    for candidate in candidates:
        candidate = candidate.strip()
        try:
            ip = ipaddress.ip_address(candidate)
        except ValueError:
            continue
        if ip.version == 4:
            ips.append(str(ip))
    # Preserve order while de-duping.
    return list(dict.fromkeys(ips))


def _run(cmd: list[str], *, dry_run: bool) -> int:
    if dry_run:
        print(shlex.join(cmd))
        return 0
    completed = subprocess.run(cmd, check=False)
    return completed.returncode


def main(argv: list[str]) -> int:
    dry_run = False
    args = argv[1:]
    if len(args) > 1 or (args and args[0] not in {"-n", "-h", "--help"}):
        print(_usage(), file=sys.stderr)
        return 2
    if args and args[0] in {"-h", "--help"}:
        print(_usage())
        return 0
    if args and args[0] == "-n":
        dry_run = True

    feed = _fetch_feed(FEED_URL)
    ips = _extract_ipv4_ips(feed)
    if not ips:
        print("No Pingdom probe IPs found; leaving firewall unchanged.", file=sys.stderr)
        return 1

    rc = _run([IPTABLES, "-F", CHAIN], dry_run=dry_run)
    if rc != 0:
        return rc

    for ip in ips:
        rc = _run(
            [
                IPTABLES,
                "-A",
                CHAIN,
                "-p",
                "tcp",
                "--dport",
                str(PORT),
                "-j",
                "ACCEPT",
                "-s",
                ip,
            ],
            dry_run=dry_run,
        )
        if rc != 0:
            return rc

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

