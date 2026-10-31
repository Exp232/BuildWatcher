# Mod Build Watcher

A Windows background script for authors of C# game mods who get new versions of their mod's source as zip files (for
example from an AI chat). It is set up for [Railroader](https://store.steampowered.com/app/1683150/Railroader/) out
of the box, and works for other games built with `dotnet build` through the [`Game`](#another-game) setting. Drop
`<Mod>-<version>-source.zip` into a watched folder and it:

1. checks the zip,
2. imports it into the mod's git repo as a commit,
3. builds it against your game install,
4. pushes it to GitHub and copies the built mod into the game.

If the build fails and [Claude Code](https://claude.com/claude-code) is installed, a headless Claude Code session is
allowed to try a minimal compile fix, which the script then checks for itself. Everything else runs without AI and
costs nothing.

## Requirements

- Windows 10 or 11 with Windows PowerShell 5.1 (built in).
- [Git for Windows](https://git-scm.com/download/win) and the [.NET SDK](https://dotnet.microsoft.com/download).
- For Railroader: version 0.6.0 or newer (the game's built-in mod loader).
- Optional: [GitHub CLI](https://cli.github.com/) (`gh`), signed in, to open an issue when a build can't be fixed.
- Optional: [Claude Code](https://claude.com/claude-code), signed in, for automatic compile fixes.

## Your mod's repo

Each mod lives in `<ProjectsDir>\<Mod>`. It must be:

- a git repo on branch `main`, with its first version committed by hand;
- built by `<Mod>.csproj`, with a version file next to it: for Railroader, an `Info.json` that has a `"version"`
  field (the game's mod format), otherwise whatever `Game.VersionFile` and `Game.VersionField` name;
- optionally pushed to an `origin` remote. Without one, commits stay local.

The watcher builds with:

```
dotnet build -c Release -nologo /p:RailroaderDir=<GameDir> /p:ModsDir=<ModsDir> [/p:DeployToGame=false]
```

(for another game, `RailroaderDir` is `Game.DirProperty`, `GameDir` by default), so the csproj should reference the
game's DLLs through that property and copy the built mod and its version file into `$(ModsDir)\<Mod>` after the build
unless `DeployToGame` is `false`. The watcher checks the deploy by reading the version file there. For Railroader:

```xml
<PropertyGroup>
  <RailroaderDir Condition="'$(RailroaderDir)' == ''">C:\Program Files (x86)\Steam\steamapps\common\Railroader</RailroaderDir>
  <ManagedDir>$(RailroaderDir)\Railroader_Data\Managed</ManagedDir>
  <ModsDir Condition="'$(ModsDir)' == ''">$([System.Environment]::GetFolderPath(SpecialFolder.MyDocuments))\Railroader\Mods</ModsDir>
</PropertyGroup>
<ItemGroup>
  <Reference Include="$(ManagedDir)\Railroader.dll" Private="false" />
  <Reference Include="$(ManagedDir)\Railroader.Modding.dll" Private="false" />
  <Reference Include="$(ManagedDir)\UnityEngine.CoreModule.dll" Private="false" />
</ItemGroup>
<Target Name="DeployToGame" AfterTargets="Build" Condition="'$(DeployToGame)' != 'false'">
  <Copy SourceFiles="$(OutDir)MyMod.dll;Info.json" DestinationFolder="$(ModsDir)\MyMod" />
</Target>
```

## Setup

1. Clone or download this repo anywhere.
2. Copy `config.example.json` to `config.json` and edit it (see below).
3. Run `powershell -ExecutionPolicy Bypass -File Install-Task.ps1`.

`Install-Task.ps1` registers a scheduled task, **Mod Build Watcher**, that starts the watcher at logon with no
window and starts it again every 5 minutes if it was stopped. A running watcher makes the extra starts exit at once.
It replaces the **Railroader Build Watcher** task that older versions registered.
After you change `config.json` or update the script, restart it (see [Commands](#commands)).

### config.json

Every setting is optional except `Mods`. Paths may use environment variables such as `%USERPROFILE%`. In JSON,
backslashes must be doubled: `"C:\\Games\\Railroader"`.

| Key | Default | Meaning |
| --- | --- | --- |
| `Mods` | none | Names of the mods to watch. Each one is a folder in `ProjectsDir`, a `<Mod>.csproj` and a zip prefix. |
| `ProjectsDir` | `Desktop\Projects` | Folder that holds the mod repos. |
| `WatchDirs` | `Desktop\Projects`, `Downloads` | Folders searched for zips. |
| `Game` | Railroader | The game the mods are for. See [Another game](#another-game). |
| `GameDir` | `Game.Dir` | The game install that the mod is compiled against. |
| `ModsDir` | `Game.ModsDir` | Where the built mod is deployed, into `<ModsDir>\<Mod>`. See below. |
| `ClaudeModel` | `sonnet` | Model for the automatic compile fix. |

The same names, except `Game`, work as command-line parameters of `Watch-Builds.ps1` and override `config.json`.
`GameDir` and `ModsDir` also override `Game.Dir` and `Game.ModsDir`.

**Where mods are deployed.** Railroader loads installed mods from `<home>\Mods`, where home is `Documents\Railroader`,
or the folder given with `-homedir` in the game's Steam launch options
([Installing Mods](https://docs.railroadergame.com/modding/installing-mods/),
[Command Line Arguments](https://docs.railroadergame.com/support/command-line-arguments/)). By default the watcher
works this out the same way: it reads `-homedir` from Steam's launch options for Railroader if there is one, and
otherwise uses `Documents\Railroader`. To deploy into the game's development folder (`<home>\ModDev`) instead, or
anywhere else, set `ModsDir`, for example `"ModsDir": "%USERPROFILE%\\Documents\\Railroader\\ModDev"`.

### Another game

`Game` describes the game. Without it, or with `"Name": "Railroader"`, the Railroader settings apply, and any key you
set overrides one of them. With any other name, every key starts from the generic default, and `Dir` and `ModsDir`
must be set. For example, for a game whose mods have a Thunderstore-style `manifest.json`:

```json
{
    "Mods": [ "MyMod" ],
    "Game": {
        "Name": "Some Game",
        "Dir": "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Some Game",
        "Process": "SomeGame",
        "RequiredFiles": [ "SomeGame_Data\\Managed\\Assembly-CSharp.dll" ],
        "ModsDir": "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Some Game\\BepInEx\\plugins",
        "VersionFile": "manifest.json",
        "VersionField": "version_number"
    }
}
```

| Key | Railroader | Generic default | Meaning |
| --- | --- | --- | --- |
| `Name` | `Railroader` | | Shown in notifications. |
| `Dir` | Steam's default Railroader folder | none | The game install. |
| `DirProperty` | `RailroaderDir` | `GameDir` | MSBuild property the game folder is passed in. |
| `Process` | `Railroader` | none | Process name. While it runs, deploys wait (the game locks the DLL). None: never wait. |
| `RequiredFiles` | `Railroader.dll`, `Railroader.Modding.dll` in `Railroader_Data\Managed` | none | Files, relative to `Dir`, without which nothing compiles. While one is missing, builds wait. |
| `ModsDir` | `<Railroader home>\Mods` | none | Where mods are deployed. |
| `VersionFile` | `Info.json` | `Info.json` | JSON file in the mod's folder that holds its version. |
| `VersionField` | `Version` | `Version` | Field in that file with the version (`x.y.z`). Not case-sensitive. |

## What it does with a new zip

Every 5 seconds it looks, for each mod, for `<Mod>-<x.y.z>-source.zip` in the watched folders with a version newer
than the one committed in the mod's repo. It then:

1. Waits until the download has finished, then checks the zip.
   - The files may sit either inside a `<Mod>/` folder or at the top level of the zip, but not both, and no deeper.
   - Only `.cs`, `.md`, the version file (`Info.json`), `<Mod>.csproj` and `.gitignore` are allowed, up to 5 MB in
     total.
   - The version file and `<Mod>.csproj` must be present, and the version file must match the version in the zip's
     name.
2. Refuses to build if the `.csproj` changed beyond the version number, and tells you to review it. The csproj
   decides what the build runs, so it is never taken from a zip unseen.
3. Imports the zip as a commit (`Import v<ver> source`) and builds it. Files the zip leaves out are deleted from the
   repo, except `.gitignore` and `CLAUDE.md`. If `CHANGELOG.md` has `## x.y.z` headings for skipped versions, the
   commit message lists them.
4. **If it builds cleanly:** pushes to GitHub and deploys to the game.
5. **If it fails to build:** starts Claude Code headless. That session may only read files, edit `.cs` files and run
   `dotnet build`. Afterwards the script checks that only existing `.cs` files changed, and builds again itself.
   - Fixed: the fix is pushed as its own commit (`Fix compile errors in v<ver> (automatic)`), then it deploys.
   - Not fixed (or Claude Code not installed): `main` stays on the previous version, the import goes to the
     `incoming/v<ver>` branch, and a GitHub issue lists the errors and Claude's explanation.

It waits instead of acting when:
- the game is running (`Game.Process`; this only delays the deploy, since the game locks the DLL);
- the repo has uncommitted changes or is not on `main`;
- one of the game's `Game.RequiredFiles` is missing, for Railroader `Railroader.dll` or `Railroader.Modding.dll`
  (for example during a Steam update).

Every step shows a Windows notification.

**Old zips:** after each successful import, and once per mod when the watcher starts, source zips older than the
repo's version are moved to the Recycle Bin, but only if some commit on `main` has that version in its version file.
The current version's zip, any zip that was rejected or failed to build, and zips of versions that were never
committed (from before the repo existed, or folded into a later import) are kept.

## Files

- `Watch-Builds.ps1`: the watcher.
- `Install-Task.ps1`: registers the scheduled task. `Install-Task.ps1 -Remove` removes it.
- `config.example.json`: a starting point for `config.json`.
- Created when it runs, and ignored by git:
  - `config.json`: your settings.
  - `watcher.log`: what it did, including build errors and Claude's reports.
  - `state.json`: zips already handled (by hash), so a failed zip is not retried (delete its entry to retry it),
    notifications already shown, and mods waiting to be deployed.
  - `work\`: zips being checked.

## Commands

- Stop it: `Stop-ScheduledTask 'Mod Build Watcher'`, then end the `powershell.exe` running `Watch-Builds.ps1`
  in Task Manager if it is still there.
- Start it: `Start-ScheduledTask 'Mod Build Watcher'`
- Try a change for a few polls next to the running watcher, without deploying or opening issues:
  `powershell -File Watch-Builds.ps1 -StateDir <empty folder> -Ticks 3 -NoDeploy -NoIssue`.
  It still imports, commits and pushes any new zip it finds, so point `-ProjectsDir` and `-WatchDirs` at test
  copies if that matters.

## License

MIT. See [LICENSE](LICENSE).
