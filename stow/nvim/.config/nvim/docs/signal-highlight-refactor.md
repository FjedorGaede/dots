# Signal highlight refactor — TODO

> Derived from code review of `lua/core/signal-highlight.lua` (699 lines, single file).
> Goal: keep the two-layer architecture (treesitter sync + LSP async), drop the
> accidental complexity, make the file(s) navigable, fix the real bugs.
> See `docs/angular-signal-highlighting.md` for the feature spec.

## Plan

Ordered for incremental, low-risk progress. Each step should leave the feature
working as before. Tick the box, write a one-line commit-style note under
"Log" at the bottom.

### Pass 1 — Pure cleanup (no behavior change)

- [x] **1.1** ~~Split `lua/core/signal-highlight.lua` into a module folder~~
      **Superseded** — done as part of the move to `angular-tools`. See log.
- [x] **1.2** Eliminate the `full_scan_*_ref` forward-declaration hack.
      Done — `full_scan_ts`/`full_scan_html` are now defined before
      `on_filetype` is called.
- [x] **1.3** Replace the `hover_cache = {}` global-clear on every `*.ts` save
      with per-file invalidation. Done — `hover_cache[buf][key]` now stores
      `{verdict, file}`; the `BufWritePost` autocmd calls
      `lsp.invalidate_file(args.file)` which drops only entries whose symbol
      is defined in the saved file. The cost: every candidate now triggers
      hover + definition (was hover-only for confident verdicts), so ~2x LSP
      requests per scan. The benefit: saving `utils.ts` no longer invalidates
      signals in unrelated components.
- [x] **1.4** Reuse `core.files.get_base` for the `.html ↔ .ts` resolution.
      Done — `treesitter.scan_html_buffer` and the `BufWritePost` autocmd
      both use `files.get_base` and append `.component.ts` / `.component.html`.
      Tighter than the old gsub: only the Angular `.component.*` convention
      is recognized. `foo.html` → `foo.ts` is no longer auto-resolved (it
      wasn't a valid Angular pattern anyway).
- [x] **1.5** Replace the `'required'` sentinel in `SIGNAL_APIS` with two
      sets. Done — and added the missing items (input/model/viewChild/
      contentChild) to BOTH sets so plain form `model<T>(...)` is recognized.
- [x] **1.6** Lift magic numbers to `config.lua`:
      `DEBOUNCE_MS = 200`, `LSP_ATTACH_DELAY_MS = 1000`,
      `PRIORITY_OFFSET = 2` (implicit in PRIORITY). Done.

### Pass 2 — Fix the real bug

- [ ] **2.1** Collapse `NS` and `NS_LSP` into a single namespace.
      Do one redraw pass per cycle: clear once, then emit marks from the
      combined Layer-1 + Layer-2 verified set. This removes the "Layer 1
      false positives are permanent" limitation in
      `docs/angular-signal-highlighting.md` §0.
- [ ] **2.2** Single treesitter parse per cycle. Introduce a `BufState`
      struct `{buf, ts_tree, classes, ts_root, template_roots}` built once,
      consumed by both layers. Removes the duplicate `parse()` calls and
      duplicate `for_each_tree` walks.
- [ ] **2.3** `ts_member_query` and `usage_query` overlap (both target
      member_expression). Unify into one query, dispatch results to
      Layer 1 / Layer 2 by a simple test. Removes the
      "skip Layer 1 hits" workaround in `ts_candidates`.

### Pass 3 — Polish

- [ ] **3.1** Refine `template_query` to scope to actual Angular expression
      nodes (`property_binding`, `interpolation`, `event_binding`,
      `two_way_binding`, `structural_directive`, `let_binding`, `pipe_call`,
      `method_call`) instead of every `identifier` in the tree. Big perf win
      on large templates — currently every identifier triggers
      `is_member_access` + a string compare.
- [ ] **3.2** Replace `local enabled = true` module-local with a `state`
      struct `{enabled = true}`. Lets you add a `setup()` function for
      plugin extraction later without rewriting call sites.
- [ ] **3.3** `definition_is_signal` reads files from disk line-by-line per
      `unknown` hover verdict. Slurp the file once and use `lines[lineno]`,
      or cache by `(path, lineno)`.
- [ ] **3.4** Drop `M._find_declarations` from the public surface (or
      rename to `M._test_*` so the intent is explicit). `M.scan` /
      `M.scan_html` are the real public API.
- [ ] **3.5** Skip `*.stories.ts` and `*.spec.ts` in the `FileType
      typescript` autocmd (or accept the cost — TBD, currently cheap).
- [ ] **3.6** In `classify_hover`, log a debug message when a hover shape
      doesn't match any known pattern (currently silently returns `unknown`
      and falls through to definition lookup — degrades silently if a
      language server changes its hover output).

### Pass 4 — Tests

- [ ] **4.1** Add a test runner (`mini.test` or `plenary.busted`) if not
      already present in `_tests/`.
- [ ] **4.2** Tests for pure functions:
      - `is_signal_api(fn, base, prop)` — every API in `SIGNAL_APIS`,
        including `.required` variants and false positives like
        `inject(...)`.
      - `classify_hover(text)` — `(property) Foo.bar: Signal<number>`,
        `(property) Foo.bar: () => T` (alias-expanded), `(method) ...`,
        garbage.
      - `find_declarations(src)` — fixture TS source with one component
        and one non-component, verify per-class scoping, verify
        `inject(...)` is ignored.
      - `definition_is_signal(src, lineno)` — `x = signal(...)`,
        `x = input.required(...)`, `x: Signal<...>`, plain
        `x = something()`.
- [ ] **4.3** Headless test: open a TS buffer with a cross-file signal
      usage, run a scan, assert extmarks were placed. End-to-end smoke
      test for the wiring (autocmds, namespaces, etc.).

### Pass 5 — Plugin extraction (deferred)

- [ ] **5.1** Decide whether to extract to a standalone plugin repo
      (per `docs/angular-signal-highlighting.md` §0 "next steps").
      Public surface would be `require('angular-signal-highlight').setup({...})`
      with `extra_apis`, `extra_types`, `hl_override` config.
- [ ] **5.2** Move queries / config into a `plugin/` directory if extracted.
- [ ] **5.3** Update `docs/angular-signal-highlighting.md` §0 to reflect
      any architectural changes from this refactor.

---

## Log

<!-- One-line notes per step, e.g. "1.1: split into 8 files, behavior unchanged". -->

- **Step 1 (2026-02) — plugin scaffolded:** created `lua/angular-tools/`
  with `init.lua` + `config.lua` + `core/{init,files}.lua` +
  `features/{template-jumper,rename,ng-generate}/init.lua`. Moved
  `core/angular.lua` (file-jumper + rename + ng-generate palette) into
  the three feature folders. Wired via `require('angular-tools').setup()`
  in `core/init.lua`. Behavior unchanged; 6 keymaps still registered
  by default. Verified headlessly: setup() loads all 3 features,
  feature toggle (enabled=false) correctly skips keymap registration,
  `files.get_base` resolves `.component.html|.ts|.stories.ts` and
  returns nil for non-Angular paths. Total: 223 lines across 7 files
  (vs. 117 lines in the deleted `core/angular.lua` — overhead is the
  setup() machinery + per-feature folders).
- **Step 2 (2026-02) — signal-highlight split + moved:** deleted
  `lua/core/signal-highlight.lua` (699 lines) and created
  `lua/angular-tools/features/signal-highlight/` with 6 files
  (`init`, `config`, `queries`, `mark`, `treesitter`, `lsp`) totaling
  ~890 lines. Folded in Pass 1 cleanups: lifted magic numbers to
  `config.lua` (DEBOUNCE_MS=200, LSP_ATTACH_DELAY_MS=1000,
  PRIORITY_OFFSET=2 implicit), split the `'required'` sentinel into
  `SIGNAL_APIS` + `SIGNAL_APIS_REQUIRED` two-set model, eliminated
  the `full_scan_*_ref` forward-decl hack by reordering definitions
  in `init.lua`, wrapped `enabled` in a `state` struct. Dropped
  `M._find_declarations` (unused); re-exported `M.find_declarations`
  from `treesitter.lua` for future tests. Fixed one regression: original
  code recognized `model<T>(...)` (plain form) via `~= nil` check
  which accepted both `true` and `'required'`; new code's `== true`
  check missed the plain form. Fix: `input`, `model`, `viewChild`,
  `contentChild` listed in BOTH sets. Verified headlessly on a fixture
  TS file: 10 extmarks placed correctly (4 declarations + 4
  `this.<signal>()` usages + 1 inline template + 1 `this.count()`
  in computed body); non-signal `notASignal` and `plain` not
  highlighted. `:SignalHighlight off|on|refresh|toggle` all work;
  feature toggle (`signal-highlight.enabled = false`) correctly
  skips autocmd registration. Two Pass-2 items NOT done yet (TODO
  in code): single namespace + single treesitter parse per cycle,
  unified member query.
- **Step 3 (2026-02) — renames + 1.3 + 1.4:**
  - Renamed `layer1.lua` → `treesitter.lua`, `layer2.lua` → `lsp.lua`
    (mechanism names matching the design doc's "treesitter / LSP"
    terminology). Updated all `init.lua` requires.
  - **1.3 per-file cache invalidation:** `hover_cache[buf][key]` now
    stores `{verdict, file}`. `verify_candidates` always queries
    `textDocument/definition` (was definition-only for "unknown"
    hover results) to get the file. The `BufWritePost` autocmd now
    calls `lsp.invalidate_file(args.file)` which iterates all cache
    entries and drops those whose `entry.file` matches. Cost: ~2x LSP
    requests per scan (hover + definition always). Benefit: saving
    `utils.ts` no longer invalidates signals defined in
    `mycomponent.ts`. Renamed `clear_cache_for_*` to `invalidate_*`
    for consistency.
  - **1.4 shared `core.files`:** Replaced the naive
    `gsub('%.html$', '.ts')` and `gsub('%.ts$', '.html')` in
    `scan_html_buffer` and the `BufWritePost` autocmd with
    `files.get_base(...)` + `.component.ts` / `.component.html`.
    Tighter: only the Angular `.component.*` convention is
    recognized (the gsub was more permissive but not really
    correct for Angular). The autocmd now skips the rescan if
    the saved file isn't a `.component.ts` (was firing for
    `.spec.ts` and `.stories.ts` too, wasteful).
  - Verified headlessly: 10 marks on TS fixture, 2 marks on
    external HTML fixture (count + doubled in template; plain
    not highlighted). All three `lsp.invalidate_*` functions
    exist and don't error.
- **Step 4 (2026-02) — Pass 2 (NS collapse + BufState + unified
  query):** dropped `NS_LSP`, both layers now paint into `config.NS`.
  Per-cycle `BufState` built once in `treesitter.build_ts_state(buf)` /
  `build_html_state(buf)` and consumed by both layers (single typescript
  parse + single `for_each_tree` walk, no more duplicate parses). Single
  namespace + per-cycle redraw: orchestrator (`init.lua`) calls
  `lsp.start_cycle(buf)` to start a fresh cycle, then
  `treesitter.paint_ts_state` records each L1 mark via the
  `lsp.note_l1_paint` callback; `lsp.verify_candidates` records verified
  + rejected into the same cycle; a `vim.uv` timer fires the redraw
  `REDRAW_DEBOUNCE_MS` (200) after the last hover response, clears the
  NS once, then emits `(L1 - rejected) + L2 verified`. A cycle-object
  identity check in the hover response handler drops stale responses
  (user typed again, new cycle already started). Unification: the old
  `usage_ts` query is gone; both layers iterate `ts_member` in one pass
  in `paint_ts_state`, dispatching `this.x` inside a class that has x as
  a signal to L1 (mark + cycle note) and everything else to L2
  candidate. The "skip Layer 1 hits" loop in `lsp.ts_candidates` is gone
  (the function is gone — `lsp.lsp_scan_ts` now accepts the L2 candidate
  list as a parameter). Template bare-x in L1's set are still L2
  candidates with `from_l1 = true` so a `not_signal` hover verdict
  rejects them in the redraw — this is what actually closes the
  "permanent false positive" hole. Total: 1092 lines across 6 files
  (up from ~890 in step 2, +200 for cycle bookkeeping + redraw). Mark.lua
  shrank from 24 to 20 lines (single `place` function). Verified
  headlessly on the same fixture: 12 TS marks (4 template + 4 decls + 4
  `this.x` usages) and 4 HTML marks (count, doubled, name, requiredName);
  `notASignal` and `plain` correctly NOT highlighted. Three consecutive
  scans in a row produce the same mark set (cycle replacement works).
  `notASignal` in a template (the false-positive case) cannot be
  tested headlessly without an LSP server, but the rejection path is
  exercised by every cycle and the cache stores the file for
  per-file invalidation.
