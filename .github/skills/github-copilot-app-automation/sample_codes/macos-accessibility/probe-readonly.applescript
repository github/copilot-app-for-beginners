on run argv
  set targetPid to 0
  if (count of argv) > 0 then set targetPid to (item 1 of argv) as integer

  tell application "System Events"
    set outText to "COPILOT PROCESS PROBE" & linefeed
    repeat with procRef in every application process whose name contains "Copilot" or name contains "github" or name contains "GitHub"
      set procName to name of procRef
      set procPid to unix id of procRef
      set winCount to 0
      set winNames to ""
      try
        set winCount to count of windows of procRef
        set winNames to (name of every window of procRef) as text
      end try
      set outText to outText & procName & " pid=" & procPid & " windows=" & winCount & " names=" & winNames & linefeed
    end repeat

    if targetPid > 0 then
      set targetProcess to missing value
      repeat with candidateProcess in every application process
        try
          if (unix id of candidateProcess) is targetPid then
            set targetProcess to candidateProcess
            exit repeat
          end if
        end try
      end repeat
    else
      set matchingProcesses to every application process whose name is "GitHub Copilot"
      if (count of matchingProcesses) is not 1 then error "Pass a process ID when multiple GitHub Copilot instances are running."
      set targetProcess to item 1 of matchingProcesses
    end if
    if targetProcess is missing value then error "Target GitHub Copilot process was not found."

    tell targetProcess
      set frontmost to true
      delay 0.5
      set outText to outText & linefeed & "WINDOWS AND MENUS" & linefeed
      set outText to outText & "windows=" & ((name of every window) as text) & linefeed
      set outText to outText & "menus=" & ((name of every menu bar item of menu bar 1) as text) & linefeed

      if (count of windows) > 0 then
        set webArea to UI element 1 of UI element 1 of UI element 1 of UI element 1 of window 1
        set outText to outText & linefeed & "WEBAREA" & linefeed
        set outText to outText & "role=" & (role of webArea) & " desc=" & (description of webArea) & " children=" & (count of UI elements of webArea) & linefeed

        set allItems to entire contents of webArea
        set listedCount to 0
        repeat with itemRef in allItems
          set itemRole to ""
          set itemName to ""
          try
            set itemRole to role of itemRef
          end try
          try
            set itemName to name of itemRef
          end try
          if itemName is not "" and itemName is not "missing value" then
            set listedCount to listedCount + 1
            set outText to outText & listedCount & " role=" & itemRole & " name=" & itemName & linefeed
          end if
          if listedCount > 120 then exit repeat
        end repeat
      end if
    end tell
  end tell

  return outText
end run
