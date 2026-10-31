# Railroader mod build watcher

Runs in the background from logon (windowless, via `conhost --headless`; the task re-starts it every 5 minutes if it was killed). Every 5 seconds it checks, for each watched mod, whether `<Mod>-<ver>-source.zip`
in `Desktop\Projects` or `Downloads` has a version newer than that mod's repo.

Watched mods: `AutoEngineerBrakeFix` and `TrackRepair` (`-Mods` in `Watch-Builds.ps1`). For each mod:
- the repo is `Desktop\Projects\<Mod>` (a git repo on `main`);
- the project file is `<Mod>.csproj`;
- it deploys to `Documents\Railroader\ModDev\<Mod>`.

To add a mod, import its first version by hand into `Desktop\Projects\<Mod>`, add the name to `-Mods` and restart
the task.

When it finds a newer zip, it:

1. Waits until the download has finished, then checks the zip.
   - The files may sit either inside a `<Mod>/` folder or at the top level of the zip, but not both, and no deeper.
   - Only `.cs`, `.md`, `Info.json`, the `.csproj` and `.gitignore` are allowed.
   - `Info.json` must match the version in the file name.
2. Refuses to build if the `.csproj` changed beyond the version number, and tells you to review it.
3. Imports the zip into the repo as a commit (`Import v<ver> source`) and builds it. Files the zip leaves out are
   deleted, except `.gitignore` and `CLAUDE.md`.
4. **If it builds cleanly:** pushes to GitHub and deploys to the game. Claude is not involved and it costs nothing.
   - A repo with no `origin` remote is committed and deployed but not pushed. You get one notification about it.
5. **If it fails to build:** starts Claude Code (Sonnet, headless). That session can only read files, edit `.cs`
   files and run `dotnet build`. Afterwards the script checks that only existing `.cs` files changed, and rebuilds
   itself.
   - Fixed: the fix is pushed as its own commit (`Fix compile errors in v<ver> (automatic)`), so Claude desktop
     sees the exact diff. Then it deploys.
   - Not fixed: `main` stays on the previous version and the import goes to the `incoming/v<ver>` branch. A GitHub
     issue lists the errors and Claude's explanation.

It builds for the game's own mod loader only: Railroader 0.6.0+, using `Railroader.dll` and
`Railroader.Modding.dll`. Harmony ships with each mod, and nothing uses Unity Mod Manager. Use `-ModsDir` to deploy
somewhere else (e.g. `...\Railroader\Mods`) and `-GameDir` for another install.

It waits instead of acting when:
- Railroader is running (this only delays the deploy);
- the repo has uncommitted changes;
- the game's `Railroader.dll` or `Railroader.Modding.dll` is missing.

Every step shows a Windows notification.

Old zips: after each successful import, and once per mod when the watcher starts, source zips older than the repo's
version are moved to the Recycle Bin from `Desktop\Projects` and `Downloads`, but only if some commit on `main` has
that version in its `Info.json` (so it is already in the repo and on GitHub). The current version's zip, any zip
that was rejected or failed to build, and zips of versions that were never committed (from before the repo existed,
or folded into a later import) are kept.

## Files
- `Watch-Builds.ps1`: the watcher.
- `Install-Task.ps1`: registers it as a logon task that also repeats every 5 minutes (a running watcher makes the extra starts exit at once). `Install-Task.ps1 -Remove` removes it.
- `watcher.log`: what it did, including build errors and Claude's reports.
- `state.json`:
  - zips already handled (by hash), so a failed zip is not retried. Delete an entry to retry it.
  - mods waiting to be deployed.

## Commands
- Stop it: `Stop-ScheduledTask 'AutoEngineerBrakeFix Build Watcher'`
- Start it: `Start-ScheduledTask 'AutoEngineerBrakeFix Build Watcher'`
