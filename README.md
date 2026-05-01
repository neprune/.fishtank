# .fishtank

For fish shell functionality I want to share across machines, or just not have disappear into oblivion.

This repo is a small set of [fisher](https://github.com/jorgebucaran/fisher) plugins:

- `tank` — manages the rest (capture/use/list/refresh/track/etc.).
- `core`, `git`, `mysoc` — local plugins of fish functions.

`tank` also tracks "external" fisher plugins via the `external_plugins` file so they sync across machines.

## Setup

1. Install [fish shell](https://fishshell.com/).
2. Clone this repository (e.g., `~/.fishtank`).
3. Set the `fish_tank_dir` universal variable and run `tank --init`:

   ```fish
   cd /path/to/this/repo
   set -U fish_tank_dir (pwd)
   source tank/functions/tank.fish && tank init
   ```

`tank init` symlinks `fisher_path.fish` into `~/.config/fish/conf.d/`, installs fisher if missing, and installs the `tank` plugin itself.

If anything looks off, run `tank doctor`.

## Usage

```
tank <command> [args...]
tank --<command> [args...]   (flag form, equivalent)
```

### Lifecycle

- `tank init` — symlink `fisher_path`, install fisher and tank.
- `tank doctor` — diagnose tank's health (env var, symlink, fisher, tank plugin, tracked externals).
- `tank status` — list local plugins (in-use vs not), uncaptured functions, and external plugin tracking state.

### Working with local plugins

- `tank new <plugin>` — scaffold an empty plugin (`<plugin>/functions/`).
- `tank capture <fn> <plugin>` — move `~/.config/fish/functions/<fn>.fish` into `<plugin>/functions/`, fisher-update, commit, push.
- `tank uncapture <fn>` — reverse: move `<fn>` back out of its plugin into `~/.config/fish/functions/`.
- `tank use <plugin|all>` / `tank nouse <plugin>` — install / remove via fisher.
- `tank edit <fn>` — open a captured function in `$EDITOR`.
- `tank where <fn>` — print which plugin owns the function.
- `tank list [plugin]` — list functions and descriptions in in-use plugins.
- `tank refresh` — pull repo, fisher-update in-use plugins, install tracked externals that are missing.

### Working with external fisher plugins

- `tank track <plugin>` — record `<plugin>` (e.g. `jorgebucaran/nvm.fish`) in `external_plugins`.
- `tank drop <plugin>` — stop tracking.
- `tank refresh` — installs anything tracked but missing on this machine.

### Modifiers

- `--no-commit` — skip stash/pull/commit/push for `capture` / `uncapture` / `track` / `drop`.
- `--no-push` — commit but don't push.
- `--dry-run` — show what would happen, don't do it.
- `--local` — for `refresh`, skip git ops (just rerun local fisher updates).
- `-f` / `--force` — for `capture`, overwrite an existing captured copy (the re-capture path).

## `funcsave` reminder

The `tank` plugin ships a `funcsave` wrapper (`tank/functions/funcsave.fish`) that mirrors fish's bundled funcsave but prints a one-line reminder of how to capture the saved function into a tank plugin. Because `alias --save NAME …` calls `funcsave` internally, the same nudge fires there too. Suppress with `funcsave -q`, a custom `-d <dir>`, or `set -U tank_funcsave_quiet 1`.

## A note on `funced` / `funcsave`

`funcsave` writes to `~/.config/fish/functions/<fn>.fish`, which sits ahead of the fisher path on `$fish_function_path`. So if you `funced` a captured function and `funcsave` it, you'll create a *shadow* file that hides the captured copy — your edit appears to work, but the tank source is unchanged and won't sync to other machines.

Two ways to keep edits inside the tank:

- **`tank edit <fn>`** — opens the captured source file directly. After the editor exits, tank drops fish's cached function parse, re-runs `fisher update` for the owning plugin, and re-sources the file so the current shell sees the new version immediately.
- **`tank capture --force <fn> <plugin>`** — promotes a `~/.config/fish/functions/<fn>.fish` shadow back into the tank, overwriting the captured copy. Use this if you've already edited via `funced`.

## Example: capture round-trip

```fish
# 1. Define a function in the usual fish location.
function hi --description 'say hi'
    echo "hi $USER"
end
funcsave hi

# 2. Move it into the 'core' plugin (commits + pushes by default).
tank capture hi core

# 3. Edit it later.
tank edit hi

# 4. Pull it back out if you'd rather not version it.
tank uncapture hi
```

## Removal

`fisher remove <local plugin>` works.

`fisher list | fisher remove` goes nuclear and removes all plugins and `fisher` itself.
