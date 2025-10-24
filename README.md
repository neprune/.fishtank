# .fishtank

For fish shell functionality I want to share across machines, or just not have disappear into oblivion.

Basically, this repo keeps a bunch of my own [fisher](https://github.com/jorgebucaran/fisher) plugins including one called `tank` which manages these local plugins.

## Setup

1. Install [fish shell](https://fishshell.com/).
2. Clone this repository to preferred location (e.g., `~/.fishtank`).
3. Set the `fish_tank_dir` universal variable to point to this repository:
   ```fish
   cd /path/to/this/repo
   set -U fish_tank_dir (pwd)
   ```
4. Initialize via and see next steps via:
   ```fish
   source tank/functions/tank.fish && tank --init
   ```

## Usage

Run `tank --status` to see what's available and `--help` for more info on the specific commands.

## Removal

`fisher remove <local plugin>` works.

Can also do `fisher list | fisher remove` to go nuclear and remove all plugins and `fisher` itself.
