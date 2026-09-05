-- Autocommands configuration

-- On comments it does not auto adding comments on new line when using
-- "o" but still when using insert mode and hitting return
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("no_auto_comment", {}),
    callback = function()
        vim.opt_local.formatoptions:remove({ "c", "o"})
    end,
})

-- Return cursor position to the previous state in the file
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function(args)
        local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
        local line_count = vim.api.nvim_buf_line_count(args.buf)
        if mark[1] > 0 and mark[1] <= line_count then
            vim.api.nvim_win_set_cursor(0, mark)
            -- defer rending a bit so it is applied after render
            vim.schedule(function()
                vim.cmd("normal! zz")
            end)
        end
    end,
})

-- Highlight yanked text
vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("post_yank", { clear = true }),
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({ timeout = 200, visual = true, higroup= "OnYank" })
    end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesActionRename",
  callback = function(event)
    Snacks.rename.on_rename_file(event.data.from, event.data.to)
  end,
})

-- Trim trailing whitespace and extra blank lines at end of file on save
vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("mini_trailspace_auto_trim", { clear = true }),
    callback = function()
        MiniTrailspace.trim()
        MiniTrailspace.trim_last_lines()
    end,
})

vim.filetype.add({
    filename = {
        [".commonshellrc"] = "sh",
    },
    pattern = {
        [".*"] = {
            priority = -math.huge,
            function(path, bufnr)
                local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
                if first_line:match("^#!/.*bash") then
                    return "sh"
                end
            end,
        },
    },
})

return {}
