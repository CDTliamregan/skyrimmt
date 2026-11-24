-- Used by ultimate.sh fetch: after each nxm download SkyrimMT asks "Downloaded …: Install it now?" (Install/Later).
-- Answer "Later" (the archive stays in the downloads folder; ultimate.sh install installs everything at the end).
tell application "System Events"
	if not (exists process "SkyrimMT") then return 0
	tell process "SkyrimMT"
		set n to 0
		repeat with w in windows
			try
				if (exists button "Later" of w) and (exists button "Install" of w) and (exists static text "Install it now?" of w) then
					click button "Later" of w
					set n to n + 1
				end if
			end try
		end repeat
		return n
	end tell
end tell
