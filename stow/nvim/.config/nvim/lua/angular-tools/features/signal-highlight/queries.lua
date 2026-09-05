-- Treesitter queries used by signal-highlight. All parsed on module load.
-- Kept as raw query strings so they live in one place and are easy to
-- copy/adapt for related features (RxJS operators, etc.).

local M = {}

---Class fields whose value is a call expression.
---Captures: @name (the field name), @fn / @fn_base / @fn_prop (the callee).
M.decl_ts = vim.treesitter.query.parse('typescript', [[
    (public_field_definition
      name: (property_identifier) @name
      value: (call_expression
        function: [
          (identifier) @fn
          (member_expression
            object: (identifier) @fn_base
            property: (property_identifier) @fn_prop)
        ]))
]])

---All `<obj>.<prop>` member accesses in .ts. Used by BOTH layers in a
---single pass (see paint_ts_state): `this.x` inside a class that has x
---as a signal → Layer 1 mark, everything else → Layer 2 candidate.
M.ts_member = vim.treesitter.query.parse('typescript', [[
    (member_expression
      property: (property_identifier) @prop)
]])

---Identifiers in angular templates. Member-property identifiers are
---filtered out downstream via treesitter.is_member_access().
M.template = vim.treesitter.query.parse('angular', [[
    (identifier) @id
]])

return M
