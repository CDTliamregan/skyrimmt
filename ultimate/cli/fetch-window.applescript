-- Used by ultimate.sh fetch: shows one URL in a dedicated Chrome window at fixed bounds, in front.
-- args: url, "x1,y1,x2,y2", window id from the previous call (or ""); returns the window id.
on run argv
  set u to item 1 of argv
  set AppleScript's text item delimiters to ","
  set b to text items of item 2 of argv
  set wid to item 3 of argv
  tell application "Google Chrome"
    set w to missing value
    if wid is not "" then
      try
        set w to window id (wid as integer)
      end try
    end if
    if w is missing value then
      set w to make new window
    end if
    set bounds of w to {(item 1 of b) as integer, (item 2 of b) as integer, (item 3 of b) as integer, (item 4 of b) as integer}
    -- keep exactly one tab in the fetch window
    repeat while (count of tabs of w) > 1
      close tab (count of tabs of w) of w
    end repeat
    set URL of active tab of w to u
    set index of w to 1
    activate
    return id of w as text
  end tell
end run
