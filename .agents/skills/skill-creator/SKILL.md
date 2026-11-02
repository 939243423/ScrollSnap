---
name: skill-creator
description: Scaffold and create new agent skills conforming to the SKILL.md specification. Use when creating a new skill, generating skill templates, or adding scripts and references to an existing skill.
metadata:
  repository: https://github.com/anthropics/skills
---

# Skill Creator

Scaffold standard agent skill packages conforming to the `SKILL.md` specification within `.agents/skills/` or global configurations.

## Package Layout

```text
skills/<skill-name>/
├── SKILL.md          # Primary instruction file with YAML frontmatter
├── scripts/          # Executable helper utilities (Python, Node, Bash, Swift)
├── references/       # API mapping tables, technical specs, parameter reference
├── examples/         # Reference implementations
└── resources/        # Static templates and assets
```

## Scaffolding Workflow

1. **Scope and Directory**:
   - Workspace skill: `<workspace>/.agents/skills/<skill-name>/`
   - Global skill: `~/.gemini/config/skills/<skill-name>/`
   - Identifier: Lowercase letters, numbers, hyphens only (e.g., `image-stitching-engine`).

2. **YAML Frontmatter Structure**:
   ```markdown
   ---
   name: your-skill-name
   description: >-
     Explicit description of capability and exact trigger scenario in third person.
   ---
   ```

3. **Progressive Disclosure**:
   - Keep `SKILL.md` concise (< 100 lines) focusing on entry triggers and core execution steps.
   - Offload large data tables and references into `references/`.
   - Implement complex logic in `scripts/`.
