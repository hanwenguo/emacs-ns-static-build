-- Emacs Client AppleScript Application
-- Handles opening files from Finder, drag-and-drop, Spotlight/Dock launch,
-- and org-protocol URLs by calling the Emacs.app installed in /Applications.

property emacsAppBundlePath : "/Applications/Emacs.app"
property emacsBinaryPath : "/Applications/Emacs.app/Contents/MacOS/Emacs"
property emacsClientPath : "/Applications/Emacs.app/Contents/MacOS/bin/emacsclient"

on open theDropped
	repeat with oneDrop in theDropped
		set dropPath to POSIX path of oneDrop
		try
			my runClientWithArguments(" " & quoted form of dropPath, true)
		end try
	end repeat
	my activateEmacs()
end open

on run
	try
		my runClientWithArguments("", true)
	end try
	my activateEmacs()
end run

-- Handle URL open events, including org-protocol:// URLs registered in Info.plist.
on «event GURLGURL» thisURL
	try
		my runClientWithArguments(" " & quoted form of thisURL, false)
	end try
	my activateEmacs()
end «event GURLGURL»

on runClientWithArguments(clientArguments, createFrame)
	set frameArgument to ""
	if createFrame then set frameArgument to " -c"

	set clientCommand to quoted form of emacsClientPath & frameArgument & " -n" & clientArguments
	set daemonCommand to quoted form of emacsBinaryPath & " --daemon >/dev/null 2>&1"

	do shell script clientCommand & " || (" & daemonCommand & " && " & clientCommand & ")"
end runClientWithArguments

on activateEmacs()
	try
		do shell script "open " & quoted form of emacsAppBundlePath
	end try
end activateEmacs
