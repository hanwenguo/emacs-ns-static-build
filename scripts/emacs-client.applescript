-- Emacs Client AppleScript Application
-- Handles opening files from Finder, drag-and-drop, Spotlight/Dock launch,
-- and org-protocol URLs by calling the launchd-managed Emacs daemon.

property emacsClientPath : "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient"

on open theDropped
	repeat with oneDrop in theDropped
		set dropPath to POSIX path of oneDrop
		my runClientWithArguments(" " & quoted form of dropPath, true)
	end repeat
end open

on run
	my runClientWithArguments("", true)
end run

-- Handle URL open events, including org-protocol:// URLs registered in Info.plist.
on «event GURLGURL» thisURL
	my runClientWithArguments(" " & quoted form of thisURL, false)
end «event GURLGURL»

on runClientWithArguments(clientArguments, createFrame)
	set frameArgument to ""
	if createFrame then set frameArgument to " -c"

	set clientCommand to quoted form of emacsClientPath & frameArgument & " -n" & clientArguments

	do shell script clientCommand
end runClientWithArguments
