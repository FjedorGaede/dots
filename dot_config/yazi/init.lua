local function getFormattedTime(time)
	return time and os.date("%d-%m-%Y %H:%M", time) or ""
end

function Linemode:mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	time = getFormattedTime(time)
	return ui.Line(string.format(time))
end

function Linemode:btime()
	local time = math.floor(self._file.cha.btime or 0)
	time = getFormattedTime(time)
	return ui.Line(string.format(time))
end
