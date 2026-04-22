# 📂 FileExplorerNotes v2.0
> **"Commit messages" for your local files. Never ask "Why does this file exist?" ever again.**

Easily add descriptions, tags, notes, and context to your files in Windows Explorer. A lightweight, free alternative to organize your digital life and never forget the usefulness of a file or folder. Ideal for those who return to a project weeks later and need to know exactly where they left off and how useful each document or folder is.

---

## 📖 The Story
We've all been there: you open a project folder after three months and see a file named `data_v2_final_revised.db`. You know it's important, but you can't remember exactly what "puzzle piece" it represents. To find out, you have to exhaustively open and read the file, wasting precious time and mental energy.

I tried to solve this in many ways:
- **Manual Lists:** I tried keeping a master list of files inside **Obsidian**, but it was inefficient and hard to maintain as files moved or changed.
- **Paid Tools:** I looked into tools like **TagSpaces**, but found them over-engineered for such a simple need, often hiding basic features behind expensive paywalls.

![Folder filenote](https://imgur.com/DH2p5II.png)

I wanted something that followed the **KISS Principle (Keep It Simple, Stupid)**. I just wanted a note associated with a file that I could read instantly. Since I couldn't find it, I built it.

The code has comments explaining what is happening, and at the end of it there are shortcut customization options, in case you have never dealt with the AHK syntax.

## 🖥️ Independent Native GUI (No Notepad required)

![editor preview](https://imgur.com/eHdS4W9.png)

In version 2.0, I moved away from relying on the Windows Notepad. The modern Windows 11 Notepad has become a "session-based" application with tabs and auto-restore features that often caused conflicts and opened the wrong notes. 

To solve this, I built a **custom, native GUI** directly into the script. This ensures:
- **Total Independence:** No more fighting with Notepad's tabs or session bugs.
- **Pixel-Perfect Design:** A professional Dark Mode interface with internal margins and rounded buttons.
- **Focus & Speed:** The editor is lightweight, instant, and specifically designed for writing file contexts.

## 🤖 Why [AutoHotkey](https://en.wikipedia.org/wiki/AutoHotkey)?
I chose **AutoHotkey (AHK)** for this project for a few key reasons:
1. **Simplicity:** It reduces a massive level of complexity compared to using C# or C++ to achieve the same result in Windows.
2. **Lightweight:** It has a tiny footprint on system resources.
3. **Versatility:** AHK allows me to easily add extra features, like markdown formatting shortcuts, without bloating the software.
4. **Quality:** The reliability and speed of AHK v2 for Windows automation are honestly surprising.

## ✨ Features
- **Instant Context:** Create or edit a note for any file with `Ctrl + Shift + D` using the built-in editor.
- **Quick Preview:** Hold `Ctrl + Q` to see the note in a tooltip without opening the file (chosen for better ergonomics).
- **Sidecar System:** Notes are stored in a hidden `.filenotes` folder within each directory. If you move the folder, the context goes with it.
- **Zero Clutter:** Your filenames remain untouched. No messy prefixes or suffixes.

![File Description Notes](https://imgur.com/T286PT5.png)

## 🛠️ Installation & Setup

Follow these steps to get **FileExplorerNotes** running on your system:

1. **Install AutoHotkey:** Download and install [AutoHotkey v2](https://www.autohotkey.com/).
2. **Create the Script:**
   - Create a new folder anywhere on your PC (e.g., `Documents\Scripts`).
   - Create a new text file, paste the code from `FileExplorerNotes.ahk`, and save it.
3. **Run on Startup (Recommended):**
   - Press `Win + R`, type `shell:startup`, and hit Enter.
   - Right-click your `FileExplorerNotes.ahk` file and select **Create shortcut**.
   - Move that **shortcut** into the Startup folder you just opened.
   - Now, the tool will start automatically every time you turn on your PC.

## ⌨️ Shortcuts (Inside Explorer)
- **`Ctrl + Shift + D`**: Open/Create the note for the selected file in the Native GUI.
- **`Ctrl + Q` (Hold)**: Preview the note content.
- **`Ctrl + Q` (Release)**: Hide the preview.
- **`Ctrl + S`**: Save the note (while the editor is open).
- **`Esc`**: Close the editor / Cancel changes.

*(You can customize these shortcuts, read the end of the script file)*

---

## ⚖️ License
This project is licensed under the **MIT License** - meaning it's free for everyone, forever. 

*Stop guessing. Start committing context to your files.*
