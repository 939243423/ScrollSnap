---
name: skill-installer
description: Install and inspect agent skills from local paths, Git repositories, or URL sources into the project (.agents/skills/) or global (~/.gemini/config/skills/) directories. Use when discovering available skills, inspecting installed skills, or installing new capabilities.
---

# Skill Installer

Inspect, validate, and install Agent Skills into `.agents/skills/` or user global environments.

## Core Capabilities

1. **Inspection**: List all installed skills across workspace and global scopes.
2. **Repository Fetch**: Pull skill packages from remote Git repositories.
3. **Spec Validation**: Validate that `SKILL.md` contains valid YAML frontmatter with `name` and `description`.
4. **Scope Control**: Target either workspace scope (`.agents/skills/`) or global scope (`~/.gemini/config/skills/`).

## Validation Protocol

- Target directory must contain a readable `SKILL.md` file.
- YAML frontmatter must parse with non-empty `name` and `description` strings.
- Skill directory name must match `name` attribute in frontmatter.
