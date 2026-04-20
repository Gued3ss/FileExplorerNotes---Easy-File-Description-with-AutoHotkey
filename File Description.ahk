;============================================================
; Script Name : ExplorerNotes
; Author      : Gued3s
; Version     : 1.0.
; Date        : 2026-04-20
; Description : Context-aware file description system for Windows Explorer
;               Allows quick note creation and preview for any file
;               without cluttering the file system.
; 
; Features:
;   - Create/edit file descriptions (Ctrl+Shift+D)
;   - Quick preview descriptions (Ctrl+I)
;   - Hidden .context folder per directory
;   - LRU cache with 30-second TTL
;   - 100ms polling for responsive UI
;   - Easily customizable hotkeys
;
; Scope:
;   - Lightweight, single-file solution
;   - Windows Explorer integration only
;   - No external dependencies
;   - Minimal CPU/memory footprint
;   - UX-focused (no complex features)
;============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

;============================================================
; ⚙️  CONFIGURATION - CUSTOMIZE HOTKEYS HERE
;
; Change the values below to customize your hotkeys.
; The script will automatically use these settings.
;
; Format Examples:
;   "^+d"  = Ctrl+Shift+D
;   "^i"   = Ctrl+I
;   "!d"   = Alt+D
;   "F7"   = F7 key
;
; See HOTKEY GUIDE section at the end for more examples.
;============================================================

global CONFIG := {
    HOTKEY_CREATE: "^+d",           ; Create/Edit note
    HOTKEY_PREVIEW: "^i",           ; Preview note
    CACHE_MAX_SIZE: 50,             ; Max cached notes in memory
    CACHE_MAX_AGE: 30000,           ; Cache TTL: 30 seconds (milliseconds)
    PREVIEW_POLL_MS: 100            ; Preview polling interval: 100ms
}

;============================================================
; CLEANUP HANDLER
; Ensures tooltip is cleared when script exits, preventing
; visual artifacts in the system.
;============================================================
OnExit((*) => ToolTip())

;============================================================
; GLOBAL STATE
; PreviewState: Tracks active preview session and current file
; NoteCache:    In-memory LRU cache for file descriptions
;============================================================
global PreviewState := Map(
    "Active", false,        ; Is preview active?
    "LastPath", ""          ; Last focused file path
)

global NoteCache := Map()

;============================================================
; HOTKEY REGISTRATION
; All hotkeys are registered here and limited to Explorer context
; via the #HotIf directive below.
;============================================================

#HotIf WinActive("ahk_class CabinetWClass ahk_exe explorer.exe")

; Register Create/Edit hotkey dynamically
Hotkey(CONFIG.HOTKEY_CREATE, HotkeyCreate_Handler)

; Register Preview hotkey dynamically
Hotkey(CONFIG.HOTKEY_PREVIEW, HotkeyPreview_Handler)
Hotkey(CONFIG.HOTKEY_PREVIEW " Up", HotkeyPreview_Stop)

#HotIf  ; End Explorer-specific context

;============================================================
; HOTKEY HANDLER: Create/Edit Description
; 
; Opens Notepad to edit/create a description file for the
; currently selected file in Explorer.
;============================================================
HotkeyCreate_Handler(HotkeyName) {
    shellWin := Explorer_GetShellWindowFromActiveHwnd()
    if !shellWin
        return

    ; Step 1: Extract first selected file path
    targetPath := ""
    try {
        for item in shellWin.Document.SelectedItems {
            targetPath := item.Path
            break  ; Only process first selected item
        }
    }
    
    ; Step 2: Validate path
    if (targetPath = "" || InStr(targetPath, "\.context\"))
        return

    ; Step 3: Build paths for note file
    SplitPath(targetPath, &fileName, &fileDir)
    metaDir := fileDir "\.context"
    notePath := metaDir "\" fileName ".txt"

    ; Step 4: Create hidden metadata folder if needed
    if !DirExist(metaDir) {
        try {
            DirCreate(metaDir)
            FileSetAttrib("+H", metaDir)
        } catch {
            return  ; Silent fail if permission denied
        }
    }

    ; Step 5: Open note in Notepad for editing
    try {
        Run('notepad.exe "' notePath '"')
    }
}

;============================================================
; HOTKEY HANDLER: Preview Start
; 
; Activates the preview polling when preview hotkey is pressed.
;============================================================
HotkeyPreview_Handler(HotkeyName) {
    global PreviewState
    
    if PreviewState["Active"]
        return
    
    PreviewState["Active"] := true
    SetTimer(Preview_Tick, CONFIG.PREVIEW_POLL_MS)
    Preview_Tick()  ; Immediate feedback on key press
}

;============================================================
; HOTKEY HANDLER: Preview Stop
; 
; Deactivates preview and clears tooltip when preview key is released.
;============================================================
HotkeyPreview_Stop(HotkeyName) {
    global PreviewState
    
    PreviewState["Active"] := false
    PreviewState["LastPath"] := ""
    SetTimer(Preview_Tick, 0)  ; Stop polling timer
    ToolTip()  ; Clear tooltip immediately
}

;============================================================
; FUNCTION: Preview_Tick
; 
; Core polling loop executed every N ms while preview hotkey is held.
; 
; Flow:
;   1. Verify preview is still active and Explorer is focused
;   2. Get currently focused/selected file from Explorer
;   3. Check if file changed since last tick
;   4. If changed: check cache, or read from disk
;   5. Display tooltip with file description
;
; Performance:
;   - ~2-5ms execution time per tick (negligible overhead)
;   - Only reads disk when file actually changes
;   - LRU cache prevents repeated disk I/O for same files
;============================================================
Preview_Tick() {
    global PreviewState, NoteCache, CONFIG

    ; Guard clause: Exit if preview was stopped
    if !PreviewState["Active"]
        return

    ; Guard clause: Exit if preview hotkey released or Explorer not focused
    if !WinActive("ahk_class CabinetWClass ahk_exe explorer.exe") {
        HotkeyPreview_Stop()
        return
    }

    ; Get Explorer COM object for current window
    shellWin := Explorer_GetShellWindowFromActiveHwnd()
    if !shellWin {
        ToolTip()
        return
    }

    ; Extract currently focused/selected file
    focusedPath := ""
    try {
        focusedItem := shellWin.Document.FocusedItem
        if focusedItem
            focusedPath := focusedItem.Path
    }

    if (focusedPath = "") {
        ToolTip()
        return
    }

    ; Build description file path
    SplitPath(focusedPath, &fileName, &fileDir)
    notePath := fileDir "\.context\" fileName ".txt"

    ; Only process if focused file changed (optimization to reduce I/O)
    ; This prevents unnecessary disk reads when user navigates with arrow keys
    if (notePath != PreviewState["LastPath"]) {
        PreviewState["LastPath"] := notePath

        if FileExist(notePath) {
            contentToDisplay := ""
            currentFileTime := ""
            
            ; Get file modification time for cache validation
            try currentFileTime := FileGetTime(notePath, "M")

            ; ===== CACHE LOOKUP =====
            ; Check if description is in memory cache
            if NoteCache.Has(notePath) {
                cachedData := NoteCache[notePath]
                
                ; Cache is valid only if:
                ; 1) File hasn't been modified since cache entry
                ; 2) Cache entry hasn't exceeded TTL (30 seconds)
                if (currentFileTime == cachedData.FileTime && 
                    (A_TickCount - cachedData.AccessTime) < CONFIG.CACHE_MAX_AGE) {
                    contentToDisplay := cachedData.Content
                    cachedData.AccessTime := A_TickCount  ; Update LRU timestamp
                } else {
                    NoteCache.Delete(notePath)  ; Invalidate stale cache entry
                }
            }

            ; ===== DISK READ (if needed) =====
            ; Only read from disk if cache miss or validation failed
            if (contentToDisplay = "") {
                try {
                    ; Read max 4000 chars to prevent massive tooltips
                    contentToDisplay := FileRead(notePath, "m4000 UTF-8")
                    
                    if (contentToDisplay != "") {
                        ; ===== CACHE STORE & LRU EVICTION =====
                        ; Store in cache with metadata for validation
                        NoteCache[notePath] := {
                            Content: contentToDisplay, 
                            AccessTime: A_TickCount,      ; For LRU tracking
                            FileTime: currentFileTime      ; For invalidation
                        }
                        
                        ; LRU Eviction: If cache exceeds max size,
                        ; remove entry with oldest AccessTime (least recently used)
                        if (NoteCache.Count > CONFIG.CACHE_MAX_SIZE) {
                            oldestKey := ""
                            oldestTime := A_TickCount
                            
                            ; Find entry with minimum AccessTime
                            for key, data in NoteCache {
                                if (data.AccessTime < oldestTime) {
                                    oldestTime := data.AccessTime
                                    oldestKey := key
                                }
                            }
                            
                            if (oldestKey != "")
                                NoteCache.Delete(oldestKey)
                        }
                    }
                } catch {
                    contentToDisplay := ""
                }
            }
            
            ; Display tooltip or show status message
            if (contentToDisplay != "")
                ToolTip(contentToDisplay)
            else
                ToolTip("(Empty description)")
                
        } else {
            ToolTip("(No description)")
        }
    }
}

;============================================================
; FUNCTION: Explorer_GetShellWindowFromActiveHwnd
; 
; Purpose:
;   Retrieve COM object for the active Explorer window
;   This allows us to query selected files, focused items, etc.
;
; Returns:
;   COM object (Shell.Application.Windows item) or 0 on failure
;
; Notes:
;   - Iterates through all open Shell windows (fast, usually < 5 items)
;   - Returns immediately on first match
;   - Handles COM exceptions gracefully
;============================================================
Explorer_GetShellWindowFromActiveHwnd() {
    hwnd := WinExist("A")
    if !hwnd
        return 0

    try {
        for w in ComObject("Shell.Application").Windows {
            if (w.hwnd = hwnd)
                return w  ; Found matching Explorer window
        }
    } catch {
        return 0  ; Silent fail if COM access fails
    }
    return 0  ; No matching window found
}

;============================================================
; HOTKEY CUSTOMIZATION GUIDE
;
; Edit the CONFIG section at the top to change hotkeys.
; Below are recommended alternatives and examples.
;
; RECOMMENDED HOTKEYS:
; ────────────────────────────────────────────────────────
;
; CREATE/EDIT Description (Top 5):
;   1. ^+d    = Ctrl+Shift+D  (DEFAULT - D for Description)
;   2. ^+o    = Ctrl+Shift+O  (Alternative - O for Open)
;   3. ^+m    = Ctrl+Shift+M  (Alternative - M for Memo)
;   4. ^+n    = Ctrl+Shift+N  (Note: conflicts with "New Folder")
;   5. F2     = F2 key        (Note: conflicts with "Rename")
;
; PREVIEW Description (Top 5):
;   1. ^i     = Ctrl+I        (DEFAULT - I for Info)
;   2. ^q     = Ctrl+Q        (Alternative - Q for Query)
;   3. F7     = F7 key        (Alternative - single key)
;   4. F8     = F8 key        (Alternative - single key)
;   5. !i     = Alt+I         (Alternative - Alt+Info)
;
; ────────────────────────────────────────────────────────
; HOTKEY SYNTAX:
;
;   ^  = Ctrl
;   !  = Alt
;   +  = Shift
;   #  = Windows key
;
; Examples:
;   "^+d"   = Ctrl+Shift+D
;   "!f7"   = Alt+F7
;   "#n"    = Windows+N
;   "F7"    = F7 key (no modifiers)
;
; CONFLICTS TO AVOID in Explorer:
;   - Ctrl+Shift+N    (New Folder)
;   - Ctrl+Shift+E    (Expand navigation pane)
;   - Ctrl+D          (Delete)
;   - F2              (Rename)
;   - F3              (Search)
;   - Alt+Enter       (Properties)
;   - Alt+P           (Preview pane)
;   - Ctrl+W          (Close window)
;   - Ctrl+N          (New window)
;
; ────────────────────────────────────────────────────────
; EXAMPLES TO PASTE:
;
; Use Alt+D for create, Alt+W for preview:
;   CONFIG.HOTKEY_CREATE := "!d"
;   CONFIG.HOTKEY_PREVIEW := "!w"
;
; Use F2 for create, F3 for preview:
;   CONFIG.HOTKEY_CREATE := "F2"
;   CONFIG.HOTKEY_PREVIEW := "F3"
;
; Use Windows key combinations:
;   CONFIG.HOTKEY_CREATE := "#n"
;   CONFIG.HOTKEY_PREVIEW := "#m"
;
; ────────────────────────────────────────────────────────
; For full hotkey syntax documentation, see:
; https://www.autohotkey.com/docs/v2/Hotkeys.htm
;
;============================================================

;============================================================
; END OF SCRIPT
;============================================================