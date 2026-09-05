---
name: obsidian-note
description: Creates Markdown notes in the user's Obsidian vault at ~/TheVoid/notes and always marks them as AI-generated. Use when the user asks to write, create, capture, or save a note in Obsidian, or invokes /skill:obsidian-note.
---

# Obsidian Note

Create useful Markdown notes in `~/TheVoid/notes/`. Every note must contain the `ai-generated` tag in YAML frontmatter.

## Quick Start

For a request such as “Write an Obsidian note about eventual consistency”:

1. Draft the note in Markdown.
2. Choose `eventual-consistency.md` as the filename.
3. Write it to `~/TheVoid/notes/eventual-consistency.md` with the required frontmatter.
4. Report the resulting path.

## Required Note Format

Start every note with exactly this metadata unless additional YAML properties are needed:

```yaml
---
tags:
  - ai-generated
---
```

When adding metadata, preserve `ai-generated` in the `tags` list. Never omit or rename this tag.

After the frontmatter, add a blank line, a descriptive H1 title, and the note body. Use concise, structured Markdown by default. Preserve wording, structure, or metadata explicitly requested by the user.

## Workflow

1. Determine the topic and requested content from the user's message.
2. Ask a focused clarification only when essential information is missing; otherwise proceed.
3. Create a lowercase, hyphen-separated topic slug ending in `.md`, such as `distributed-systems.md`.
4. Reject filenames or paths that would place the note outside `~/TheVoid/notes/`.
5. Check whether the target file already exists.
6. If it exists, ask before replacing it. Offer a distinct filename when replacement is not intended.
7. Ensure `~/TheVoid/notes/` exists. Create that directory only if necessary.
8. Write the complete note with the required `ai-generated` YAML tag.
9. Read back or otherwise verify the saved file includes the tag and substantive body content.
10. Return the absolute note path and a one-line summary.

## Safety and Scope

- Write notes only beneath `~/TheVoid/notes/`.
- Do not overwrite an existing note without explicit confirmation.
- Do not modify unrelated vault files, Obsidian settings, attachments, or plugins.
- Do not claim the note was saved unless the write succeeded.

## When to Use

- When the user asks to write, save, capture, or create an Obsidian note.
- When the user asks to put knowledge or ideas into `~/TheVoid/notes/`.
- When the user invokes `/skill:obsidian-note` with a topic or note content.

## When Not to Use

- Do not use for ordinary project documentation unless the user wants it saved in the Obsidian vault.
- Do not use for editing an existing note unless the user explicitly requests that edit.
