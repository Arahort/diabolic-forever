#!/usr/bin/env python3
"""Build the tracked Forever addon snapshot. Author: Arahort <alex@arahort.pro>."""
import argparse
import hashlib
import posixpath
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path, PurePosixPath
RUNTIME_DIRS = {"Assets", "Components", "Core", "Libs", "Locale"}
ROOT_FILES = {"DiabolicUI3.toc", "Bindings.xml", "TaintLess.xml", "README.md", "CHANGELOG.md", "TESTING.md", "DiabolicUI_logo.png", "LICENSE", "LICENSE.txt", "LICENSE.md"}
PRIVATE_PARTS = {"scripts", "tests", "test", "results", "backups", "research_notes", "node_modules", "__pycache__", "ai"}
SOURCE_SUFFIXES = {".psd", ".kra", ".xcf", ".blend", ".tmp", ".bak", ".log", ".sqlite", ".db", ".py", ".pyc", ".zip", ".rar", ".7z", ".jsonl"}
def git(root, *args):
    return subprocess.check_output(["git", *args], cwd=root)
def safe_path(path):
    if not path or "\\" in path or "\x00" in path or re.match(r"^[A-Za-z]:", path) or path.startswith("/"):
        raise ValueError(f"Unsafe addon path: {path!r}")
    normalized = posixpath.normpath(path)
    if normalized in {".", ".."} or normalized.startswith("../"):
        raise ValueError(f"Addon path escapes its root: {path!r}")
    return normalized
def package_path(path):
    canonical = safe_path(path)
    if canonical != path:
        raise ValueError(f"Non-canonical archive path: {path!r}")
    path = canonical
    parts = PurePosixPath(path).parts
    if path not in ROOT_FILES and parts[0] not in RUNTIME_DIRS:
        return False
    if any(p.startswith(".") or p.casefold() in PRIVATE_PARTS for p in parts):
        return False
    if path.startswith("Components/Misc/Disabled/"):
        return False
    if PurePosixPath(path).suffix.casefold() in SOURCE_SUFFIXES or path.endswith("~"):
        return False
    return True
def read_snapshot(root, ref="HEAD", index=False):
    entries = []
    if index:
        for record in git(root, "ls-files", "--stage", "-z").split(b"\0"):
            if not record:
                continue
            metadata, path = record.split(b"\t", 1)
            mode, oid, stage = metadata.decode("ascii").split()
            if stage != "0":
                raise ValueError("Cannot package an index with unresolved conflicts")
            entries.append((path.decode("utf-8"), mode, oid))
    else:
        for record in git(root, "ls-tree", "-r", "-z", "--full-tree", ref).split(b"\0"):
            if not record:
                continue
            metadata, path = record.split(b"\t", 1)
            mode, kind, oid = metadata.decode("ascii").split()
            if kind != "blob":
                continue
            entries.append((path.decode("utf-8"), mode, oid))
    selected = [(p, oid) for p, mode, oid in entries if package_path(p) and mode in {"100644", "100755"}]
    oids = sorted({oid for _, oid in selected})
    raw = subprocess.run(["git", "cat-file", "--batch"], cwd=root, input=("\n".join(oids) + "\n").encode("ascii"), stdout=subprocess.PIPE, check=True).stdout
    blobs, offset = {}, 0
    for oid in oids:
        end = raw.index(b"\n", offset)
        header = raw[offset:end].split()
        if len(header) != 3 or header[0].decode() != oid or header[1] != b"blob":
            raise ValueError("Invalid git snapshot object")
        size = int(header[2])
        blobs[oid] = raw[end + 1:end + 1 + size]
        offset = end + 2 + size
    return {p: blobs[oid] for p, oid in selected}
def text(snapshot, path):
    return snapshot[path].decode("utf-8-sig")
def release_notes(snapshot, tag):
    changelog = text(snapshot, "CHANGELOG.md")
    headings = list(re.finditer(r"^## +\[([^]\r\n]+)\].*$", changelog, re.MULTILINE))
    if not headings or headings[0].group(1) != tag:
        raise ValueError("First CHANGELOG section must match the release tag")
    notes = changelog[headings[0].start():headings[1].start() if len(headings) > 1 else len(changelog)].strip()
    if notes.endswith("---"):
        notes = notes[:-3].rstrip()
    return notes + "\n"
def validate_snapshot(snapshot, tag):
    if not re.fullmatch(r"6\.6\.6-r[1-9][0-9]*", tag):
        raise ValueError("Expected tag 6.6.6-rN with a positive build number")
    for required in {"DiabolicUI3.toc", "Bindings.xml", "README.md", "CHANGELOG.md"}:
        if required not in snapshot:
            raise ValueError(f"Required release file is missing: {required}")
    toc = text(snapshot, "DiabolicUI3.toc")
    interfaces = re.findall(r"^##\s*Interface(?:-[^:]*)?\s*:\s*(.*?)\s*$", toc, re.MULTILINE | re.IGNORECASE)
    if interfaces != ["16001"]:
        raise ValueError("Release TOC must declare only Interface: 16001")
    versions = re.findall(r"^##\s*Version\s*:\s*(.*?)\s*$", toc, re.MULTILINE | re.IGNORECASE)
    if versions != [tag]:
        raise ValueError(f"TOC Version must match tag {tag}")
    lookup = {}
    for path in snapshot:
        if not package_path(path):
            raise ValueError(f"Unexpected release path: {path}")
        key = path.casefold()
        if key in lookup:
            raise ValueError(f"Case-insensitive duplicate path: {path}")
        lookup[key] = path
    visited = set()
    def visit(path):
        path = safe_path(path.replace("\\", "/"))
        actual = lookup.get(path.casefold())
        if actual is None:
            raise ValueError(f"Loaded runtime file is missing from archive: {path}")
        if actual in visited:
            return
        visited.add(actual)
        if actual.lower().endswith(".xml"):
            root = ET.fromstring(snapshot[actual])
            for element in root.iter():
                if element.tag.split("}")[-1] in {"Script", "Include"} and "file" in element.attrib:
                    reference = element.attrib["file"].replace("\\", "/")
                    if reference.startswith("/") or re.match(r"^[A-Za-z]:", reference):
                        raise ValueError(f"Absolute runtime reference in {actual}: {reference}")
                    visit(posixpath.join(posixpath.dirname(actual), reference))
    for line in toc.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            visit(line)
    visit("Bindings.xml")
    return release_notes(snapshot, tag), len(visited)
def build(snapshot, tag, output):
    notes, loaded = validate_snapshot(snapshot, tag)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / "DiabolicUI3-Forever.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(snapshot):
            info = zipfile.ZipInfo("DiabolicUI3/" + path, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(info, snapshot[path], compresslevel=9)
    (output / "release-notes.md").write_text(notes, encoding="utf-8", newline="\n")
    print(f"Built {archive.name}: {len(snapshot)} tracked files; {loaded} loaded references; SHA256 {hashlib.sha256(archive.read_bytes()).hexdigest()}")
    return archive
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--ref", default="HEAD", help="Immutable git commit/tag to package")
    parser.add_argument("--index", action="store_true", help="Review the staged snapshot before its first commit")
    parser.add_argument("--output", type=Path, default=Path("dist"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    build(read_snapshot(root, args.ref, args.index), args.tag, args.output)
if __name__ == "__main__":
    try:
        main()
    except (ValueError, ET.ParseError, subprocess.CalledProcessError) as exc:
        print(f"Release validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
