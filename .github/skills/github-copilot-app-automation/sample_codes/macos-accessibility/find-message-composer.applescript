on run argv
  set targetPid to 0
  if (count of argv) > 0 then set targetPid to (item 1 of argv) as integer

  tell application "System Events"
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
      if (count of windows) = 0 then error "GitHub Copilot has no accessible windows"

      set webArea to UI element 1 of UI element 1 of UI element 1 of UI element 1 of window 1
      set allItems to entire contents of webArea
      set outText to "MESSAGE-LIKE CONTROLS" & linefeed
      set matchCount to 0

      repeat with itemRef in allItems
        set itemRole to ""
        set itemName to ""
        set itemValue to ""
        set actionsText to ""
        try
          set itemRole to role of itemRef
        end try
        try
          set itemName to name of itemRef
        end try
        if itemRole is "AXTextArea" or itemRole is "AXTextField" or itemName is "Message" then
          set matchCount to matchCount + 1
          try
            set itemValue to value of itemRef as text
          end try
          try
            set actionsText to (name of every action of itemRef) as text
          end try
          set outText to outText & matchCount & " role=" & itemRole & " name=" & itemName & " value=" & itemValue & " actions=" & actionsText & linefeed
        end if
      end repeat

      return outText
    end tell
  end tell
end run
