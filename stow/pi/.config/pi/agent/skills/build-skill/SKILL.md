---
name: build-skill
description: Creates new pi skills following Agent Skills best practices. Use when the user asks to create, build, or design a new skill. Provides structured workflow for skill creation — gather requirements, draft frontmatter, write SKILL.md, scaffold directory, and validate. Don't use for modifying existing skills.
---

# build-skill — Smart Skill Creator

Creates high-quality agent skills following the [Agent Skills spec](https://agentskills.io/specification) and established best practices. Guides through: gather requirements → draft → review with user → scaffold → validate.

## Building the Skill

### Step 1: Gather requirements

Ask the user:
- What specific task(s) should the skill handle?
- What tools/APIs/dependencies does it need?
- Where should it live (global: `~/.pi/agent/skills/<name>/` or project: `.pi/skills/<name>/`)?
- Any reference material to bundle (API docs, schemas, templates)?

If the user doesn't know, use defaults: global for general-purpose, project-local for project-specific.

### Step 2: Choose a name

Names must:
- 1-64 chars, lowercase letters, numbers, single hyphens only
- NOT start/end with hyphens, no consecutive hyphens
- Pi does NOT require the name to match the parent directory

Pick a name that's descriptive and uses consistent terminology.

### Step 3: Write the frontmatter description

The description is the ONLY field the agent sees before activating the skill. Make it count:

- First sentence: what the skill does (verbs: extracts, creates, processes, searches...)
- Second sentence: when to use it ("Use when user asks for X" or "Use when working with Y")
- Optional: negative triggers ("Don't use for Z")
- Max 1024 characters
- Write in third person

**Good:** "Extracts text and tables from PDF files, fills forms, merges documents. Use when working with PDFs or when user mentions forms or document extraction."

**Bad:** "Helps with PDFs."

### Step 4: Draft SKILL.md

Follow `assets/skill-template.md`. Key principles:

**Structure:**
- **Quick start** section: minimal working example agent sees immediately
- **Workflows** section: step-by-step processes with checklists for complex tasks
- **Setup** section: prerequisites, API keys, install commands
- **References** section: links to `references/` files, one level deep
- **When to use / When NOT to use**: explicit triggers and negative triggers

**Writing style (for LLMs, not humans):**
- Step-by-step numbered procedures (not paragraphs of prose)
- Third-person imperative: "Extract the text", not "You should extract"
- Concrete examples over abstract descriptions
- Consistent terminology: pick one term per concept, stick to it

**Sizing rules:**
- Aim for under 100 lines. Hard max: 500 lines.
- Offload detail to `references/`. Link from SKILL.md, one level deep.

**Prefer execution over instruction:**
- Bundle deterministic operations as scripts in `scripts/`
- Don't describe logic in prose — encode it in scripts and instruct the agent to run them

### Step 5: Decide what goes where

**Add scripts** when:
- The operation is deterministic (validation, formatting, parsing)
- The same code would be generated repeatedly
- Errors need explicit handling

Scripts save tokens and improve reliability vs generated code. Keep them tiny and single-purpose. No library code.

**Split into separate files** when:
- SKILL.md exceeds 100 lines
- Content covers distinct domains (e.g., finance vs sales schemas)
- Advanced features are rarely needed

**Do NOT create:**
- `README.md`, `CHANGELOG.md`, `INSTALLATION_GUIDE.md` — for humans, not agents
- Time-sensitive info (specific dates, version numbers that will age)

### Step 6: Review with user

After drafting, present the skill and ask:
- Does this cover your use cases?
- Anything missing or unclear?
- Should any section be more or less detailed?

Iterate based on feedback before finalizing.

### Step 7: Scaffold the directory

```
<name>/
├── SKILL.md
├── scripts/        (if needed)
├── references/     (if needed)
└── assets/         (if needed)
```

### Step 8: Validate

Verify:
- [ ] `name`: lowercase, hyphens only, 1-64 chars
- [ ] `description`: present, ≤1024 chars, includes what AND when
- [ ] SKILL.md under 100 lines (or justified if over)
- [ ] No time-sensitive info (dates, versions)
- [ ] Consistent terminology throughout
- [ ] Concrete examples included
- [ ] References one level deep
- [ ] No `---` inside frontmatter section

## Triage

- Need to find the best skill dir? Check `~/.pi/agent/skills/` and `.pi/skills/`.
- Skill too large? Split into `references/` files.
- Writing scripts? One file per purpose in `scripts/`. No library code.

## References

- [SKILL.md template](assets/skill-template.md) — fill-in-the-blanks skeleton to scaffold from