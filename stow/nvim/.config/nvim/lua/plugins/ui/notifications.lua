-- Notification system

-- Install notification plugin
addPackage("nvim-mini/mini.notify")

-- Configure notifications
-- TODO Do I even need this and if yes is it enough for me?
local MiniNotify = require("mini.notify")
MiniNotify.setup({
    content = {
        filter = function(notif)
            return not notif.msg:match("treesitter")
        end
    }
})

return {}
