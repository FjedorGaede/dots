-- Default configuration for angular-tools.
-- Override via require('angular-tools').setup({...}).
-- Anything not specified here keeps the default.

return {
    features = {
        ['template-jumper'] = { enabled = true },
        ['rename']          = { enabled = true },
        ['ng-generate']     = { enabled = true },
        ['signal-highlight'] = { enabled = true },
        ['selector-usages']  = { enabled = true, highlight = true },
    },
}
