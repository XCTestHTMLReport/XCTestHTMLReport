-- Xcode UI automation for the viewer-compare harness.
--
-- One file with a command dispatcher rather than five one-liner scripts, so the
-- accessibility paths this depends on — which are the part that breaks when
-- Xcode ships a new report viewer — are all in one place to re-derive.
--
--   osascript xcode_ui.applescript get-appearance
--   osascript xcode_ui.applescript set-appearance dark|light
--   osascript xcode_ui.applescript find <bundle-basename>
--   osascript xcode_ui.applescript pin <winIndex> <x> <y> <w> <h>
--   osascript xcode_ui.applescript select <winIndex> summary|tests|logs
--   osascript xcode_ui.applescript rows <winIndex>
--
-- Every command prints one line. Failures print "ERR|<reason>" and exit 0, so
-- the caller decides whether to fall back to a guided manual step rather than
-- dying on a `set -e` trip.
--
-- Requires Accessibility permission for whatever runs osascript (Terminal,
-- iTerm, the editor's shell — the prompt names it). Xcode 26.2 verified.

on run argv
	if (count of argv) < 1 then return "ERR|usage: xcode_ui.applescript <command> [args]"
	set cmd to item 1 of argv
	try
		if cmd is "get-appearance" then
			return getAppearance()
		else if cmd is "set-appearance" then
			return setAppearance(item 2 of argv)
		else if cmd is "find" then
			return findReportWindow(item 2 of argv)
		else if cmd is "pin" then
			return pinWindow(item 2 of argv, item 3 of argv, item 4 of argv, item 5 of argv, item 6 of argv)
		else if cmd is "select" then
			return selectView(item 2 of argv, item 3 of argv)
		else if cmd is "rows" then
			return listRows(item 2 of argv)
		end if
		return "ERR|unknown command " & cmd
	on error msg
		return "ERR|" & msg
	end try
end run

-- Xcode's report viewer has no appearance of its own; it follows the system,
-- which is why the harness moves the whole machine between shots and puts the
-- original value back afterwards.
on getAppearance()
	tell application "System Events"
		tell appearance preferences
			if dark mode then return "dark"
			return "light"
		end tell
	end tell
end getAppearance

on setAppearance(mode)
	tell application "System Events"
		tell appearance preferences
			set dark mode to (mode is "dark")
		end tell
	end tell
	return mode
end setAppearance

-- Identifies the report window by what it contains, not by its title: a window
-- opened straight onto an .xcresult has an EMPTY title bar, and when a project
-- is already open the bundle's window sits alongside one titled after the
-- project. The discriminator is the first row of the Report navigator, which is
-- the bundle's own filename.
--
-- System Events orders windows front to back, and this returns the FIRST match.
-- That matters when a previous run left a window open on a different bundle
-- with the same filename: `open -a Xcode` puts the one just asked for in front,
-- so the frontmost match is the right one.
--
-- Prints "idx|x|y|w|h|rowCount".
on findReportWindow(bundleName)
	tell application "System Events" to tell process "Xcode"
		repeat with i from 1 to (count of windows)
			try
				set w to window i
				set ol to outline 1 of scroll area 1 of group 1 of w
				set rws to rows of ol
				if (count of rws) > 0 then
					if my rowLabel(item 1 of rws) is bundleName then
						set p to position of w
						set s to size of w
						return (i as string) & "|" & (item 1 of p as string) & "|" & (item 2 of p as string) & "|" & (item 1 of s as string) & "|" & (item 2 of s as string) & "|" & ((count of rws) as string)
					end if
				end if
			end try
		end repeat
	end tell
	return "ERR|no Xcode window whose report navigator starts with " & bundleName
end findReportWindow

-- Prints "x|y|w|h" as the window actually ended up. The caller compares that
-- against what it asked for: Xcode refuses sizes below its own minimum, and a
-- silently smaller window would put the two sides at different logical widths
-- while every filename still claimed 1440.
on pinWindow(idx, px, py, pw, ph)
	set theIndex to idx as integer
	tell application "System Events" to tell process "Xcode"
		set w to window theIndex
		set position of w to {px as integer, py as integer}
		set size of w to {pw as integer, ph as integer}
		set p to position of w
		set s to size of w
		return (item 1 of p as string) & "|" & (item 2 of p as string) & "|" & (item 1 of s as string) & "|" & (item 2 of s as string)
	end tell
end pinWindow

on listRows(idx)
	set theIndex to idx as integer
	tell application "System Events" to tell process "Xcode"
		set ol to outline 1 of scroll area 1 of group 1 of window theIndex
		set out to ""
		repeat with r in (rows of ol)
			if out is not "" then set out to out & "|"
			set out to out & my rowLabel(r)
		end repeat
		return out
	end tell
end listRows

-- Selects a view by moving the Report navigator's selection with the arrow
-- keys.
--
-- Setting `selected of row` directly does NOT work: the row highlights and the
-- editor keeps showing whatever it showed before, because the AX write never
-- reaches the outline's selection delegate. `click at {x, y}` does not work
-- either. A keyboard press on the focused outline is the one gesture Xcode 26.2
-- treats as a real navigation — and it only lands when Xcode is frontmost,
-- which is why this activates first and why the harness cannot share the
-- machine with someone else's typing while it runs.
on selectView(idx, mode)
	set theIndex to idx as integer
	tell application "Xcode" to activate
	delay 0.8
	tell application "System Events" to tell process "Xcode"
		set ol to outline 1 of scroll area 1 of group 1 of window theIndex
		set rws to rows of ol
		set n to (count of rws)
		if n = 0 then return "ERR|report navigator is empty"

		set labels to {}
		repeat with i from 1 to n
			set end of labels to my rowLabel(item i of rws)
		end repeat

		set target to 0
		repeat with i from 1 to n
			set lbl to item i of labels
			if mode is "tests" and lbl is "Tests" then
				set target to i
			else if mode is "logs" and (lbl is "Log" or lbl is "Logs") then
				set target to i
			else if mode is "summary" and target is 0 and i > 1 then
				-- The summary row is named after the scheme, so it cannot be
				-- matched by name across projects. It is the first row under
				-- the bundle that is not one of the named sub-reports.
				if lbl is not "Tests" and lbl is not "Log" and lbl is not "Logs" and lbl does not end with "Insights" then set target to i
			end if
		end repeat
		if target is 0 then return "ERR|no report-navigator row matched " & mode & " (rows: " & my joinList(labels) & ")"

		set focused of ol to true
		delay 0.3

		-- Bounded: a row that will not take the selection must surface as a
		-- failure the caller can fall back from, not as a spin.
		repeat 16 times
			set cur to 0
			repeat with i from 1 to n
				if selected of (item i of rws) then set cur to i
			end repeat
			if cur is target then return "OK|" & (item target of labels)
			if cur is 0 or cur < target then
				key code 125 -- down arrow
			else
				key code 126 -- up arrow
			end if
			delay 0.35
		end repeat
		return "ERR|selection never reached " & mode & " row"
	end tell
end selectView

on rowLabel(r)
	set lbl to ""
	tell application "System Events"
		repeat with t in (static texts of UI element 1 of r)
			try
				set v to (value of t) as string
				if v is not "" then
					if lbl is not "" then set lbl to lbl & " "
					set lbl to lbl & v
				end if
			end try
		end repeat
	end tell
	return lbl
end rowLabel

on joinList(items_)
	set out to ""
	repeat with x in items_
		if out is not "" then set out to out & ", "
		set out to out & (x as string)
	end repeat
	return out
end joinList
