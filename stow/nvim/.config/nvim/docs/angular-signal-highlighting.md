# Angular Signal Highlighting for Neovim

> Goal: highlight Angular signals (`signal`, `computed`, `input`, `model`, …) with a
> distinct color in TypeScript files, external HTML templates, and inline templates —
> the way WebStorm does it. Neither VS Code nor Neovim can do this out of the box.

Status: **implemented and working — paused for dogfooding** (2026-02)

## 0. Current state — what exists, where

| File | What |
| --- | --- |
| `lua/core/signal-highlight.lua` | The whole feature (~640 lines): Layer 1 + Layer 2 + `:SignalHighlight` command. Loaded via `require("core.signal-highlight")` in `lua/core/init.lua`. |
| `lsp/angularls.lua` | **Critical fix, independent of signals**: `get_language_id` override. Neovim sends `languageId = "htmlangular"` for templates, but the Angular LS only understands `typescript`/`html` (enum `LanguageId` in `vscode-ng-language-service/server/src/session.ts`) and silently ignores everything else — that's why hover/gd/diagnostics never worked in templates before. |
| `lua/plugins/editor.lua` | `"angular"` added to treesitter `ensure_installed`. |
| `~/projects/AngularPlayground/src/app/signal-demo/` | Test fixture: `demo.component.ts` (all signal APIs, inline templates, false-positive traps), `demo.component.html`, `counter.store.ts` (cross-file signals via injected service). Typechecks against Angular 22. |

**Command:** `:SignalHighlight [on|off|toggle|refresh]` (default: toggle;
`refresh` drops the LSP hover cache and rescans all buffers).

**Highlight group:** `@angular.signal` — default `fg=#e5c07b italic` with
`default = true`, so a theme override wins:
`vim.api.nvim_set_hl(0, "@angular.signal", {...})`.

**Environment gotchas (will bite again):**
- Mason's `angular-language-server` must roughly match the project's Angular
  major version. It was v21 vs Angular 22 → server attached but answered
  *nothing* (no hover, no diagnostics, no errors either). Manually updated via
  `npm install @angular/language-server@22.1.0` inside
  `~/.local/share/nvim/mason/packages/angular-language-server/`. Mason updates
  may revert this; a per-project pinning story is an open TODO.
- angularls needs the `lsp/angularls.lua` languageId fix (see above), otherwise
  Layer 2 in templates is dead.
- Layer-2 highlights appear ~5–10 s after opening a project's first file
  (Angular compiler warm-up); Layer 1 is instant.

**Verified behavior (headless test runs against the playground):**
- `.ts`: all 18 declaration kinds highlighted (`signal`, `computed`,
  `linkedSignal`, `input`, `input.required`, `model`, `model.required`,
  `viewChild(.required)`, `viewChildren`, `contentChild(.required)`,
  `contentChildren`, `toSignal`, `resource`), `inject(...)` correctly ignored,
  `this.x` usages per-class scoped (same-name trap across classes passes),
  shadowed locals not highlighted. Scan ~0.5 ms.
- Inline templates: usages highlighted via angular injection; decorator sits
  *outside* the `class_declaration` node, so regions are associated with the
  nearest class starting after them.
- External templates: sibling `.ts` parsed from disk, rescans on its
  `BufWritePost`.
- Layer 2: `store.count()`/`store.doubled()` (injected service) and
  `data.value()` confirmed in both `.ts` (vtsls) and template (angularls);
  `data.hasValue()` (method), `message`, `plain` correctly rejected.
- `:SignalHighlight off` clears everything and silences autocmds; `on`
  restores.

**Known limitations / open ends:**
- Layer-2 re-verification happens on `LspAttach`, full rescans, and cache drop
  on `*.ts` save — but not continuously while typing (Layer 1 does re-run on
  `TextChanged`/`InsertLeave`, debounced 200 ms).
- Layer 2 verdicts rely on hover text shape (`(property) Foo.bar: Type`).
  angularls expands the `Signal` alias of `computed()` to `() => T`; that case
  falls back to `textDocument/definition` + declaration-line inspection
  (`definition_is_signal`). Other alias-expansion shapes may need the same
  treatment.
- Layer 1 does not remove false positives that Layer 2 disproves (Layer 2 only
  *adds* marks in its own namespace). Rarely matters in practice because Layer 1
  only claims same-class members.
- Not visually reviewed beyond one theme; only headless-validated.
- Untested on: NgRx signal stores, very large components, `host:` bindings,
  `@let` declarations, signal-typed function parameters.

**Next steps when resuming:**
1. Dogfood on a real project; fix what looks wrong.
2. Consider extracting to a standalone plugin repo (`plugin/` + `lua/`,
   `setup()` config: extra API names, extra type patterns, hl override).
   Nothing comparable exists publicly — worth publishing.
3. Optional endgame: upstream semantic tokens to `angular/angular` (re-land
   PR #2191 with the #2196 regression fixed + a signal token modifier). All
   groundwork is in §1–§2; sparse clone lives in `~/repos/angular`.

---

## 1. Research findings

### 1.1 Why WebStorm has it and nobody else does

- WebStorm does **not** use the Angular Language Server. It has a custom type engine
  (only Angular's TCB engine is reused for template type checking). Signal highlighting
  is a proprietary feature of that engine.
- Source: [JetBrains blog — "The Angular Language Server: Understanding IDE Integration
  Approaches"](https://blog.jetbrains.com/webstorm/2025/03/the-angular-language-server-understanding-ide-integration-approaches/)
  — explicitly lists *"Semantic highlighting of signals"* as a feature the Angular LSP
  does **not** provide.

### 1.2 State of the Angular Language Server

- The repo `angular/vscode-ng-language-service` was **archived (Nov 2025)**; code moved
  into the `angular/angular` monorepo:
  - Extension + LSP server: `vscode-ng-language-service/` (client, server, common)
  - Core analysis engine: `packages/language-service/`
  - Local sparse clone: `~/repos/angular`
- A semantic-token classification engine **exists** in
  `packages/language-service/src/semantic_tokens.ts` +
  `language_service.ts → getEncodedSemanticClassifications()`, **but it only classifies
  component tags** (`<app-foo>` → `class` token). All expression visitors
  (`visitBoundText`, `visitBoundAttribute`, …) are empty stubs. No signal awareness.
- **Semantic tokens were shipped and reverted upstream:**
  - [PR #2191](https://github.com/angular/vscode-ng-language-service/pull/2191)
    (v20.1.0, Jul 2025) added an LSP `semanticTokensProvider` to the server.
  - [Issue #2196](https://github.com/angular/vscode-ng-language-service/issues/2196):
    regression — VS Code allows only *one* semantic-token provider per document; the
    Angular server's sparse tokens displaced the built-in TS semantic highlighting.
  - [PR #2197](https://github.com/angular/vscode-ng-language-service/pull/2197)
    (v20.1.1) reverted the LSP part. The engine itself remains and is still used in the
    tsserver-plugin path (`ts_plugin.ts` correctly *merges* ng + ts classifications).
- Feature request for signal highlighting is open:
  [vscode-ng-language-service#2086](https://github.com/angular/vscode-ng-language-service/issues/2086).
- Note: the VS Code revert reason does **not** apply to Neovim — Neovim merges semantic
  tokens from all attached LSP clients.

### 1.3 Prior art (VS Code extensions — both are client-side workarounds)

**a) "Signal Highlighter" (`cactus.signal-highlighter`)** — TS-plugin + diagnostics hack
- A TypeScript language-service plugin wraps `getSemanticDiagnostics()`, walks the AST
  with the real TS type checker, and for every node whose type string starts with
  `Signal<` / `WritableSignal<` injects **fake suggestion diagnostics** (codes
  90000–90003).
- The extension converts those diagnostics into text decorations and hides the squiggles.
- Limitations: hack (own README documents leftover hint squiggles), TS files only,
  no template support.

**b) "Reactive Highlights" (`noahkohrs/reactive-highlights-vscode-extension`)** — hover polling
- Regex-scans the document for *every identifier*, calls the hover provider for each,
  checks the hover text for `Signal<` / `WritableSignal<` / `InputSignal<` /
  `ModelSignal<`, paints decorations.
- Per-version range cache with incremental dirty-region rescans on edits.
- Limitations: brute force (many hover requests), TS only, heuristic string match.

**Conclusion:** there is nothing reusable off the shelf. Everyone fakes it client-side
because the language servers don't emit signal information. But (b)'s approach —
"ask hover about identifiers, check the type" — translates directly to Neovim, and we
can do it much better because treesitter gives us *precise* candidates instead of
regex-matching every word.

### 1.4 Options considered

| Option | Verdict |
| --- | --- |
| Fork angular/angular, extend `semantic_tokens.ts` + re-land LSP provider | Best for the ecosystem (works in every editor), but: Bazel + pnpm monorepo build, must track Angular releases, upstream review is slow. Deferred — the research here is the groundwork if we ever do it. |
| tsserver plugin like (a) | Hack, TS only, no templates. Rejected. |
| **Neovim plugin: treesitter fast path + LSP hover verification** | **Chosen.** No server changes, no fork maintenance, covers TS + HTML + inline templates, can outdo both VS Code extensions. |

---

## 2. Design

### 2.1 Overview

Two cooperating layers, painting extmarks in a dedicated namespace with highlight group
**`@angular.signal`** (users theme it themselves; default links to something sensible,
e.g. `@property` + italic/underline so it's visible without theme support).

**Layer 1 — Treesitter fast path (synchronous, instant):**
1. In a component `.ts` buffer, query class members whose initializer is a call to a
   signal-creating API:
   `signal`, `computed`, `linkedSignal`, `input`, `input.required`, `model`,
   `model.required`, `viewChild`, `viewChild.required`, `viewChildren`, `contentChild`,
   `contentChild.required`, `contentChildren`, `toSignal`, `resource`, `rxResource`,
   `httpResource`.
2. Collect the member names → the buffer's *signal set*.
3. Highlight the declarations and every usage (`this.x`, bare `x` in templates) of
   names in the signal set:
   - in the `.ts` buffer (treesitter query for `property_identifier` / `identifier`),
   - in the **inline template** (`template:` string in `@Component`) via the angular
     treesitter parser injection,
   - in the **sibling `.html` buffer** (reuse base-name logic from
     `lua/core/angular.lua`; when the html buffer is opened, parse its sibling `.ts`).
- Known miss: signals living on other files (injected services, stores). Known false
  positive: same-named non-signal locals. Both fixed by Layer 2.

**Layer 2 — LSP verification (async, debounced):**
1. Treesitter collects *candidate* identifiers (property accesses, call targets — not
   every word).
2. For candidates not already resolved by Layer 1, issue `textDocument/hover`
   requests — against **vtsls** in `.ts` buffers, against **angularls** in templates
   (angularls answers hover inside templates with type info).
3. An identifier is a signal iff the hover type matches:
   `Signal<`, `WritableSignal<`, `InputSignal<`, `InputSignalWithTransform<`,
   `ModelSignal<`, `ResourceRef<`, `Resource<`, `HttpResourceRef<`
   (word-boundary matches on the *type* portion, not doc text; exclude
   function/method signatures like (a) and (b) both learned to).
4. Cache results per buffer `changedtick` + per symbol name; debounce on
   `TextChanged`/`InsertLeave`; cancel in-flight requests on new edits (b's approach,
   simplified by Neovim's `changedtick`).

### 2.2 Placement

- Lives in the nvim config first: `lua/core/signal-highlight.lua` (wired from
  `lua/core/init.lua`). If it works well → extract into a standalone plugin repo
  (nothing like it exists yet).

### 2.3 Non-goals (for now)

- Forking / patching the Angular language server (documented above as future option).
- Non-Angular reactivity (Vue refs etc.) — the architecture allows a strategy layer
  later, like (b) does.

---

## 3. Implementation plan (historical — all steps done)

Steps 0–4 implemented as planned; step 5 partially (command yes, extraction and
theme wiring pending). Deviations from plan are folded into §0 above. Notable:
Layer 2 got a definition-check fallback that wasn't planned, and "cancel
in-flight requests" became "ignore stale results via changedtick check".

### Step 0 — Test fixture
- Create a tiny Angular sample (or use an existing real project) containing:
  every signal API listed in 2.1, a signal-returning service injected into a component,
  an external template, an inline template, a non-signal property with the same name as
  a signal in another class (false-positive trap), `model.required()`, and a plain
  non-component `.ts` file (must remain untouched).
- **Validate:** `:checkhealth vim.treesitter`, `:InspectTree` on the fixture shows
  `typescript` + `angular` parsers working; angularls + vtsls attach (`:LspInfo`).
  Install the `angular` treesitter parser if missing (currently not in
  `ensure_installed` in `lua/plugins/editor.lua`).

### Step 1 — Declarations in `.ts` (Layer 1 core)
- New module `lua/core/signal-highlight.lua`: namespace, `@angular.signal` group,
  treesitter query for signal-creating initializers, extmarks on declaration names.
  Autocmds: `FileType typescript` + `TextChanged`/`InsertLeave` (debounced re-scan).
- **Validate:** open fixture component — all declaration identifiers colored; edit
  (rename a member, change `signal()` to a plain value) — highlight follows;
  no highlights in the plain `.ts` file; `:Inspect` on a highlighted identifier shows
  the extmark. Measure with `--startuptime` / `vim.uv.hrtime` that scan is < a few ms.

### Step 2 — Usages in the same `.ts` buffer
- Second query pass: highlight `this.<name>` property accesses and bare `<name>`
  references matching the signal set (scope-aware enough to skip shadowed locals —
  keep it simple: only `this.x` and identifiers inside the inline template).
- **Validate:** `this.count()`, `this.count.set(1)` colored at `count`; a local
  variable `count` in a method is *not* colored; false-positive trap file clean.

### Step 3 — Templates (inline + external HTML)
- Inline: run the usage query inside the injected `angular` tree of the `template:`
  string.
- External: on `FileType htmlangular`/`html`, locate sibling `.ts` (reuse
  `core/angular.lua` base-name logic), parse it (headless `vim.treesitter` on the file
  content — buffer need not be open), compute the signal set, run the usage query on
  the html buffer. Re-scan when the sibling `.ts` is written (`BufWritePost` hook).
- **Validate:** `{{ count() }}`, `[prop]="count()"`, `@if (user(); as u)` colored in
  both template kinds; editing the `.ts` (add/remove a signal) updates the open html
  buffer after save; non-Angular html files unaffected.

### Step 4 — LSP hover verification (Layer 2)
- Candidate collector (treesitter) + async hover pipeline with per-name cache,
  `changedtick` invalidation, debounce, request cancellation.
- `.ts` buffers → vtsls; template buffers → angularls.
- Confirms cross-file signals (`this.store.count`) and *removes* Layer-1 false
  positives when hover proves a candidate is not a signal.
- **Validate:** injected-service signal usage gets highlighted within ~1s of opening;
  rapid typing causes no error notifications and no request pile-up
  (`:lua vim.print(vim.lsp.get_clients())` sanity, `nvim --startuptime`, watch
  `:messages`); results stable after `:e!`.

### Step 5 — Polish & extraction (partially done)
- Done: `:SignalHighlight on|off|toggle|refresh` command with completion.
- Pending: config surface (extra API names / type patterns / hl override),
  theme note in `lua/plugins/ui/theme.lua`, plugin extraction decision,
  dogfooding on a real project.

---

## 4. Reference links

- JetBrains blog on LS integration approaches: <https://blog.jetbrains.com/webstorm/2025/03/the-angular-language-server-understanding-ide-integration-approaches/>
- Feature request (open): <https://github.com/angular/vscode-ng-language-service/issues/2086>
- Semantic tokens PR (merged, then reverted): <https://github.com/angular/vscode-ng-language-service/pull/2191>
- Regression issue: <https://github.com/angular/vscode-ng-language-service/issues/2196>
- Revert PR: <https://github.com/angular/vscode-ng-language-service/pull/2197>
- Engine (still alive): `angular/angular` → `packages/language-service/src/semantic_tokens.ts`
- Signal-type unwrapping precedent: `packages/language-service/src/inlay_hints.ts`
- VS Code prior art: `cactus.signal-highlighter` (marketplace), <https://github.com/noahkohrs/reactive-highlights-vscode-extension>
- Local sparse clone of angular/angular: `~/repos/angular`
