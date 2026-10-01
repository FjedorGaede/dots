-- Angular language server tweaks (extends nvim-lspconfig's angularls).
--
-- The server only understands languageId 'typescript' and 'html'
-- (LanguageId enum in vscode-ng-language-service/server/src/session.ts).
-- Neovim's htmlangular filetype sends languageId 'htmlangular', which the
-- server silently ignores -> no hover/definition/diagnostics in templates.
--
-- Note: angularls is allowed to attach to .ts files alongside vtsls --
-- the cross-server dedup in lua/core/lsp.lua handles the duplicate
-- definition/references results, and angularls knows about template
-- usages that vtsls doesn't (e.g. <app-foo> from selector: 'app-foo').
return {
    get_language_id = function(_, filetype)
        if filetype == 'htmlangular' then
            return 'html'
        end
        return filetype
    end,
}
