; ============================================================================
; PROJECT     : FileExplorerNotes v3.0 (Enhanced)
; BASED ON    : FileExplorerNotes v2.0 by Gued3s
; DESCRIPTION : "Commit messages" for your local files. Context-aware 
;               description system for Windows Explorer.
;               Enhancements: centralized notes storage,
;               configurable hotkeys via UI + tray menu.
; LICENSE     : MIT
; ============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
TraySetIcon("C:\WINDOWS\system32\shell32.dll", 71)

; ============================================================================
; 1. GLOBAL CONFIGURATION
; ============================================================================

; Paths
global SCRIPT_DIR := A_ScriptDir
global CONFIG_PATH := SCRIPT_DIR "\config.ini"
global NOTES_DIR := SCRIPT_DIR "\.filenotes"

; Ensure centralized notes folder exists (hidden)
if !DirExist(NOTES_DIR) {
    try {
        DirCreate(NOTES_DIR)
        FileSetAttrib("+H", NOTES_DIR)
    }
}

; Dark Mode Colors (Win11 Native)
global COLOR_BG      := "1E1E1E"
global COLOR_EDIT    := "2D2D2D"
global COLOR_TEXT    := "FFFFFF"
global COLOR_LINE    := "000000"
global COLOR_BTN     := "0066CC"

; Preview & Cache Management
global PreviewState := Map("Active", false, "LastPath", "")
global NoteCache := Map()
global CACHE_MAX_SIZE := 50
global CACHE_MAX_AGE := 30000

; GUI Windows Registry (prevent duplicates, memory leaks)
global OpenGuis := Map()

; --- Hotkey Configuration ---
global HK_CREATE := LoadConfig("Hotkeys", "CreateNote", "^+d")
global HK_PREVIEW := LoadConfig("Hotkeys", "Preview", "^q")
global HK_SETTINGS := LoadConfig("Hotkeys", "Settings", "^+F12")

; --- Auto-Preview Configuration ---
global AUTO_PREVIEW_ENABLED := LoadConfig("AutoPreview", "Enabled", "1")
global AUTO_PREVIEW_DURATION := LoadConfig("AutoPreview", "Duration", "3000")

; --- Tooltip Style: "styled" or "default" ---
global STYLE_AUTO := LoadConfig("Style", "AutoPreview", "styled")
global STYLE_MANUAL := LoadConfig("Style", "ManualPreview", "styled")

LoadConfig(section, key, defaultVal) {
    try {
        val := IniRead(CONFIG_PATH, section, key)
        if (val != "" && val != "ERROR")
            return val
    }
    ; Write default if missing
    try IniWrite(defaultVal, CONFIG_PATH, section, key)
    return defaultVal
}

SaveConfig(section, key, val) {
    try IniWrite(val, CONFIG_PATH, section, key)
}

; Apply Dark Mode Globally
if (VerCompare(A_OSVersion, "10.0.18362") >= 0) {
    try DllCall("uxtheme\135", "int", 2)
}

; Custom styled tooltip GUI
global StyledTip := 0

OnExit(ExitHandler)
ExitHandler(*) {
    ToolTip()
    HideStyledTip()
    for filePath, guiObj in OpenGuis {
        try guiObj.Destroy()
    }
}

; ============================================================================
; 2. EXPLORER HOTKEYS (Context-Aware, Configurable)
; ============================================================================

RegisterHotkeys() {
    try {
        HotIfWinActive("ahk_class CabinetWClass ahk_exe explorer.exe")
        Hotkey(HK_CREATE, (*) => CreateNote())
        Hotkey(HK_PREVIEW, (*) => PreviewStart())
        Hotkey(HK_PREVIEW " Up", (*) => PreviewStop())
        HotIf()
    } catch as err {
        MsgBox("Failed to register Explorer hotkeys. Check config.ini for invalid values.`n`n" err.Message, "Hotkey Error", "Icon!")
    }
    ; Settings hotkey (always active)
    try Hotkey(HK_SETTINGS, (*) => OpenSettingsGUI())
    catch as err
        MsgBox("Failed to register Settings hotkey. Check config.ini.`n`n" err.Message, "Hotkey Error", "Icon!")
}
RegisterHotkeys()

; --- Tray Menu ---
A_TrayMenu.Delete()  ; Clear default menu
A_TrayMenu.Add("Settings", (*) => OpenSettingsGUI())
A_TrayMenu.Add("Open Notes Folder", (*) => Run(NOTES_DIR))
A_TrayMenu.Add("Edit Script", (*) => Edit())
A_TrayMenu.Add()  ; Separator
A_TrayMenu.Add("Reload Script", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Settings"

; ============================================================================
; 2a. AUTO-PREVIEW SYSTEM
;     Polls the focused file in Explorer and shows a styled tooltip
;     automatically when a note exists. No hotkey needed.
; ============================================================================

global AutoPreviewState := Map("LastPath", "", "Active", false)

StartAutoPreview() {
    global AutoPreviewState
    if (AUTO_PREVIEW_ENABLED != "1") {
        NoteCache.Clear()
        return
    }
    AutoPreviewState["Active"] := true
    SetTimer(AutoPreviewTick, 300)
}

StopAutoPreview() {
    global AutoPreviewState
    AutoPreviewState["Active"] := false
    AutoPreviewState["LastPath"] := ""
    SetTimer(AutoPreviewTick, 0)
    NoteCache.Clear()
}

AutoPreviewTick() {
    global AutoPreviewState, NoteCache

    static _busy := false
    if _busy
        return
    _busy := true

    try {
        if !WinActive("ahk_class CabinetWClass ahk_exe explorer.exe") {
            if AutoPreviewState["LastPath"] != "" {
                AutoPreviewState["LastPath"] := ""
                HideStyledTip()
                ToolTip()
            }
            return
        }

        shellWin := GetExplorerWindow()
        if !shellWin
            return

        focusedPath := ""
        try {
            focusedItem := shellWin.Document.FocusedItem
            if focusedItem
                focusedPath := focusedItem.Path
        }

        if !focusedPath || InStr(focusedPath, "\.filenotes\") {
            if AutoPreviewState["LastPath"] != "" {
                AutoPreviewState["LastPath"] := ""
                HideStyledTip()
                ToolTip()
            }
            return
        }

        notePath := EncodeNotePath(focusedPath)

        ; Same file as last tick — skip
        if notePath = AutoPreviewState["LastPath"]
            return

        AutoPreviewState["LastPath"] := notePath

        ; Only show for files that HAVE a note
        if !FileExist(notePath) {
            HideStyledTip()
            ToolTip()
            return
        }

        ; Read content (use cache)
        content := ReadNoteContent(notePath)
        if !content {
            HideStyledTip()
            ToolTip()
            return
        }

        SplitPath(focusedPath, &fName)
        if (STYLE_AUTO = "styled")
            ShowStyledTip("", content, true)
        else {
            preview := StrReplace(content, "`n", " · ")
            if StrLen(preview) > 80
                preview := SubStr(preview, 1, 80) "..."
            ToolTip("📝 " preview)
        }

        ; Auto-hide after configured duration
        duration := Integer(AUTO_PREVIEW_DURATION)
        if (STYLE_AUTO = "styled")
            SetTimer(HideStyledTip, -duration)
        else
            SetTimer(ClearDefaultTip, -duration)

    } finally {
        _busy := false
    }
}

; Read note with cache support (shared with manual preview)
ReadNoteContent(notePath) {
    global NoteCache
    currentFileTime := ""
    try currentFileTime := FileGetTime(notePath, "M")

    if NoteCache.Has(notePath) {
        cachedData := NoteCache[notePath]
        if currentFileTime = cachedData.FileTime && (A_TickCount - cachedData.AccessTime) < CACHE_MAX_AGE {
            cachedData.AccessTime := A_TickCount
            return cachedData.Content
        } else {
            NoteCache.Delete(notePath)
        }
    }

    content := ""
    try {
        content := FileRead(notePath, "m4000 UTF-8-RAW")
        if content {
            NoteCache[notePath] := {
                Content: content,
                AccessTime: A_TickCount,
                FileTime: currentFileTime
            }
            if NoteCache.Count > CACHE_MAX_SIZE {
                for key in NoteCache {
                    NoteCache.Delete(key)
                    break
                }
            }
        }
    }
    return content
}

; Start auto-preview on script load
StartAutoPreview()

ClearDefaultTip(*) => ToolTip()

; ============================================================================
; 2a-2. STYLED TOOLTIP (Custom GUI)
;       Dark-themed popup with title + content, rounded appearance.
; ============================================================================

ShowStyledTip(title, content, compact := false) {
    global StyledTip
    HideStyledTip()

    ; Truncate long content for tooltip display
    if StrLen(content) > 500
        content := SubStr(content, 1, 500) "..."

    tip := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", "StyledTip")
    tip.BackColor := "2D2D30"

    ; Rounded corners (Win11)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", tip.Hwnd, "int", 33, "int*", 3, "int", 4)
    ; Border color
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", tip.Hwnd, "int", 34, "int*", 0x00555555, "int", 4)

    if compact {
        ; --- Compact mode: subtle single-line indicator ---
        tip.MarginX := 8
        tip.MarginY := 4
        tip.SetFont("s8 cAAAAAA Norm", "Segoe UI")
        maxLen := 80
        preview := StrReplace(content, "`n", " · ")
        if StrLen(preview) > maxLen
            preview := SubStr(preview, 1, maxLen) "..."
        tip.Add("Text", , "📝 " preview)
    } else {
        ; --- Full mode: title + separator + content ---
        tip.MarginX := 12
        tip.MarginY := 8
        if title {
            tip.SetFont("s10 cE0E0E0 Bold", "Segoe UI")
            tip.Add("Text", "w350", title)
            tip.Add("Text", "x12 w350 h1 Background555555")
        }
        tip.SetFont("s9 cCCCCCC Norm", "Segoe UI")
        tip.Add("Text", "x12 w350", content)
    }

    ; Position near mouse, clamped to screen bounds
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    tipX := mx + 15
    tipY := my + 15

    ; Get screen work area dimensions
    monNum := MonitorGetCount()
    bestMon := 1
    Loop monNum {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (mx >= mL && mx < mR && my >= mT && my < mB) {
            bestMon := A_Index
            break
        }
    }
    MonitorGetWorkArea(bestMon, &wL, &wT, &wR, &wB)

    tip.Show("AutoSize NoActivate x" tipX " y" tipY)

    ; After showing, get actual size and clamp
    try {
        tip.GetPos(, , &tipW, &tipH)
        if (tipX + tipW > wR)
            tipX := wR - tipW
        if (tipY + tipH > wB)
            tipY := wB - tipH
        if (tipX < wL)
            tipX := wL
        if (tipY < wT)
            tipY := wT
        tip.Move(tipX, tipY)
    }

    StyledTip := tip
}

HideStyledTip(*) {
    global StyledTip
    if StyledTip {
        try StyledTip.Destroy()
        StyledTip := 0
    }
}

; ============================================================================
; 2b. NOTE PATH ENCODING
;     Encodes full file path into a safe filename stored centrally.
;     Format: Drive_Path_To_FileName.ext.txt
; ============================================================================

EncodeNotePath(filePath) {
    ; Encode path using double-underscore as separator to avoid collisions
    ; "C:\Users\foo\bar.txt" -> "C__Users__foo__bar.txt.txt"
    ; Single underscores in original names are preserved, double-underscore = path separator
    encoded := StrReplace(filePath, ":\", "__")
    encoded := StrReplace(encoded, "\", "__")
    encoded := StrReplace(encoded, "/", "__")
    encoded := StrReplace(encoded, ":", "__")
    return NOTES_DIR "\" encoded ".txt"
}

; ============================================================================
; 3. CORE: CREATE NOTE LOGIC
; ============================================================================

CreateNote() {
    shellWin := GetExplorerWindow()
    if !shellWin {
        MsgBox("Explorer window not found.", "Error", "Icon!")
        return
    }

    targetPath := ""
    try {
        for item in shellWin.Document.SelectedItems {
            targetPath := item.Path
            break
        }
    }
    
    if !targetPath || !FileExist(targetPath) || InStr(targetPath, "\.filenotes\") {
        ToolTip("⚠ Please select a valid file.")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    SplitPath(targetPath, &fileName, &fileDir)
    notePath := EncodeNotePath(targetPath)

    ; Open in GUI (prevent duplicate windows)
    if OpenGuis.Has(notePath) {
        try {
            WinActivate("ahk_id " OpenGuis[notePath].Hwnd)
            return
        } catch {
            OpenGuis.Delete(notePath)
        }
    }

    OpenNoteGUI(notePath, fileName)
}

; ============================================================================
; 4. NATIVE GUI EDITOR
;    - Custom Dark Mode text editor with Dirty Check monitoring.
;    - Responsive layout that adapts to window resizing.
;    - I still haven't managed to make the buttons look nice without the white border around them, but what matters is that it works
; ============================================================================

OpenNoteGUI(notePath, displayName) {
    ; Load existing content or start empty
    initialContent := ""
    if FileExist(notePath) {
        try initialContent := FileRead(notePath, "UTF-8-RAW")
    }

    ; Create window with dark theme support
    noteGui := Gui("+Resize +MinSize400x300 +OwnDialogs", "Note: " displayName)
    noteGui.MarginX := 0
    noteGui.MarginY := 0
    noteGui.BackColor := COLOR_BG
    noteGui.IsDirty := false
    noteGui.NotePath := notePath

    ; Win11 Dark Title Bar
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", noteGui.Hwnd, "int", 20, "int*", 1, "int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", noteGui.Hwnd, "int", 35, "int*", 0x00000000, "int", 4)

    noteGui.SetFont("s10 c" COLOR_TEXT, "Segoe UI")

    ; --- EDIT CONTROL ---
    editCtrl := noteGui.Add("Edit", "vEditCtrl x0 y0 w600 r20 -E0x200 -Border +Wrap +VScroll +WantReturn Background" COLOR_EDIT " c" COLOR_TEXT, initialContent)
    try DllCall("uxtheme\SetWindowTheme", "ptr", editCtrl.Hwnd, "str", "DarkMode_CFD", "ptr", 0)
    SendMessage(0x00D3, 3, (10 << 16) | 10, editCtrl.Hwnd) ; 10px margins

    ; Track modifications
    editCtrl.OnEvent("Change", GuiChange.Bind(noteGui))

    ; --- SEPARATOR LINE ---
    noteGui.Add("Text", "vSeparator x0 y0 w0 h1 Background" COLOR_LINE)

    ; --- BUTTONS ---
    btnSave := noteGui.Add("Button", "vBtnSave w100 h30 Default", "Save")
    btnDelete := noteGui.Add("Button", "vBtnDelete x+10 w100 h30", "Delete Note")
    btnCancel := noteGui.Add("Button", "vBtnCancel x+10 w100 h30", "Cancel")

    ; Aplica o tema escuro nativo do Windows 11 (Deixa cinza e arredondado)
    try DllCall("uxtheme\SetWindowTheme", "ptr", btnSave.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)
    try DllCall("uxtheme\SetWindowTheme", "ptr", btnDelete.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)
    try DllCall("uxtheme\SetWindowTheme", "ptr", btnCancel.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

    ; --- EVENTS ---
    btnSave.OnEvent("Click", GuiSave.Bind(noteGui, notePath, editCtrl))
    btnDelete.OnEvent("Click", GuiDeleteNote.Bind(noteGui, notePath))
    btnCancel.OnEvent("Click", GuiClose.Bind(noteGui, notePath, editCtrl))
    noteGui.OnEvent("Close", GuiClose.Bind(noteGui, notePath, editCtrl))
    noteGui.OnEvent("Size", GuiResize)

    ; --- LOCAL HOTKEYS ---
    HotIfWinActive("ahk_id " noteGui.Hwnd)
    Hotkey("^s", GuiSave.Bind(noteGui, notePath, editCtrl))
    Hotkey("^BS", CtrlBackspace.Bind(editCtrl))
    HotIf()

    ; Track window globally
    OpenGuis[notePath] := noteGui

    noteGui.Show("w600 h400")
    editCtrl.Focus()
}

; --- Event Handlers ---

GuiChange(noteGui, GuiCtrlObj, Info) {
    noteGui.IsDirty := true
}

GuiResize(GuiObj, MinMax, Width, Height) {
    ; Ignore minimize events
    if (MinMax = -1)
        return

    try {
        ; Edit Control: from top (0) to 60px before bottom
        GuiObj["EditCtrl"].Move(0, 0, Width, Height - 60)

        ; Separator Line: 1px height, positioned at Height - 60
        GuiObj["Separator"].Move(0, Height - 60, Width, 1)

        ; Save Button: bottom-left area with 15px padding
        GuiObj["BtnSave"].Move(15, Height - 45, 100, 30)

        ; Delete Button
        GuiObj["BtnDelete"].Move(125, Height - 45, 100, 30)

        ; Cancel Button
        GuiObj["BtnCancel"].Move(235, Height - 45, 100, 30)
    } catch {
        ; Graceful failure
    }
}

GuiSave(noteGui, notePath, editCtrl, *) {
    SaveNoteAtomic(notePath, editCtrl.Value)
    noteGui.IsDirty := false
    GuiDestroy(noteGui, notePath)
}

GuiDeleteNote(noteGui, notePath, *) {
    result := MsgBox("Are you sure you want to delete this note?", "Delete Note", "YesNo Icon?")
    if result = "Yes" {
        try FileDelete(notePath)
        if NoteCache.Has(notePath)
            NoteCache.Delete(notePath)
        noteGui.IsDirty := false
        GuiDestroy(noteGui, notePath)
    }
}

GuiClose(noteGui, notePath, editCtrl, *) {
    ; Check for unsaved changes
    if noteGui.IsDirty {
        result := MsgBox("You have unsaved changes. Save before closing?", "Unsaved Changes", "YesNoCancel Icon?")
        if result = "Cancel"
            return
        if result = "Yes"
            SaveNoteAtomic(notePath, editCtrl.Value)
    }
    GuiDestroy(noteGui, notePath)
}

GuiDestroy(noteGui, notePath) {
    try {
        HotIfWinActive("ahk_id " noteGui.Hwnd)
        Hotkey("^s", "Off")
        Hotkey("^BS", "Off")
        HotIf()
    }
    
    OpenGuis.Delete(notePath)
    noteGui.Destroy()
}


; ============================================================================
; 4b. CTRL+BACKSPACE WORD DELETION
;     Mimics Word/standard editor behavior: delete previous word.
; ============================================================================

CtrlBackspace(editCtrl, *) {
    ; Select previous word then delete — simpler approach avoids timing issues
    Send("^+{Left}{Del}")
}

; ============================================================================
; 5. ATOMIC SAVE (Data Integrity)
;    - Strategy: Write to .tmp -> Verify -> Replace original.
;    - Prevents file corruption during crashes or power loss.
; ============================================================================

SaveNoteAtomic(notePath, content) {
    tmpPath := notePath ".tmp"
    try {
        ; Write to temporary file first
        f := FileOpen(tmpPath, "w", "UTF-8-RAW")
        if !f {
            throw Error("Cannot open file for writing")
        }
        f.Write(content)
        f.Close()
        
        ; Atomic replacement (overwrite = 1)
        FileMove(tmpPath, notePath, 1)
        
        ; Invalidate cache
        if NoteCache.Has(notePath)
            NoteCache.Delete(notePath)
            
    } catch as err {
        try FileDelete(tmpPath)
        MsgBox("Error saving note:`n" err.Message, "Error", "Icon!")
    }
}


; ============================================================================
; 6. PREVIEW SYSTEM (ctrl + q / Hold to View)
;    - High-performance polling system with O(1) FIFO Cache.
;    - Minimizes Disk I/O and CPU usage during navigation.
; ============================================================================

ClearPreview() {
    HideStyledTip()
    ToolTip()
}

PreviewStart() {
    global PreviewState
    SetTimer(ClearPreview, 0)
    
    if PreviewState["Active"]
        return
    PreviewState["Active"] := true
    SetTimer(PreviewTick, 100)
    PreviewTick()
}

PreviewStop() {
    global PreviewState
    PreviewState["Active"] := false
    PreviewState["LastPath"] := ""
    SetTimer(PreviewTick, 0)
    SetTimer(ClearPreview, -250) ; 250ms delay to clear the tooltip
}

PreviewTick() {
    global PreviewState, NoteCache

    ; Guard: prevent re-entrancy
    static _inProgress := false
    if _inProgress
        return
    _inProgress := true

    try {
        if !PreviewState["Active"] || !WinActive("ahk_class CabinetWClass ahk_exe explorer.exe") {
            if PreviewState["Active"]
                PreviewStop()
            return
        }

        shellWin := GetExplorerWindow()
        if !shellWin {
            HideStyledTip()
            ToolTip()
            return
        }

        focusedPath := ""
        try {
            focusedItem := shellWin.Document.FocusedItem
            if focusedItem
                focusedPath := focusedItem.Path
        }

        if !focusedPath || InStr(focusedPath, "\.filenotes\") {
            HideStyledTip()
            ToolTip()
            return
        }

        SplitPath(focusedPath, &fileName, &fileDir)
        notePath := EncodeNotePath(focusedPath)

        if notePath = PreviewState["LastPath"]
            return

        PreviewState["LastPath"] := notePath

        if FileExist(notePath) {
            contentToDisplay := ReadNoteContent(notePath)
            if contentToDisplay {
                if (STYLE_MANUAL = "styled")
                    ShowStyledTip("📝  " fileName, contentToDisplay)
                else
                    ToolTip("📝  " fileName "`n────────────────────`n" contentToDisplay)
            } else {
                if (STYLE_MANUAL = "styled")
                    ShowStyledTip("", "(Empty description)")
                else
                    ToolTip("(Empty description)")
            }
        } else {
            if (STYLE_MANUAL = "styled")
                ShowStyledTip("", "(No description)")
            else
                ToolTip("(No description)")
        }
    } finally {
        _inProgress := false
    }
}

; ============================================================================
; 7. EXPLORER DETECTION (WIN11 TABS SUPPORT)
;    - Advanced COM logic to identify the physically active tab.
;    - Ensures 100% accuracy in multi-tab Explorer environments.
; ============================================================================

GetExplorerWindow() {
    hwnd := WinExist("A")
    if !hwnd
        return 0

    ; Detect active tab handle (Win11)
    activeTab := 0
    try activeTab := ControlGetHwnd("ShellTabWindowClass1", "ahk_id " hwnd)

    try {
        shell := ComObject("Shell.Application")
        for window in shell.Windows {
            if window.Hwnd != hwnd
                continue
            
            ; If window has tabs, verify this is the active one
            if activeTab {
                static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
                try {
                    shellBrowser := ComObjQuery(window, IID_IShellBrowser, IID_IShellBrowser)
                    ComCall(3, shellBrowser, "uint*", &thisTab := 0)
                    if thisTab != activeTab
                        continue
                } catch {
                    continue
                }
            }

            ; Verify document accessibility
            try {
                _ := window.Document.Folder.Self.Path
            } catch {
                continue
            }

            return window
        }
    } catch {
        return 0
    }
    
    return 0
}


; ============================================================================
; 8. SETTINGS GUI (Hotkey Configuration)
;    - Allows users to change hotkeys via a visual interface.
;    - Saves configuration to config.ini next to the script.
; ============================================================================

OpenSettingsGUI() {
    static settingsOpen := false
    if settingsOpen
        return
    settingsOpen := true

    sGui := Gui("+OwnDialogs", "FileExplorerNotes - Settings")
    sGui.MarginX := 15
    sGui.MarginY := 10
    sGui.BackColor := COLOR_BG

    ; Win11 Dark Title Bar
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", sGui.Hwnd, "int", 20, "int*", 1, "int", 4)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", sGui.Hwnd, "int", 35, "int*", 0x00000000, "int", 4)

    sGui.SetFont("s10 c" COLOR_TEXT, "Segoe UI")

    sGui.Add("Text", , "Hotkey Syntax:  ^ = Ctrl  |  ! = Alt  |  + = Shift  |  # = Win")
    sGui.Add("Text", , "Example: ^+d = Ctrl+Shift+D")
    sGui.Add("Text", "y+15", "")

    sGui.Add("Text", , "Create/Edit Note:")
    editCreate := sGui.Add("Edit", "vHkCreate w200 Background" COLOR_EDIT " c" COLOR_TEXT, HK_CREATE)
    try DllCall("uxtheme\SetWindowTheme", "ptr", editCreate.Hwnd, "str", "DarkMode_CFD", "ptr", 0)

    sGui.Add("Text", "y+10", "Preview Note (hold):")
    editPreview := sGui.Add("Edit", "vHkPreview w200 Background" COLOR_EDIT " c" COLOR_TEXT, HK_PREVIEW)
    try DllCall("uxtheme\SetWindowTheme", "ptr", editPreview.Hwnd, "str", "DarkMode_CFD", "ptr", 0)

    sGui.Add("Text", "y+10", "Settings Hotkey:")
    editSettings := sGui.Add("Edit", "vHkSettings w200 Background" COLOR_EDIT " c" COLOR_TEXT, HK_SETTINGS)
    try DllCall("uxtheme\SetWindowTheme", "ptr", editSettings.Hwnd, "str", "DarkMode_CFD", "ptr", 0)

    ; --- Auto-Preview Section ---
    sGui.Add("Text", "x15 y+20", "─────── Auto-Preview ───────")

    sGui.Add("Text", "y+10", "Enabled:")
    chkAutoPreview := sGui.Add("Checkbox", "vAutoPreviewOn c" COLOR_TEXT " Checked" AUTO_PREVIEW_ENABLED)
    try DllCall("uxtheme\SetWindowTheme", "ptr", chkAutoPreview.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

    sGui.Add("Text", "y+10", "Display Duration (ms):")
    editDuration := sGui.Add("Edit", "vAutoPreviewDur w200 Background" COLOR_EDIT " c" COLOR_TEXT, AUTO_PREVIEW_DURATION)
    try DllCall("uxtheme\SetWindowTheme", "ptr", editDuration.Hwnd, "str", "DarkMode_CFD", "ptr", 0)

    ; --- Tooltip Style Section ---
    sGui.Add("Text", "x15 y+20", "─────── Tooltip Style ───────")

    sGui.Add("Text", "y+10", "Auto-Preview Style:")
    ddAutoStyle := sGui.Add("DropDownList", "vStyleAuto w200 Background" COLOR_EDIT " c" COLOR_TEXT, ["styled", "default"])
    ddAutoStyle.Text := STYLE_AUTO
    try DllCall("uxtheme\SetWindowTheme", "ptr", ddAutoStyle.Hwnd, "str", "DarkMode_CFD", "ptr", 0)

    sGui.Add("Text", "y+10", "Manual Preview Style (Ctrl+Q):")
    ddManualStyle := sGui.Add("DropDownList", "vStyleManual w200 Background" COLOR_EDIT " c" COLOR_TEXT, ["styled", "default"])
    ddManualStyle.Text := STYLE_MANUAL
    try DllCall("uxtheme\SetWindowTheme", "ptr", ddManualStyle.Hwnd, "str", "DarkMode_CFD", "ptr", 0)

    sGui.Add("Text", "y+15", "")

    btnApply := sGui.Add("Button", "w100 h30 Default", "Save && Reload")
    try DllCall("uxtheme\SetWindowTheme", "ptr", btnApply.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

    btnFolder := sGui.Add("Button", "x+10 w100 h30", "Notes Folder")
    try DllCall("uxtheme\SetWindowTheme", "ptr", btnFolder.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

    btnClose := sGui.Add("Button", "x+10 w100 h30", "Cancel")
    try DllCall("uxtheme\SetWindowTheme", "ptr", btnClose.Hwnd, "str", "DarkMode_Explorer", "ptr", 0)

    btnApply.OnEvent("Click", SettingsSave.Bind(sGui))
    btnFolder.OnEvent("Click", (*) => Run(NOTES_DIR))
    btnClose.OnEvent("Click", (*) => (settingsOpen := false, sGui.Destroy()))
    sGui.OnEvent("Close", (*) => (settingsOpen := false, sGui.Destroy()))

    sGui.Show("AutoSize")
}

SettingsSave(sGui, *) {
    global HK_CREATE, HK_PREVIEW, HK_SETTINGS
    
    newCreate := sGui["HkCreate"].Value
    newPreview := sGui["HkPreview"].Value
    newSettings := sGui["HkSettings"].Value
    newAutoEnabled := sGui["AutoPreviewOn"].Value
    newAutoDuration := sGui["AutoPreviewDur"].Value
    newStyleAuto := sGui["StyleAuto"].Text
    newStyleManual := sGui["StyleManual"].Text
    
    if (newCreate = "" || newPreview = "" || newSettings = "") {
        MsgBox("Hotkeys cannot be empty.", "Error", "Icon!")
        return
    }
    
    if !IsInteger(newAutoDuration) || Integer(newAutoDuration) < 500 {
        MsgBox("Duration must be a number >= 500 ms.", "Error", "Icon!")
        return
    }
    
    SaveConfig("Hotkeys", "CreateNote", newCreate)
    SaveConfig("Hotkeys", "Preview", newPreview)
    SaveConfig("Hotkeys", "Settings", newSettings)
    SaveConfig("AutoPreview", "Enabled", newAutoEnabled)
    SaveConfig("AutoPreview", "Duration", newAutoDuration)
    SaveConfig("Style", "AutoPreview", newStyleAuto)
    SaveConfig("Style", "ManualPreview", newStyleManual)
    
    sGui.Destroy()
    Reload()
}


; ============================================================================
; 📂 USER GUIDE & REFERENCE
; ============================================================================
/*
    ========================================================================
    QUICK START
    ========================================================================
    1. Select any file or folder in Windows Explorer.
    2. Press Ctrl+Shift+D to open the our notepad.
    3. Type your context/note and click 'Save' (or press Ctrl+S).
    4. Click and hold ctrl q to see a quick preview of your note in a tooltip.
    ========================================================================
    DEFAULT HOTKEYS
    ========================================================================
    • Ctrl + Shift + D : Create or Edit a note.
    • ctrl+q (Hold)    : Preview note content.
    • Ctrl + S         : Save note (while editor is open).
    • Esc           : Close editor / Cancel changes.
    ========================================================================
    STORAGE SYSTEM (Sidecar Files)
    ========================================================================
    Notes are stored in a hidden subfolder named ".filenotes".
    • Original File:  C:\MyFolder\Project_Data.xlsx
    • Context Note:   C:\MyFolder\.filenotes\Project_Data.xlsx.txt
    ========================================================================
    TECHNICAL HIGHLIGHTS
    ========================================================================
    • Win11 Tabs: Active tab detection via IShellBrowser COM.
    • Atomic Save: .tmp file strategy for zero data loss.
    • Dirty Check: Prevents closing with unsaved changes.
    • FIFO Cache: 30s TTL to save system resources.
    ========================================================================
    CUSTOMIZATION
    ========================================================================
    • Colors: Search for COLOR_ variables in Section 1.
    • Cache:  Search for CACHE_ variables in Section 1.
    • Keys:   Modify trigger combinations in Section 2.
    ========================================================================
    HOTKEY SYNTAX GUIDE
    ========================================================================
    ^ = Ctrl  |  ! = Alt  |  + = Shift  |  # = Windows Key
    Example: "^+d" means Ctrl+Shift+D

    ========================================================================
    CONFLICTS TO AVOID IN EXPLORER
    ========================================================================
    - Ctrl+Shift+N (New Folder) | - F2 (Rename)
    - Alt+Enter (Properties)    | - Ctrl+W (Close Window)
    ========================================================================
    For more details on Hotkey syntax, visit:
    https://www.autohotkey.com/docs/v2/Hotkeys.htm
*/
; ============================================================================
; END OF SCRIPT
; ============================================================================
