#!/usr/bin/env python3
"""
Skill Manager Script
Lists, installs, fetches from Git, and removes Agent Skills.
Enables self-contained offline reproduction and remote network pulling.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def get_skill_paths():
    workspace_skills = Path.cwd() / ".agents" / "skills"
    global_skills = Path.home() / ".gemini" / "config" / "skills"
    return workspace_skills, global_skills


def parse_skill_meta(skill_dir: Path):
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return None
    try:
        content = skill_md.read_text(encoding="utf-8")
    except Exception:
        return None

    # Parse YAML frontmatter
    match = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return {"name": skill_dir.name, "description": "(No frontmatter found)"}

    yaml_block = match.group(1)
    name = skill_dir.name
    desc = ""

    for line in yaml_block.splitlines():
        line = line.strip()
        if line.startswith("name:"):
            name = line.split(":", 1)[1].strip()
        elif line.startswith("description:"):
            desc = line.split(":", 1)[1].strip()
            if desc.startswith(">-") or desc.startswith(">") or desc.startswith("|"):
                desc = ""

    if not desc:
        desc_match = re.search(r"description:\s*(?:[>|]-?\s*)?\n((?:\s{2,}.*\n?)+)", yaml_block)
        if desc_match:
            desc = " ".join(line.strip() for line in desc_match.group(1).splitlines())

    return {"name": name, "description": desc or "(No description)"}


def cmd_list(args):
    ws_dir, gb_dir = get_skill_paths()

    print("=== Agent Skills Inventory ===")
    print(f"\n[Workspace Skills: {ws_dir}]")
    if ws_dir.exists():
        ws_skills = [p for p in ws_dir.iterdir() if p.is_dir() and (p / "SKILL.md").exists()]
        if ws_skills:
            for s in sorted(ws_skills, key=lambda x: x.name):
                meta = parse_skill_meta(s)
                desc = meta["description"][:80] + ("..." if len(meta["description"]) > 80 else "")
                print(f"  - {s.name:<25} {desc}")
        else:
            print("  (No workspace skills installed)")
    else:
        print("  (Workspace .agents/skills directory does not exist)")

    print(f"\n[Global Skills: {gb_dir}]")
    if gb_dir.exists():
        gb_skills = [p for p in gb_dir.iterdir() if p.is_dir() and (p / "SKILL.md").exists()]
        if gb_skills:
            for s in sorted(gb_skills, key=lambda x: x.name):
                meta = parse_skill_meta(s)
                desc = meta["description"][:80] + ("..." if len(meta["description"]) > 80 else "")
                print(f"  - {s.name:<25} {desc}")
        else:
            print("  (No global skills installed)")
    else:
        print("  (Global skills directory does not exist)")


def validate_skill_dir(source_path: Path):
    skill_md = source_path / "SKILL.md"
    if not skill_md.is_file():
        raise ValueError(f"Target directory {source_path} does not contain SKILL.md")
    meta = parse_skill_meta(source_path)
    if not meta or not meta["name"]:
        raise ValueError("SKILL.md is missing a valid 'name' in frontmatter")
    return meta


def cmd_install(args):
    source = Path(args.source).resolve()
    if not source.exists() or not source.is_dir():
        print(f"Error: Source directory {source} does not exist.")
        sys.exit(1)

    meta = validate_skill_dir(source)
    skill_name = meta["name"]

    ws_dir, gb_dir = get_skill_paths()
    target_root = gb_dir if args.scope == "global" else ws_dir
    target_dir = target_root / skill_name

    if target_dir.exists():
        if not args.force:
            print(f"Error: Skill {skill_name} already exists at {target_dir}. Use --force to overwrite.")
            sys.exit(1)
        shutil.rmtree(target_dir)

    target_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target_dir)
    print(f"Successfully installed skill '{skill_name}' to {target_dir}")


def cmd_fetch(args):
    repo_url = args.repo
    skill_name = args.skill
    ws_dir, gb_dir = get_skill_paths()
    target_root = gb_dir if args.scope == "global" else ws_dir

    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"Cloning {repo_url} into temporary directory...")
        res = subprocess.run(["git", "clone", "--depth", "1", repo_url, temp_dir], capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Error cloning repository: {res.stderr}")
            sys.exit(1)

        temp_path = Path(temp_dir)
        candidates = [
            temp_path / skill_name,
            temp_path / "skills" / skill_name,
            temp_path / ".agents" / "skills" / skill_name,
        ]
        matched = None
        for c in candidates:
            if c.exists() and (c / "SKILL.md").exists():
                matched = c
                break

        if not matched:
            for root, dirs, files in os.walk(temp_dir):
                if Path(root).name == skill_name and "SKILL.md" in files:
                    matched = Path(root)
                    break

        if not matched:
            print(f"Error: Could not locate skill '{skill_name}' in repository.")
            sys.exit(1)

        target_dir = target_root / skill_name
        if target_dir.exists():
            if not args.force:
                print(f"Error: Destination {target_dir} exists. Use --force to overwrite.")
                sys.exit(1)
            shutil.rmtree(target_dir)

        target_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(matched, target_dir)
        print(f"Successfully fetched and installed skill '{skill_name}' to {target_dir}")


def cmd_remove(args):
    ws_dir, gb_dir = get_skill_paths()
    target_root = gb_dir if args.scope == "global" else ws_dir
    target_dir = target_root / args.name

    if not target_dir.exists():
        print(f"Skill '{args.name}' not found at {target_dir}")
        sys.exit(1)

    shutil.rmtree(target_dir)
    print(f"Removed skill '{args.name}' from {target_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Skill Manager")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # list
    subparsers.add_parser("list", help="List installed skills")

    # install
    p_inst = subparsers.add_parser("install", help="Install a skill from a local directory")
    p_inst.add_argument("source", help="Source directory")
    p_inst.add_argument("--scope", choices=["workspace", "global"], default="workspace")
    p_inst.add_argument("--force", action="store_true", help="Overwrite if exists")

    # fetch
    p_fetch = subparsers.add_parser("fetch", help="Fetch a skill from a remote Git repo")
    p_fetch.add_argument("repo", help="Git repository URL")
    p_fetch.add_argument("--skill", required=True, help="Name of skill folder")
    p_fetch.add_argument("--scope", choices=["workspace", "global"], default="workspace")
    p_fetch.add_argument("--force", action="store_true", help="Overwrite if exists")

    # remove
    p_rem = subparsers.add_parser("remove", help="Remove an installed skill")
    p_rem.add_argument("name", help="Skill name")
    p_rem.add_argument("--scope", choices=["workspace", "global"], default="workspace")

    args = parser.parse_args()
    if args.command == "list":
        cmd_list(args)
    elif args.command == "install":
        cmd_install(args)
    elif args.command == "fetch":
        cmd_fetch(args)
    elif args.command == "remove":
        cmd_remove(args)
