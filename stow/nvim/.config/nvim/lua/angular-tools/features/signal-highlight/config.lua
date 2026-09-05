-- Static configuration for signal-highlight.
-- All data tables and magic numbers live here so the rest of the feature
-- has no hardcoded knowledge of which APIs count as signals or what colors
-- to use. User can override the highlight look via setup({hl = {...}}).

local M = {}

-- Highlight group. Set at module load; user can override afterwards.
M.HL_GROUP = '@angular.signal'
M.HL_DEFAULT = { default = true, fg = '#e5c07b', italic = true }

-- Above LSP semantic tokens (125), so signals win over vtsls property tokens.
M.PRIORITY = (vim.hl and vim.hl.priorities and vim.hl.priorities.semantic_tokens or 125) + 2

-- Single namespace: both Layer 1 (sync, treesitter) and Layer 2 (async, LSP)
-- paint into the same one. The orchestrator does one redraw pass per cycle:
-- clear once, then emit (Layer 1 minus Layer 2 rejections) + Layer 2 verified.
-- (See docs/signal-highlight-refactor.md pass 2.1.)
M.NS = vim.api.nvim_create_namespace('angular_signal_highlight')

-- Autocmd / scan tuning.
M.DEBOUNCE_MS         = 200  -- TextChanged / InsertLeave debounce
M.LSP_ATTACH_DELAY_MS = 1000 -- delay after LspAttach before Layer 2 runs
M.REDRAW_DEBOUNCE_MS  = 200  -- wait after the last hover response before redrawing

-- Signal-creating APIs. Plain ones (no .required variant) are listed
-- only in SIGNAL_APIS. APIs that have BOTH a plain and a .required form
-- (input, model, viewChild, contentChild) appear in both sets — the
-- redundancy is intentional so the two lookups in is_signal_api() stay
-- simple. Don't remove from one set without checking the other.
M.SIGNAL_APIS = {
    signal          = true,
    computed        = true,
    linkedSignal    = true,
    toSignal        = true,
    resource        = true,
    rxResource      = true,
    httpResource    = true,
    viewChildren    = true,
    contentChildren = true,
    -- APIs with both forms:
    input           = true,
    model           = true,
    viewChild       = true,
    contentChild    = true,
}
M.SIGNAL_APIS_REQUIRED = {
    input        = true,
    model        = true,
    viewChild    = true,
    contentChild = true,
}

-- Hover type names that identify a signal (Layer 2).
M.SIGNAL_TYPES = {
    Signal                  = true,
    WritableSignal          = true,
    InputSignal             = true,
    InputSignalWithTransform = true,
    ModelSignal             = true,
    Resource                = true,
    WritableResource        = true,
    ResourceRef             = true,
    HttpResourceRef         = true,
}

return M
