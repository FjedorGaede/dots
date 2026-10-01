---
name: research-project-setup
description: Scaffolds a new research project by gathering only missing details, checking for collisions, and creating a research folder structure plus a tailored domain-specific skill. Use when the user asks to start, set up, or scaffold a research project on any topic.
---

# Research Project Setup

Set up a new research project. Follow this sequence.

## 1. Gather only missing information

Before creating anything, determine:

1. **Topic/goal** — what the research project is about.
2. **Target directory** — where it should live. Never guess a path.
3. **Subtopics** — areas to cover. If unknown, propose a topic-appropriate starter list and get confirmation or edits.
4. **Staleness-sensitive categories** — facts that may change quickly, such as rates, laws, prices, or software versions. Infer likely categories for decision, finance, legal, or technical topics and ask for a quick confirmation. Skip this entirely for clearly non-time-sensitive topics, such as historical research, literature reviews, or hobby exploration.

Extract answers from the user's request before asking questions. Do not re-ask stated details. A sufficiently detailed request may require no follow-up.

Infer the log shape without asking unless genuinely ambiguous:

- **Decision log**: use when the request is decision-shaped, such as choosing a tool, purchase, or financing option.
- **Conclusion log**: otherwise, use a lighter running record of conclusions for open-ended exploration.

## 2. Check collisions before writing

1. Inspect the target directory.
2. If it exists and has files—especially `AGENTS.md`, `decisions.md`, or `.pi/skills/`—stop. Explain what exists and ask whether to merge, choose another directory, or explicitly overwrite.
3. Never silently overwrite `decisions.md` or `open-questions.md`.
4. Search global and relevant project `.pi/skills/` locations for a matching topic slug. If one exists, flag it and propose a more-specific slug. Do not silently shadow it.
5. Do not create anything until collision handling is clear.

## 3. Create the project

Derive a short kebab-case `<topic-slug>` from the topic, such as `haus-finanzierung` or `db-selection`. Create:

```text
<project-dir>/
├── AGENTS.md
├── .pi/
│   └── skills/
│       └── <topic-slug>/
│           └── SKILL.md
├── sources/
├── notes/
├── decisions.md
└── open-questions.md
```

### `AGENTS.md`

Include:

- The project's goal in the user's own words.
- Folder conventions:
  - `sources/`: raw collected material only; never edit it after saving. Use dated filenames, for example `topic-2026-08-24.md`.
  - `notes/`: synthesized findings; one file per subtopic. Split a file when it covers more than one clear question. Consider merging files when repeated cross-references make either hard to read independently.
  - `decisions.md`: the running decision or conclusion log, matching the selected shape.
  - `open-questions.md`: unresolved items.
- Instruction to read `decisions.md` and `open-questions.md` before any new research and update both at the end of each session.
- Source accumulation guidance: when several dated snapshots cover the same fact, flag this and offer to consolidate older snapshots into a short dated summary, retaining only the most recent one or two in full.
- Lifecycle guidance: this project is registered for global discovery. Its status is `active` at creation; use `/project paused`, `/project done`, or `/project archived` as appropriate. Archived projects stay retained but are hidden from the default picker.

### `.pi/skills/<topic-slug>/SKILL.md`

Write a concrete domain-specific research skill with a discoverable `description:` frontmatter field. Include:

- The actual topic, goal, and confirmed subtopics.
- If applicable, explicit staleness categories and a rule to check and record a fact's date/currency before citing it.
- Raw material belongs in `sources/`; synthesis must never be written there.
- Every claim in `notes/` identifies its originating `sources/` file.
- Every note separates **fact from source** from **interpretation/recommendation**.
- End-of-session updates to `decisions.md` and `open-questions.md`.
- Brief split/merge guidance for subtopic notes.
- Brief source-consolidation guidance.
- Lifecycle guidance: the project is registered as `active`; when its goal is met, use `/project done`, and use `/project archived` when it should be retained but removed from normal discovery.

Avoid generic boilerplate: tailor the rules to this topic.

### `decisions.md`

For a decision log, create a header and one example section:

```markdown
## <Question>
- Found:
- Going with:
- Would change our mind if:
```

For a conclusion log, create a header and one example section:

```markdown
## <Topic/date>
- Findings:
- Current understanding:
```

### `open-questions.md`

Create a header and one starter question based on the overall goal. Leave `notes/` and `sources/` empty.

### Register the project

After all files have been created successfully, call the global `register_research_project` tool with the absolute project path, a concise display name, `<topic-slug>`, the user's goal, and status `active`. Do this only after creation succeeds; the registry must never point at a partially-created project.

## 4. Confirm completion

1. Show the resulting directory tree.
2. Confirm that the domain skill is discoverable as `/skill:<topic-slug>` (or list it).
3. Confirm it is registered as `active` and discoverable anywhere through `/project` or requests such as “work on my <project name> project.” Mention `/project paused`, `/project done`, and `/project archived` for lifecycle updates.
4. Suggest a natural first research prompt that explicitly references `/skill:<topic-slug>`.

## Guardrails

- Do not force questions already answered or irrelevant to the topic.
- Check collisions before destructive writes.
- Never silently overwrite historical logs.
