#!/usr/bin/env python3
"""Fail closed when the public replication tree is not safe to release.

This script intentionally uses only the Python standard library.  Run it from
any directory; the repository root is derived from this file's location.

The path scanner examines every text file. A genuinely necessary literal
reference may be annotated on that same line with
``release-audit: allow-local-reference``.  This exception does not suppress
checks for credentials, sensitive file types, symlinks, or oversized files.
"""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
MAX_FILE_BYTES = 10 * 1024 * 1024
ALLOW_LOCAL_REFERENCE = "release-audit: allow-local-reference"

# Formats that can carry observations, identifiers, rendered results, or an
# opaque collection of files.  Comparisons are case-insensitive.
FORBIDDEN_SUFFIXES = {
    ".7z",
    ".arrow",
    ".bz2",
    ".csv",
    ".dat",
    ".db",
    ".dbf",
    ".dmg",
    ".doc",
    ".docx",
    ".dta",
    ".dtas",
    ".eps",
    ".feather",
    ".gif",
    ".geojson",
    ".gph",
    ".gpkg",
    ".gz",
    ".h5",
    ".hdf5",
    ".iso",
    ".jpeg",
    ".jpg",
    ".json",
    ".jsonl",
    ".key",
    ".kdbx",
    ".kml",
    ".kmz",
    ".log",
    ".mat",
    ".ndjson",
    ".ods",
    ".parquet",
    ".pdf",
    ".pem",
    ".pyc",
    ".png",
    ".por",
    ".ps",
    ".prj",
    ".p12",
    ".pfx",
    ".pkl",
    ".pickle",
    ".r3d",
    ".rar",
    ".rda",
    ".rdata",
    ".rds",
    ".sas7bcat",
    ".sas7bdat",
    ".sav",
    ".shp",
    ".shx",
    ".smcl",
    ".sqlite",
    ".sqlite3",
    ".tar",
    ".tex",
    ".tif",
    ".tiff",
    ".tsv",
    ".tgz",
    ".ster",
    ".svg",
    ".xls",
    ".xlsb",
    ".xlsx",
    ".xpt",
    ".xz",
    ".zip",
    ".zsav",
    ".zst",
}

FORBIDDEN_FILENAMES = {
    ".ds_store",
    ".netrc",
    ".renviron",
    ".rhistory",
    "thumbs.db",
}

FORBIDDEN_DIRECTORY_NAMES = {
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "__pycache__",
    ".gdb",
    "figures",
    "logs",
    "results",
    "temp",
    "tmp",
}

# Only these placeholders may be present below directories that receive data
# or generated products during a local replication run.
PLACEHOLDER_DIRECTORIES = {"data", "rawdata", "outputs"}
PLACEHOLDER_FILES = {"README.md"}

REQUIRED_FILES = {
    ".gitignore",
    "README.md",
    "NOTICE.md",
    "SECURITY.md",
    "DATA_AVAILABILITY.md",
    "THIRD_PARTY_NOTICES.md",
    "CITATION.cff",
    "LICENSES/renv-MIT.txt",
    "docs/CODE_AUDIT.md",
    "REPLICATION.md",
    "data/README.md",
    "rawdata/README.md",
    "outputs/README.md",
    "run_all.do",
    "ge_analysis.do",
    "ge_analysis_RFigures.R",
    "do/GE_global_setup.do",
    "do/global_runGPS.do",
}

LOCAL_REFERENCE_PATTERNS = (
    re.compile(r"(?<![A-Za-z0-9_])/(?:Users|home|Volumes)/[^\s\"']+", re.I),  # release-audit: allow-local-reference
    re.compile(r"\b[A-Za-z]:[\\/](?:Users|Documents|Dropbox)[\\/]", re.I),  # release-audit: allow-local-reference
    re.compile(r"\bTask_Cash\b", re.I),  # release-audit: allow-local-reference
    re.compile(r"\bDropbox(?:-[^/\\\s]+)?[\\/]", re.I),  # release-audit: allow-local-reference
)

RECORD_IDENTIFIER_PATTERNS = (
    (
        "UUID-like record identifier",
        re.compile(
            r"\b(?:uuid:)?[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-"
            r"[89ab][0-9a-f]{3}-[0-9a-f]{12}\b",
            re.I,
        ),
    ),
    (
        "household-like record identifier",
        re.compile(r"\b\d{12}-\d{3}\b"),
    ),
    (
        "phone-number-like literal",
        re.compile(r"(?<!\d)(?:\+?254|0)7\d{8}(?!\d)"),
    ),
)

# Dependency hashes in the machine-generated lockfile can contain digit runs
# that resemble phone numbers. The file remains subject to all other checks.
RECORD_SCAN_EXEMPT_PATHS = {"renv.lock"}

SECRET_PATTERNS = (
    ("private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("GitHub token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b")),
    ("OpenAI-style token", re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b")),
    ("AWS access key", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("Google API key", re.compile(r"\bAIza[A-Za-z0-9_-]{30,}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b")),
)

ASSIGNMENT_SECRET = re.compile(
    r"(?i)\b(?:api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|"
    r"password|passwd)\b\s*(?::|=)\s*[\"']?([^\s\"';,#]+)"
)
SAFE_SECRET_VALUES = {
    "changeme",
    "example",
    "none",
    "null",
    "placeholder",
    "redacted",
    "replace_me",
    "your_api_key",
    "your_token",
}


@dataclass(frozen=True)
class Finding:
    path: str
    message: str
    line: int | None = None

    def render(self) -> str:
        location = self.path if self.line is None else f"{self.path}:{self.line}"
        return f"  - {location}: {self.message}"


def repository_entries() -> tuple[list[Path], list[Finding]]:
    """Return all non-.git files and any symlink findings without following links."""
    files: list[Path] = []
    findings: list[Finding] = []

    for current_root, directory_names, file_names in os.walk(
        REPO_ROOT, topdown=True, followlinks=False
    ):
        root = Path(current_root)

        kept_directories: list[str] = []
        for name in sorted(directory_names):
            path = root / name
            relative = path.relative_to(REPO_ROOT).as_posix()
            if relative == ".git" or relative.startswith(".git/"):
                continue
            if path.is_symlink():
                findings.append(Finding(relative, "symbolic-link directory is not allowed"))
                continue
            kept_directories.append(name)
        directory_names[:] = kept_directories

        for name in sorted(file_names):
            path = root / name
            relative = path.relative_to(REPO_ROOT).as_posix()
            if path.is_symlink():
                findings.append(Finding(relative, "symbolic-link file is not allowed"))
                continue
            files.append(path)

    return sorted(files), findings


def is_probably_text(path: Path) -> bool:
    try:
        with path.open("rb") as handle:
            return b"\0" not in handle.read(8192)
    except OSError:
        return False


def text_lines(path: Path) -> Iterable[tuple[int, str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8", errors="replace")
    return enumerate(text.splitlines(), start=1)


def looks_like_safe_placeholder(value: str) -> bool:
    raw = value.strip().lower()
    normalized = raw.strip("<>{}[]()$%")
    return (
        normalized in SAFE_SECRET_VALUES
        or normalized.startswith("your_")
        or normalized.startswith("example_")
        or "placeholder" in normalized
        or "redacted" in normalized
        or raw.startswith(("$", "%", "os.getenv(", "os.environ", "process.env.", "secrets."))
    )


def inspect_file(path: Path) -> list[Finding]:
    findings: list[Finding] = []
    relative_path = path.relative_to(REPO_ROOT)
    relative = relative_path.as_posix()
    lower_name = path.name.lower()
    lower_suffix = path.suffix.lower()

    forbidden_environment_file = (
        lower_name == ".env"
        or lower_name.startswith(".env.") and lower_name != ".env.example"
    )
    if (
        lower_name in FORBIDDEN_FILENAMES
        or lower_suffix in FORBIDDEN_SUFFIXES
        or forbidden_environment_file
    ):
        findings.append(Finding(relative, "forbidden release file type"))

    if any(part.lower() in FORBIDDEN_DIRECTORY_NAMES for part in relative_path.parts[:-1]):
        findings.append(Finding(relative, "file is inside a generated-output directory"))

    if relative_path.parts and relative_path.parts[0].lower() in PLACEHOLDER_DIRECTORIES:
        if len(relative_path.parts) != 2 or path.name not in PLACEHOLDER_FILES:
            findings.append(
                Finding(relative, "only README.md is allowed in this placeholder directory")
            )

    try:
        size = path.stat().st_size
    except OSError as error:
        findings.append(Finding(relative, f"could not read file metadata: {error}"))
        return findings

    if size > MAX_FILE_BYTES:
        findings.append(
            Finding(relative, f"file is {size:,} bytes; limit is {MAX_FILE_BYTES:,} bytes")
        )

    if not is_probably_text(path):
        findings.append(Finding(relative, "binary content is not allowed in this code-only release"))
        return findings

    try:
        lines = text_lines(path)
        for line_number, line in lines:
            if ALLOW_LOCAL_REFERENCE not in line:
                for pattern in LOCAL_REFERENCE_PATTERNS:
                    if pattern.search(line):
                        findings.append(
                            Finding(relative, "machine-local or private workspace reference", line_number)
                        )
                        break

            if relative not in RECORD_SCAN_EXEMPT_PATHS:
                for label, pattern in RECORD_IDENTIFIER_PATTERNS:
                    if pattern.search(line):
                        findings.append(Finding(relative, f"possible {label}", line_number))

            for label, pattern in SECRET_PATTERNS:
                if pattern.search(line):
                    findings.append(Finding(relative, f"possible {label}", line_number))

            assignment_match = ASSIGNMENT_SECRET.search(line)
            if assignment_match and not looks_like_safe_placeholder(assignment_match.group(1)):
                findings.append(
                    Finding(relative, "possible credential assigned in plaintext", line_number)
                )
    except OSError as error:
        findings.append(Finding(relative, f"could not read file content: {error}"))

    return findings


def check_required_files() -> list[Finding]:
    findings: list[Finding] = []
    for relative in sorted(REQUIRED_FILES):
        if not (REPO_ROOT / relative).is_file():
            findings.append(Finding(relative, "required release file is missing"))
    return findings


def check_release_boundary(files: list[Path]) -> list[Finding]:
    findings: list[Finding] = []
    forbidden_paths = {"ge_construct.do"}
    forbidden_prefixes = ("ado/ssc/", "do/construct/", "Github_Cash/")
    for path in files:
        relative = path.relative_to(REPO_ROOT).as_posix()
        if relative in forbidden_paths or relative.startswith(forbidden_prefixes):
            findings.append(
                Finding(relative, "path is outside the approved public release boundary")
            )
    return findings


def check_public_gps_mode() -> list[Finding]:
    relative = "do/global_runGPS.do"
    path = REPO_ROOT / relative
    if not path.is_file():
        return []  # The missing-file check already reports this condition.
    try:
        content = path.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        return [Finding(relative, f"could not verify public GPS mode: {error}")]

    public_mode = re.compile(r"(?im)^\s*global\s+runGPS\s*(?:=\s*)?0(?:\s|$)")
    nonpublic_mode = re.compile(r"(?im)^\s*global\s+runGPS\s*(?:=\s*)?1(?:\s|$)")
    findings: list[Finding] = []
    if not public_mode.search(content):
        findings.append(Finding(relative, "must set global runGPS = 0 for the public package"))
    if nonpublic_mode.search(content):
        findings.append(Finding(relative, "must not enable restricted GPS analysis"))
    return findings


def main() -> int:
    files, findings = repository_entries()
    findings.extend(check_required_files())
    findings.extend(check_release_boundary(files))
    findings.extend(check_public_gps_mode())

    total_bytes = 0
    for path in files:
        try:
            total_bytes += path.stat().st_size
        except OSError:
            pass
        findings.extend(inspect_file(path))

    findings = sorted(set(findings), key=lambda item: (item.path, item.line or 0, item.message))
    if findings:
        print("RELEASE AUDIT FAILED", file=sys.stderr)
        print(
            f"Scanned {len(files)} files ({total_bytes:,} bytes) and found "
            f"{len(findings)} issue(s):",
            file=sys.stderr,
        )
        for finding in findings:
            print(finding.render(), file=sys.stderr)
        print(
            "Remove the flagged material or document a narrowly scoped local-path "
            "exception as described in this script's header.",
            file=sys.stderr,
        )
        return 1

    print(
        f"RELEASE AUDIT PASSED: {len(files)} files, {total_bytes:,} bytes; "
        "no data, archives, logs, local paths, record identifiers, credentials, symlinks, or oversized files detected."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
