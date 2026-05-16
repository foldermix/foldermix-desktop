# foldermix desktop

Native macOS wrapper for the `foldermix` CLI.

## v0 scope

- Select a folder to pack.
- Preview included and skipped files with `foldermix list` and `foldermix skiplist --conversion-check`.
- Check or uncheck detected file extensions, or add an extension manually.
- Change the output path and format.
- Run `foldermix pack` and view command output in a terminal-style log pane.

The app shells out to an installed `foldermix` CLI. For local testing it searches common pyenv and Homebrew paths before running commands.

## Build a local DMG

```bash
./scripts/build_dmg.sh 0.0.0
```

The DMG is written to `build/foldermix-v0.0.0.dmg`.
