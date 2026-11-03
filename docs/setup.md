# Setup (Windows)
To build and run the project you need:

- Python 3
- LÖVE 11.5
- Aseprite
- Tiled (maybe?)

This document describes how to install each tool and also how to launch the
game.

## Installing the requirements
### Python 3
First, check if you already have Python 3 installed. To do so, press WIN+R,
type `cmd`, and then press ENTER. In the command prompt window, type `python`
and then press ENTER. This should open the Python REPL; if an error message 
pops up instead, then you do not have Python installed.

To install Python 3, download and run the installer from here:
https://www.python.org/downloads/ (or you can download it from the Microsoft
Store). **IMPORTANT!** When setting up the installation, make sure to check the
"Add python.exe to PATH" option.

### LÖVE
Provided in the tools folder is a ZIP of a custom patch[^1] of LÖVE 11.5. First,
create a folder named "love" in the project root directory (next to CREDITS.txt
and LICENSE). Place the unzipped contents of love_l52.zip inside the
aforementioned "love" folder, ensuring that there are no subfolders. **It is
important that it is done exactly this way**. This is because the game launcher
helper script (described later) will look for this file.

You may also download LOVE from their website: https://love2d.org/. However, I
already have a helper script in this repo to run LOVE given that you followed
the above instructions, so, unless you already have LOVE on your system, it is
easier to follow those instructions.

### Aseprite
I'm assuming you already have Aseprite.

### Tiled
(Skip this section, unless you plan on doing level editing.)

If we decide to need levels for this game, we will most likely make levels using
Tiled. It can be installed from here: https://thorbjorn.itch.io/tiled. The
installer downloadable from that page should install Tiled into the standard
location (`C:\Program Files\Tiled\tiled.exe`). If it doesn't, then the asset
exporter script will not work.

## Running the game launcher helper script
In order to run the game, you can run the game launcher helper script from a
PowerShell prompt. But first know that each PowerShell (or Command Prompt[^2])
session keeps track of a "current working directory". The current working
directory is displayed at the beginning of each command prompt line in the
PowerShell terminal. Using File Explorer as a metaphor, the CWD is basically the
current open folder. Double-clicking on a folder named "my-folder" in File
Explorer changes the current open folder to that folder; typing `cd my-folder`
in PowerShell semantically does the same action.

There are two ways to open PowerShell with the session's current directory set
to the project root:
1. Open the project folder in File Explorer. Click on an empty spot in the
   location bar to begin typing into it. Type `powershell` and press ENTER.
2. Press WIN+R and type in `powershell` to open a new PowerShell window with the
   current directory set to your user folder. Then, to properly set the current
   directory, type:
   ```powershell
   cd 'C:\Path\To\Project\Dir'
   ```
   (`cd` stands for "change directory"; the given path above is an example)

The game launcher helper cmdlet (`tools/run.ps1`) runs the asset
exporter/pre-processor before launching the game. But before running it, you
need to let the asset exporter know where `aseprite.exe` is located. This is
because it uses the Aseprite command-line interface for automated spritesheet
exports, and the location of the executable is different depending on how/where
you installed it (e.g. Steam vs. non-Steam installation vs. compiled from
source).

There are two ways to do let the asset exporter know the location of
`aseprite.exe`:
### 1. Modify the system PATH environment variable
The PATH variable is a system-wide variable containing a list of directories
that Command Prompt or PowerShell uses to resolve command names to executables.
For example, if you wrote `python tools\assetexport.py`, the shell looks through
each folder specified in PATH for a file named "python.exe", and runs that
executable with the given command arguments. (And then, for a program--in this
case, the asset exporter script--to launch another executable, it must do so
through Command Prompt.)

To add the Aseprite folder to this variable:
1. Open the Windows start menu and search for and open "Edit the system
   environment variables".
2. This will open you to the "Advanced" tab of System Properties. Press the
   "Environment Variables..." button on the bottom-right.
3. In the new window that opens, locate and click the entry for "Path" in the
   "System Variables" list. After it has been selected, click the "Edit" button
   located on the bottom-right.
4. This opens a new window of a list containing the entries of the PATH
   variable. Make sure you have the path to the folder containing aseprite.exe
   in your clipboard. Press the "New" button located on the right, paste the
   path, and then press ENTER.
5. Press "OK" for each window until every window has been closed.

### 2. Set a session environment variable
In your PowerShell session, type out this command, replacing the given path with
your path to aseprite.exe:
```powershell
$env:ASEPRITE = "C:\Program Files\Aseprite\aseprite.exe"
```
Then, press ENTER. The asset export script will read this environment variable
to determine the location of Aseprite. The caveat of this method is that you
must do this every time you make a new PowerShell session.

### Execute the launcher cmdlet
Afterwards, to run the launcher cmdlet you simply type:
```powershell
powershell -ExecutionPolicy Bypass -File tools\run.ps1
```
By default, Windows disables running cmdlets downloaded from the Internet for
security reasons. The `-ExecutionPolicy Bypass` part is to force it to run the
cmdlet regardless. There is a way to disable it, so that you only need to type
`tools\run.ps1` to run the cmdlet, but I'm too lazy to figure out how.

----

[^1]: The only thing I changed in my custom patch of LOVE is the Lua
(programming language) version: my version uses Lua 5.2, whereas the official
builds use LuaJIT. This is for better parity with the web build: LuaJIT
cannot run on the web, so Lua 5.2 is the closest that we can get. The game is
programmed so that the difference in Lua version does not matter.

[^2]: Sidenote: Windows has two shells: Command Prompt and PowerShell. Command
Prompt is integrated into the operating system. PowerShell is a newer shell
that, while being a pre-installed component of Windows by default, is not
actually part of the OS: you could remove it and Windows would function just
fine. But PowerShell exists to be more easy to learn (i think?) and more
powerful than Command Prompt. Command Prompt and PowerShell commands are
generally not compatible with each other, so this guide needs to pick one. I
picked PowerShell.