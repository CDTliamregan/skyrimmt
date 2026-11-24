-- Used by ultimate.sh fetch, every second: after each nxm download SkyrimMT asks "Downloaded …: Install it now?"
-- (Install/Later) and opens its mod manager window. Answer "Later" (the archive stays in the downloads folder;
-- ultimate.sh install installs everything at the end), keep SkyrimMT hidden, and put Chrome back in front.
tell application "System Events"
	if not (exists process "SkyrimMT") then return 0
	set shown to false
	tell process "SkyrimMT"
		repeat with w in windows
			try
				if (exists button "Later" of w) and (exists button "Install" of w) and (exists static text "Install it now?" of w) then click button "Later" of w
			end try
		end repeat
		if visible then
			set visible to false
			set shown to true
		end if
	end tell
end tell
if shown then tell application "Google Chrome" to activate
return 0
