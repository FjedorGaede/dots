-- Completion configuration

-- Install blink.cmp
addPackage({ src = 'Saghen/blink.cmp', version = vim.version.range('*') })

-- Configure blink.cmp
require("blink.cmp").setup({
    completion = { 
        documentation = { 
            auto_show = false 
        }, 
        menu = {
            border = "none",
            draw = {
                padding = 1
            },
        },
    },
    signature = {
        enabled = true,
        window = {
            show_documentation = false,
        }
    },
    fuzzy = {
        sorts = {
            function(a, b)
                local kind_priority = {
                    [10] = 1, -- Property
                    [5]  = 2, -- Field
                    [3]  = 3, -- Function
                    [2]  = 4, -- Method
                }
                local a_prio = kind_priority[a.kind] or 99
                local b_prio = kind_priority[b.kind] or 99
                if a_prio ~= b_prio then
                    return a_prio < b_prio
                end
            end,
            'score', 'sort_text',
        },
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer' },
      providers = {
        path = {
          opts = {
            show_hidden_files_by_default = true,
          },
        },
      },
    },
    keymap = {
        preset = "enter",

        ['<C-k>'] = { 'select_prev', 'fallback' },
        ['<C-j>'] = { 'select_next', 'fallback' },

        -- Signature
        ['<C-i>'] = { 'show_signature', 'hide_signature', 'fallback' },
        ['<C-u>'] = { 'scroll_signature_up', 'fallback' },
        ['<C-d>'] = { 'scroll_signature_down', 'fallback' },
    },
})

return {}
