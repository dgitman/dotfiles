#!/usr/bin/env python3
"""Embed remote PHOTO images into VCF (vCard) files as Base64 data.

Scans the current working directory (or a directory passed as the first
argument) for .vcf files, downloads any PHOTO properties that reference an
http(s) URL, and rewrites them as inline Base64 using the encoding that
matches each card's VERSION.

A timestamped backup of the original file is created before it is replaced.
"""

import base64
import os
import re
import shutil
import sys
import tempfile
import urllib.request
from datetime import datetime
from mimetypes import guess_type

# Fold content lines so no line exceeds 75 octets (RFC 6350 section 3.2).
FOLD_WIDTH = 75
DEFAULT_VERSION = "3.0"
# Stop at characters that delimit vCard values; colons are kept so that
# URLs with an explicit port survive intact.
URL_RE = re.compile(r'(https?://[^\s;,"\']+)', re.IGNORECASE)

# Cache downloads so a URL shared by several cards is fetched only once.
_download_cache = {}


def normalize_image_type(mime_type, url):
    """Return (mime_type, vcard_subtype) e.g. ("image/jpeg", "JPEG")."""
    if not mime_type or "image" not in mime_type:
        mime_type = guess_type(url)[0] or "image/jpeg"
    mime_type = mime_type.split(";")[0].strip().lower()
    subtype = mime_type.split("/")[-1].upper()
    if subtype == "JPG":
        subtype = "JPEG"
        mime_type = "image/jpeg"
    return mime_type, subtype


def url_to_base64(url):
    """Download an image and return (base64_string, mime_type, subtype)."""
    if url in _download_cache:
        return _download_cache[url]

    try:
        print(f"  --> Downloading: {url}")
        # A basic User-Agent prevents some hosts from blocking the request.
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
            img_data = response.read()
            mime_type = response.headers.get_content_type()

        if not img_data:
            raise ValueError("empty response body")

        mime_type, subtype = normalize_image_type(mime_type, url)
        result = (base64.b64encode(img_data).decode("ascii"), mime_type, subtype)
    except Exception as e:  # noqa: BLE001 - network failures are expected
        print(f"  [!] Failed to download {url}: {e}")
        result = (None, None, None)

    _download_cache[url] = result
    return result


def fold_line(logical_line, eol):
    """Fold a logical line into physical lines of at most FOLD_WIDTH octets.

    Continuation lines begin with a single space, per RFC 6350.
    """
    out = [logical_line[:FOLD_WIDTH]]
    rest = logical_line[FOLD_WIDTH:]
    while rest:
        out.append(" " + rest[: FOLD_WIDTH - 1])
        rest = rest[FOLD_WIDTH - 1 :]
    return "".join(chunk + eol for chunk in out)


def build_photo_property(version, b64_string, mime_type, subtype, eol):
    """Render a PHOTO property using the encoding required by the vCard version."""
    if version.startswith("2.1"):
        # vCard 2.1: parameters are bare values, the payload sits on indented
        # continuation lines, and the block is terminated by a blank line.
        body = "".join(
            " " + b64_string[i : i + FOLD_WIDTH - 1] + eol
            for i in range(0, len(b64_string), FOLD_WIDTH - 1)
        )
        return f"PHOTO;{subtype};ENCODING=BASE64:{eol}{body}{eol}"

    if version.startswith("4.0"):
        # vCard 4.0: PHOTO holds a URI, so inline images use a data: URI.
        return fold_line(f"PHOTO:data:{mime_type};base64,{b64_string}", eol)

    # vCard 3.0: TYPE parameter plus ENCODING=b (RFC 2426).
    return fold_line(f"PHOTO;TYPE={subtype};ENCODING=b:{b64_string}", eol)


def iter_logical_lines(fh):
    """Yield (logical_line, raw_physical_lines) pairs, unfolding continuations."""
    logical = None
    raw = []
    for physical in fh:
        stripped = physical.rstrip("\r\n")
        if logical is not None and stripped[:1] in (" ", "\t"):
            logical += stripped[1:]
            raw.append(physical)
            continue
        if logical is not None:
            yield logical, raw
        logical = stripped
        raw = [physical]
    if logical is not None:
        yield logical, raw


def detect_eol(file_path):
    """Return the line terminator used by the file (vCard defaults to CRLF)."""
    with open(file_path, "r", encoding="utf-8", errors="ignore", newline="") as f:
        for line in f:
            if line.endswith("\r\n"):
                return "\r\n"
            if line.endswith("\n"):
                return "\n"
            if line.endswith("\r"):
                return "\r"
            break
    return "\r\n"


def backup_file(file_path):
    """Copy the original alongside itself with a timestamped .bak suffix."""
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_path = f"{file_path}.{stamp}.bak"
    counter = 1
    while os.path.exists(backup_path):
        backup_path = f"{file_path}.{stamp}-{counter}.bak"
        counter += 1
    shutil.copy2(file_path, backup_path)
    return backup_path


def process_vcf_file(file_path):
    """Rewrite PHOTO URL properties in a VCF file as inline Base64 data."""
    eol = detect_eol(file_path)
    directory = os.path.dirname(os.path.abspath(file_path))
    modified = False
    version = DEFAULT_VERSION

    # Write to a temp file first so the original is untouched unless we succeed.
    fd, temp_path = tempfile.mkstemp(dir=directory, suffix=".tmp")
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore", newline="") as src, \
                os.fdopen(fd, "w", encoding="utf-8", newline="") as dst:
            for logical, raw in iter_logical_lines(src):
                upper = logical.upper()

                if upper.startswith("BEGIN:VCARD"):
                    version = DEFAULT_VERSION
                elif upper.startswith("VERSION:"):
                    version = logical.split(":", 1)[1].strip() or DEFAULT_VERSION

                replacement = None
                if upper.startswith("PHOTO") and "HTTP" in upper:
                    match = URL_RE.search(logical)
                    if match:
                        b64_string, mime_type, subtype = url_to_base64(match.group(1))
                        if b64_string:
                            replacement = build_photo_property(
                                version, b64_string, mime_type, subtype, eol
                            )

                if replacement is not None:
                    modified = True
                    dst.write(replacement)
                else:
                    # Preserve untouched lines byte-for-byte, including any
                    # existing folding of embedded photos.
                    dst.writelines(raw)
    except BaseException:
        os.unlink(temp_path)
        raise

    if not modified:
        os.unlink(temp_path)
        print(f"[-] No image links changed in: {file_path}")
        return

    backup_path = backup_file(file_path)
    shutil.copymode(file_path, temp_path)
    os.replace(temp_path, file_path)
    print(f"[✓] Updated: {file_path}")
    print(f"    Backup:  {backup_path}")


def main():
    # Target the directory the command was run from, not the script's location.
    target_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.getcwd()

    if not os.path.isdir(target_dir):
        print(f"Not a directory: {target_dir}")
        return 1

    vcf_files = sorted(
        f for f in os.listdir(target_dir)
        if f.lower().endswith(".vcf") and os.path.isfile(os.path.join(target_dir, f))
    )

    if not vcf_files:
        print(f"No .vcf files found in {target_dir}.")
        return 0

    print(f"Found {len(vcf_files)} VCF file(s) in {target_dir}. Starting processing...")
    for vcf_file in vcf_files:
        print(f"\nProcessing {vcf_file}...")
        process_vcf_file(os.path.join(target_dir, vcf_file))
    print("\nAll done!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
