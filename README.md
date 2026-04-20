# 📂 FileExplorerNotes
> **"Commit messages" for your local files. Never ask "Why does this file exist?" ever again.**

Easily add descriptions, tags, notes, and context to your files in Windows Explorer. A lightweight, free alternative to organize your digital life and never forget the usefulness of a file or folder. Ideal for those who return to a project weeks later and need to know exactly where they left off and how useful each document or folder is.

---

## 📖 The Story
We've all been there: you open a project folder after three months and see a file named `data_v2_final_revised.db`. You know it's important, but you can't remember exactly what "puzzle piece" it represents. To find out, you have to exhaustively open and read the file, wasting precious time and mental energy.

I tried to solve this in many ways:
- **Manual Lists:** I tried keeping a master list of files inside **Obsidian**, but it was inefficient and hard to maintain as files moved or changed.
- **Paid Tools:** I looked into tools like **TagSpaces**, but found them over-engineered for such a simple need, often hiding basic features behind expensive paywalls.

I wanted something that followed the **KISS Principle (Keep It Simple, Stupid)**. I just wanted a note associated with a file that I could read instantly. Since I couldn't find it, I built it.

The code has comments explaining what is happening, and at the end of it there are shortcut customization options, in case you have never dealt with the AHK syntax

## 🤖 Why [AutoHotkey](https://en.wikipedia.org/wiki/AutoHotkey)?
I chose **AutoHotkey (AHK)** for this project for a few key reasons:
1. **Simplicity:** It reduces a massive level of complexity compared to using C# or C++ to achieve the same result in Windows.
2. **Lightweight:** It has a tiny footprint on system resources.
3. **Versatility:** AHK allows me to easily add extra features, like markdown formatting shortcuts, without bloating the software.
4. **Quality:** The reliability and speed of AHK v2 for Windows automation are honestly surprising.

## ✨ Features
- **Instant Context:** Create or edit a note for any file with `Ctrl + Shift + D`.
- **Quick Preview:** Hold `F7` to see the note in a tooltip without opening the file.
- **Sidecar System:** Notes are stored in a hidden `.filenotes` folder within each directory. If you move the folder, the context goes with it.
- **Zero Clutter:** Your filenames remain untouched. No messy prefixes or suffixes.

## 🛠️ Installation & Setup

Follow these steps to get **FileExplorerNotes** running on your system:

1. **Install AutoHotkey:** Download and install [AutoHotkey v2](https://www.autohotkey.com/).
2. **Create the Script:**
   - Create a new folder anywhere on your PC (e.g., `Documents\Scripts`).
   - Create a new text file, paste the code from `FileExplorerNotes.ahk`, and save it.
3. **Run on Startup:**
   - Press `Win + R`, type `shell:startup`, and hit Enter.
   - Create a **shortcut** of your `.ahk` file and paste it into this folder.
   - Now, the tool will be ready every time you start Windows.

## ⌨️ Shortcuts (Inside Explorer)
- **`Ctrl + Shift + D`**: Open/Create the note for the selected file in Notepad.
- **`F7` (Hold)**: Preview the note content.
- **`F7` (Release)**: Hide the preview.
(You can customize the shortcuts)
---

## ⚖️ License
This project is licensed under the **MIT License** - meaning it's free for everyone, forever. 

*Stop guessing. Start committing context to your files.*
