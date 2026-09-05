#!/usr/bin/env python3

import argparse
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

# The code is not pure ElementTree, as doing would not guarantee reordering of elements.
# Therefore the regular expression approach in various places, making the code, unfortuntely,
# less clean.


TAG_BOUNDARY_CHARS = (" ", "\t", "\n", "\r", ">", "/")


def locally_changed_gpml_files(repo_dir):
    result = subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=all", "--", "pathways"],
        cwd=repo_dir,
        check=True,
        capture_output=True,
        text=True,
    )

    files = []
    for line in result.stdout.splitlines():
        path_text = line[3:]
        if " -> " in path_text:
            path_text = path_text.split(" -> ", 1)[1]
        path = repo_dir / path_text
        if path.suffix == ".gpml" and path.is_file():
            files.append(path)
    return files


def find_pathway_tag_span(content, path):
    start = content.find("<Pathway")
    while start != -1:
        after_name = start + len("<Pathway")
        if after_name < len(content) and content[after_name] in TAG_BOUNDARY_CHARS:
            break
        start = content.find("<Pathway", start + 1)
    if start == -1:
        raise ValueError(f"No root Pathway element found in {path}")

    end = content.find(">", start)
    if end == -1:
        raise ValueError(f"No root Pathway element found in {path}")
    return start, end + 1


def parse_author_list(value, path):
    if not (value.startswith("[") and value.endswith("]")):
        raise ValueError(f"Unexpected Author value in {path}: {value}")
    inner = value[1:-1].strip()
    if not inner:
        return []
    return [name.strip() for name in inner.split(",")]


def add_missing_editors(pathway_element, editors, path):
    author_value = pathway_element.get("Author")
    if author_value is None:
        raise ValueError(f"No Author attribute found in {path}")

    names = parse_author_list(author_value, path)
    changed = False
    for editor in editors:
        if editor not in names:
            names.append(editor)
            changed = True

    if changed:
        pathway_element.set("Author", "[" + ", ".join(names) + "]")
    return changed


def update_pathway_attributes(path, editors=None):
    content = path.read_bytes().decode("utf-8")
    start, end = find_pathway_tag_span(content, path)
    pathway_tag = content[start:end]

    try:
        pathway_element = ET.fromstring(pathway_tag + "</Pathway>")
    except ET.ParseError as e:
        raise ValueError(f"Could not parse root Pathway element in {path}: {e}")

    if pathway_element.tag.startswith("{"):
        ET.register_namespace("", pathway_element.tag[1:pathway_element.tag.index("}")])

    old_version = pathway_element.get("Version")
    if old_version is None:
        raise ValueError(f"No Version attribute found in {path}")
    prefix, sep, old_timestamp = old_version.partition("_r")
    if not sep or not prefix.startswith("WP") or not prefix[2:].isdigit() or not old_timestamp.isdigit():
        raise ValueError(f"Unexpected Version value in {path}: {old_version}")

    if pathway_element.get("Last-Modified") is None:
        raise ValueError(f"No Last-Modified attribute found in {path}")

    editors_changed = False
    if editors:
        editors_changed = add_missing_editors(pathway_element, editors, path)

    timestamp = datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y%m%d%H%M%S")
    version = f"{prefix}{sep}{timestamp}"
    if old_version == version and pathway_element.get("Last-Modified") == timestamp and not editors_changed:
        return

    pathway_element.set("Version", version)
    pathway_element.set("Last-Modified", timestamp)

    updated_tag = ET.tostring(pathway_element, encoding="unicode")
    assert updated_tag.endswith(" />")
    updated_tag = updated_tag[:-len(" />")] + ">"

    updated_content = content[:start] + updated_tag + content[end:]
    path.write_bytes(updated_content.encode("utf-8"))
    print(f"updated {path}: {version}, Last-Modified={timestamp}")


def main():
    parser = argparse.ArgumentParser(
        description="Update timestamps in locally changed GPML pathway files."
    )
    parser.add_argument(
        "--editor",
        nargs="+",
        metavar="NAME",
        help="editor name(s) to add to the Author attribute if not already present",
    )
    args = parser.parse_args()
    repo_dir = Path.cwd()

    for path in locally_changed_gpml_files(repo_dir):
        update_pathway_attributes(path, editors=args.editor)


if __name__ == "__main__":
    main()
