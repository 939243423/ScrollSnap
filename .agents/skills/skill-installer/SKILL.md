---
name: skill-installer
description: Install and inspect agent skills from local paths, Git repositories, or URL sources into the project (.agents/skills/) or global (~/.gemini/config/skills/) directories. Use when discovering available skills, inspecting installed skills, or installing new capabilities.
metadata:
  repository: https://github.com/anthropics/skills
---

# Skill Installer

Inspect, validate, and install Agent Skills into `.agents/skills/` or user global environments directly from remote Git repositories.

## Core Capabilities

1. **Inspection**: List all installed skills across workspace and global scopes (`python scripts/manage_skills.py list`).
2. **Remote Git Fetch**: Pull skill packages directly from GitHub (`python scripts/manage_skills.py fetch <repo-url> --skill <name>`).
3. **Spec Validation**: Validate that `SKILL.md` contains valid YAML frontmatter with `name` and `description`.
4. **Scope Control**: Target either workspace scope (`.agents/skills/`) or global scope (`~/.gemini/config/skills/`).

## Remote Fetch Examples

```bash
# Fetch frontend-design from Anthropic official repo
python .agents/skills/skill-installer/scripts/manage_skills.py fetch https://github.com/anthropics/skills --skill frontend-design --scope workspace --force

# Fetch stop-slop from upstream repository
python .agents/skills/skill-installer/scripts/manage_skills.py fetch https://github.com/anthropics/skills --skill stop-slop --scope workspace --force
```
