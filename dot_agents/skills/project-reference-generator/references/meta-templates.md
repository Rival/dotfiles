# Meta Templates

Templates for index.md and the project-reference SKILL.md entry point.

## index.md Template

```markdown
# Index

Quick navigation: task -> file:section

## By Task

### {Category 1}

| Task | Read |
|------|------|
| {common task} | {domain}.md#{section} |

### {Category 2}

| Task | Read |
|------|------|
| {common task} | {domain}.md#{section} |

## By Domain

### {Group 1}

| Domain | File | Key Classes |
|--------|------|-------------|
| {name} | [{file}]({file}) | `{Class1}`, `{Class2}` |

### {Group 2}

| Domain | File | Key Classes |
|--------|------|-------------|
| {name} | [{file}]({file}) | `{Class1}`, `{Class2}` |

## Paths

| What | Path |
|------|------|
| {category} | `{path}` |
```

### Index Guidelines

- Group tasks by category (Services, UI, Data, Config, Testing, etc.)
- Every L3 domain must appear in "By Domain"
- Tasks should link to specific section anchors where possible
- Common tasks should be listed first within each category

## SKILL.md Template

```markdown
---
name: project-reference
description: Project-specific documentation and reference for {ProjectName}. Contains architecture, patterns, domain knowledge, and code conventions. Load this skill when working in this repository.
---

# Project Reference

Project-specific documentation for {ProjectName}. Organized by abstraction levels.

**Start here:** [index.md](references/index.md) — task -> file:section mapping

## Structure

| Level | File | Content |
|-------|------|---------|
| **Index** | [index.md](references/index.md) | Quick navigation by task |
| **L1** | [L1-architecture.md](references/L1-architecture.md) | Tech stack, modules |
| **L1+** | [code-architecture.md](references/code-architecture.md) | DI, services, patterns |
| **L2** | [L2-project-structure.md](references/L2-project-structure.md) | Folder structure |
| **L2** | [L2-code-patterns.md](references/L2-code-patterns.md) | Naming, conventions |
| **L3** | [L3-domains/](references/L3-domains/) | Domain details |
| **Cheatsheet** | [cheatsheet.md](references/cheatsheet.md) | Code snippets |
| **Glossary** | [glossary.md](references/glossary.md) | Terms |

## Domains

{Group domains by category}

### {Category}

| Domain | File | Key Classes |
|--------|------|-------------|
| {name} | [{file}](references/L3-domains/{file}) | `{Class}` |

## Quick Reference

| Task | Read |
|------|------|
| {common task} | `{code pattern}` — [{file}](references/{file}) |

## Paths

| What | Path |
|------|------|
| {category} | `{path}` |

## Documentation & Templates

| Resource | Purpose |
|----------|---------|
| [L3 Domain Template](docs/plans/l3-domain-reference-template.md) | Creating new domain docs |
| [L3 Domain Workflow](docs/plans/l3-domain-workflow.md) | Process for creating domains |
| [Sync Pipeline](docs/sync-quick.md) | Check/update docs |

### Creating New Documentation

**For L3 Domains:** Task tool + `l3-domain-workflow.md` (always use subagent!)

**Sync check:** `cd .claude/skills/project-reference && python scripts/sync_docs.py --status`
```

### SKILL.md Guidelines

- Keep compact — this is always loaded into context
- Use tables exclusively
- Group domains logically
- Include Quick Reference for most common operations
- Link to all reference files
