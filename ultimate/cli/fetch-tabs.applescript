-- Used by ultimate.sh fetch. One Chrome window at fixed bounds holds the next few files' Nexus pages as tabs;
-- the first tab is the one shown.
--   init "x1,y1,x2,y2" url1 url2 …   → new window with those tabs, first shown, in front; returns the window id
--   advance <window id> [next url]    → close the shown tab, show the next, preload [next url] at the end
--   poll                              → answers SkyrimMT's "Install it now?" with Later ("done"), and reports an nxm
--                                       hand-off ("click": SkyrimMT came forward without that prompt); hides SkyrimMT
on run argv
	set cmd to item 1 of argv
	if cmd is "poll" then
		set r to ""
		tell application "System Events"
			if not (exists process "SkyrimMT") then return ""
			tell process "SkyrimMT"
				repeat with w in windows
					try
						if (exists button "Later" of w) and (exists button "Install" of w) and (exists static text "Install it now?" of w) then
							click button "Later" of w
							set r to "done"
						end if
					end try
				end repeat
				if visible then
					set visible to false
					if r is "" then set r to "click"
				end if
			end tell
		end tell
		if r is not "" then tell application "Google Chrome" to activate
		return r
	end if
	tell application "Google Chrome"
		if cmd is "init" then
			set AppleScript's text item delimiters to ","
			set b to text items of (item 2 of argv)
			set AppleScript's text item delimiters to ""
			set w to make new window
			set bounds of w to {(item 1 of b) as integer, (item 2 of b) as integer, (item 3 of b) as integer, (item 4 of b) as integer}
			set URL of active tab of w to item 3 of argv
			repeat with k from 4 to (count of argv)
				make new tab at end of tabs of w with properties {URL:item k of argv}
			end repeat
			set active tab index of w to 1
			set index of w to 1
			activate
			return (id of w) as text
		else if cmd is "advance" then
			set w to window id ((item 2 of argv) as integer)
			if (count of tabs of w) > 1 then
				close tab 1 of w
			end if
			set active tab index of w to 1
			if (count of argv) ≥ 3 then
				if item 3 of argv is not "" then
					make new tab at end of tabs of w with properties {URL:item 3 of argv}
					set active tab index of w to 1
				end if
			end if
			set index of w to 1
			activate
			return (loading of tab 1 of w) as text
		else if cmd is "refresh" then
			set w to window id ((item 2 of argv) as integer)
			set active tab index of w to 1
			tell tab 1 of w to reload
			set index of w to 1
			activate
			return ""
		else if cmd is "close" then
			try
				close window id ((item 2 of argv) as integer)
			end try
			return ""
		end if
	end tell
end run
