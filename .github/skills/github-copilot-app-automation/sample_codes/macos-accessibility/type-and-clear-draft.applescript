on run argv
  set targetPid to 0
  if (count of argv) > 0 then set targetPid to (item 1 of argv) as integer
  set draftText to "DRAFT ONLY - accessibility automation probe - do not submit"

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
      set messageTextArea to missing value

      repeat with itemRef in allItems
        set itemRole to ""
        set itemName to ""
        try
          set itemRole to role of itemRef
        end try
        try
          set itemName to name of itemRef
        end try
        if itemRole is "AXTextArea" and itemName is "Message" then
          set messageTextArea to itemRef
          exit repeat
        end if
      end repeat

      if messageTextArea is missing value then error "Message text area not found"

      perform action "AXPress" of messageTextArea
      delay 0.2

      set directSetWorked to false
      try
        set value of messageTextArea to draftText
        set directSetWorked to true
      end try

      delay 0.3
      set typedValue to ""
      try
        set typedValue to value of messageTextArea as text
      end try

      if typedValue does not contain "accessibility automation probe" then
        keystroke draftText
        delay 0.3
        try
          set typedValue to value of messageTextArea as text
        end try
      end if

      perform action "AXPress" of messageTextArea
      delay 0.2
      keystroke "a" using command down
      delay 0.1
      key code 51
      delay 0.3

      set clearedValue to ""
      try
        set clearedValue to value of messageTextArea as text
      end try

      return "direct-set-worked=" & directSetWorked & linefeed & "typed-value=" & typedValue & linefeed & "cleared-value=" & clearedValue
    end tell
  end tell
end run
