local selected_or_hovered = ya.sync(function()
	local tab, paths = cx.active, {}
	for _, u in pairs(tab.selected) do
		paths[#paths + 1] = tostring(u)
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tostring(tab.current.hovered.url)
	end
	return paths
end)

local function notify(content, level)
	ya.notify {
		title = "Clipboard",
		content = content,
		level = level,
		timeout = 5,
	}
end

return {
	entry = function(_, job)
		ya.emit("escape", { visual = true })

		local paths = selected_or_hovered()
		if #paths == 0 then
			return notify("No file selected", "warn")
		end

		local home = os.getenv("HOME")
		local script = home and (home .. "/.config/yazi/scripts/copy-files-to-pasteboard.swift")
		local output, err = Command("swift"):arg(script):arg(paths):output()
		if not output then
			return notify("Failed to run swift: " .. err, "error")
		elseif not output.status.success then
			return notify("File copy failed", "error")
		end

		notify(string.format("Copied %d file(s)", #paths), "info")
	end,
}
