# .fishtank

For fish shell functionality I want to share across machines, or just not have disappear into oblivion.

This repo is a small set of [fisher](https://github.com/jorgebucaran/fisher) plugins:

- `tank` — manages the rest (capture/use/list/refresh/track/etc.).
- `core`, `git`, `mysoc` — local plugins of fish functions.

`tank` also tracks "external" fisher plugins via the `external_plugins` file so they sync across machines.

## Setup

1. Install [fish shell](https://fishshell.com/).
2. Clone this repository (e.g., `~/.fishtank`).
3. Set the `fish_tank_dir` universal variable and run `tank init`:

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

## Editing functions: just use `tank edit`

`tank edit <fn>` (alias: `te`) is the one-stop way to open a function in `$EDITOR`. It dispatches on where the function lives:

- captured in tank → opens the tank source file, then `functions --erase` + `fisher update` + `source` so the current shell picks up the edit immediately.
- local file at `~/.config/fish/functions/<fn>.fish` → opens it in place, then `--erase` + `source`.
- doesn't exist → writes a stub (`function <fn>\n    \nend`) to the local dir, opens it, sources on save, and prints a `tank capture <fn> <plugin>` nudge.

Avoid `funced` + `funcsave` for captured functions: `funcsave` writes to `~/.config/fish/functions/`, which sits ahead of the fisher path on `$fish_function_path`, so you'll create a *shadow* that hides the captured copy. If you do shadow one by accident, `tank capture --force <fn> <plugin>` (alias: `tc --force …`) promotes the shadow back into the tank.

## Short aliases

The `tank` plugin ships single-letter shortcuts for the commands you'll reach for daily:

| alias  | command         |
|--------|-----------------|
| `ts`   | `tank status`   |
| `te`   | `tank edit`     |
| `tw`   | `tank where`    |
| `tc`   | `tank capture`  |
| `tl`   | `tank list`     |
| `td`   | `tank doctor`   |
| `tn`   | `tank new`      |

(`t` + the first letter of each command. `tr` is left alone so as not to shadow GNU `tr`; type `tank refresh` in full.)

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
