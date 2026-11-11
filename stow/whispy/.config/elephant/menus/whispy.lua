-- Walker menu: whispy dictation history (prefix "," in walker).
-- Lists accepted transcripts, newest first; Enter copies the text.
Name = "whispy"
NamePretty = "Whispy"
Icon = "audio-input-microphone"
Description = "whispy dictation history"
Action = "lua:Copy"
FixedOrder = true
SearchName = true

local LOG = os.getenv("HOME") .. "/.local/state/whispy/transcripts.jsonl"
local MAX = 200

function GetEntries()
    local entries = {}
    local f = io.open(LOG, "r")
    if not f then
        return entries
    end
    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()

    for i = #lines, 1, -1 do
        local ok, t = pcall(jsonDecode, lines[i])
        if ok and t and t.accepted and t.text and t.text ~= "" then
            table.insert(entries, {
                Text = t.text,
                Subtext = os.date("%d.%m. - %H:%M", math.floor(t.timestamp)),
                Value = t.text,
            })
            if #entries >= MAX then
                break
            end
        end
    end
    return entries
end

function Copy(value)
    local p = io.popen("wl-copy", "w")
    if p then
        p:write(value)
        p:close()
    end
end
