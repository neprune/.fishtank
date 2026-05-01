# Helpers --------------------------------------------------------------------

function __tank_has_dirty_tree
    set -l output (git -C $fish_tank_dir status --porcelain)
    test (count $output) -gt 0
end

# Returns 0 if changes were stashed, 1 if nothing to stash, 2 on error.
function __tank_git_stash_pull
    if __tank_has_dirty_tree
        if not git -C $fish_tank_dir stash push -u -m "tank auto-stash"
            return 2
        end
        git -C $fish_tank_dir pull
        return 0
    else
        git -C $fish_tank_dir pull
        return 1
    end
end

function __tank_git_stash_pop
    git -C $fish_tank_dir stash pop
end

function __tank_git_commit
    set -l message $argv[1]
    set -l paths $argv[2..]
    if test (count $paths) -eq 0
        return 1
    end
    git -C $fish_tank_dir add -- $paths
    or return 1
    if git -C $fish_tank_dir diff --cached --quiet
        return 0
    end
    git -C $fish_tank_dir commit -m "$message"
end

function __tank_git_commit_push
    __tank_git_commit $argv
    or return 1
    git -C $fish_tank_dir push
end

function __tank_is_plugin_installed
    set -l plugin_path $argv[1]
    fisher list 2>/dev/null | grep -q "^$plugin_path\$"
end

function __tank_extract_function_description
    set -l function_file $argv[1]

    set -l description (grep -E '^\s*function\s+\w+.*--description\s+' "$function_file" | sed -nE "s/.*--description '([^']*)'.*/\1/p")

    if test -z "$description"
        set description (grep -E '^\s*function\s+\w+.*--description\s+' "$function_file" | sed -nE 's/.*--description "([^"]*)".*/\1/p')
    end

    if test -z "$description"
        set description (grep -o '\--description.*' "$function_file" | head -n 1 | sed 's/^--description //' | tr -d '\\')
    end

    if test -n "$description"
        echo $description
        return 0
    end

    set -l first_comment (grep -E '^\s*#' "$function_file" | head -n 1 | sed 's/^\s*#\s*//')

    if test -n "$first_comment"
        echo $first_comment
        return 0
    end

    echo ""
end

# Echoes the plugin name owning <fn>, or returns 1 if not found.
function __tank_find_function
    set -l fn $argv[1]
    for plugin_dir in $fish_tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)
        if test "$plugin_name" = .git
            continue
        end
        if test -f "$plugin_path/functions/$fn.fish"
            echo $plugin_name
            return 0
        end
    end
    return 1
end

# Echoes uncaptured function names (filters fisher artefacts and fish_* hooks).
function __tank_uncaptured_function_names
    if not test -d "$__fish_config_dir/functions"
        return
    end
    for f in $__fish_config_dir/functions/*.fish
        set -l name (basename $f .fish)
        if string match -q 'fish_*' -- $name
            or string match -q '_*' -- $name
            or test -L $f
            continue
        end
        echo $name
    end
end

# Main tank command ----------------------------------------------------------

function tank --description 'Manage personal git-backed fisher plugins.'

    # Subcommand-style invocation: rewrite `tank capture x y` -> `tank --capture x y`.
    set -l subcommands init capture uncapture use nouse list refresh \
        track drop status edit where new doctor help
    if test (count $argv) -ge 1; and contains -- $argv[1] $subcommands
        set argv "--$argv[1]" $argv[2..]
    end

    argparse --name=tank \
        'i/init' \
        'c/capture' \
        'uncapture' \
        'u/use' \
        'n/nouse' \
        'l/list' \
        'r/refresh' \
        'local' \
        't/track' \
        'd/drop' \
        's/status' \
        'edit' \
        'where' \
        'new' \
        'doctor' \
        'no-commit' \
        'no-push' \
        'dry-run' \
        'h/help' \
        -- $argv
    or return

    if set -q _flag_help
        echo "Usage: tank <command> [args...]"
        echo "       tank --<command> [args...]   (flag form, equivalent)"
        echo ""
        echo "Lifecycle:"
        echo "  init                              Symlink fisher_path, install fisher and tank."
        echo "  doctor                            Check tank's health."
        echo "  status                            Show plugins and uncaptured functions."
        echo ""
        echo "Local plugins:"
        echo "  new <plugin>                      Create a new empty plugin."
        echo "  capture <fn> <plugin>             Move <fn> into <plugin>, fisher-update, commit, push."
        echo "  uncapture <fn>                    Move <fn> back out of its plugin into ~/.config/fish/functions/."
        echo "  use <plugin|all>                  Use the given local plugin (or all)."
        echo "  nouse <plugin>                    Stop using the given local plugin."
        echo "  edit <fn>                         Open a captured function in \$EDITOR."
        echo "  where <fn>                        Print which plugin owns <fn>."
        echo "  list [plugin]                     List functions in in-use plugins."
        echo "  refresh                           Pull repo, update in-use plugins, install tracked externals."
        echo ""
        echo "External plugins:"
        echo "  track <plugin>                    Track an external fisher plugin."
        echo "  drop <plugin>                     Stop tracking an external plugin."
        echo ""
        echo "Modifiers:"
        echo "  --no-commit                       Skip auto stash/pull/commit/push (capture/uncapture/track/drop)."
        echo "  --no-push                         Commit but don't push."
        echo "  --dry-run                         Print what would happen without doing it."
        echo "  --local                           For refresh: skip git ops, just rerun local fisher updates."
        echo "  -h, --help                        Show this help."
        return 0
    end

    # Doctor and help can run with no environment; everything else needs $fish_tank_dir.
    if not set -q _flag_doctor
        if not set -q fish_tank_dir
            echo "Error: fish_tank_dir is not set. Run 'tank doctor' for diagnostics, or set it via:" >&2
            echo "    set -U fish_tank_dir (pwd)" >&2
            return 1
        end
        if not test -d $fish_tank_dir
            echo "Error: fish_tank_dir = $fish_tank_dir but that directory does not exist." >&2
            return 1
        end
    end

    # Init -------------------------------------------------------------------
    if set -q _flag_init
        echo "Initializing fish dotfiles setup..."

        set -l fisher_path_source "$fish_tank_dir/fisher_path.fish"
        set -l fisher_path_dest "$__fish_config_dir/conf.d/fisher_path.fish"

        echo "Symlinking fisher_path.fish to $fisher_path_dest"
        mkdir -p "$__fish_config_dir/conf.d"
        ln -sf "$fisher_path_source" "$fisher_path_dest"
        echo "Sourcing fisher_path.fish to set up fisher_path..."
        source "$fisher_path_dest"

        if type -q fisher
            echo "fisher is already installed"
        else
            echo "Installing fisher..."
            curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
            fisher install jorgebucaran/fisher
        end

        if fisher list | grep -q "^$fish_tank_dir/tank\$"
            echo "tank plugin is already installed"
        else
            echo "Installing tank plugin..."
            fisher install "$fish_tank_dir/tank"
        end

        echo ""
        echo "Initialization complete!"
        echo ""
        echo "Printing status:"
        tank --status
        return 0
    end

    # Capture ----------------------------------------------------------------
    if set -q _flag_capture
        if test (count $argv) -ne 2
            echo "Error: capture requires 2 arguments: <function_name> <plugin_name>"
            return 1
        end

        set -l function_name $argv[1]
        set -l plugin_name $argv[2]
        set -l plugin_dir "$fish_tank_dir/$plugin_name"
        set -l function_file "$__fish_config_dir/functions/$function_name.fish"
        set -l rel_path "$plugin_name/functions/$function_name.fish"
        set -l target_file "$fish_tank_dir/$rel_path"

        if not test -f $function_file
            echo "Error: function file '$function_file' not found"
            return 1
        end
        if test -e $target_file
            echo "Error: $target_file already exists"
            return 1
        end

        if set -q _flag_dry_run
            echo "Would move:"
            echo "  $function_file"
            echo "  -> $target_file"
            return 0
        end

        set -l stashed 1
        if not set -q _flag_no_commit
            echo "Stashing and pulling before making any changes..."
            __tank_git_stash_pull
            set stashed $status
            if test $stashed -eq 2
                echo "Error: stash failed; aborting"
                return 1
            end
        end

        mkdir -p (dirname $target_file)
        if not mv "$function_file" "$target_file"
            echo "Error: failed to move function file"
            if test $stashed -eq 0
                __tank_git_stash_pop
            end
            return 1
        end

        echo "Reloading $plugin_name plugin"
        fisher update "$plugin_dir"

        if not set -q _flag_no_commit
            echo "Committing..."
            if set -q _flag_no_push
                __tank_git_commit "Capture $function_name under $plugin_name." $rel_path
            else
                __tank_git_commit_push "Capture $function_name under $plugin_name." $rel_path
            end
            if test $stashed -eq 0
                echo "Popping the stash..."
                __tank_git_stash_pop
            end
        end

        echo "Captured $function_name under $plugin_name"
        return 0
    end

    # Uncapture --------------------------------------------------------------
    if set -q _flag_uncapture
        if test (count $argv) -ne 1
            echo "Error: uncapture requires 1 argument: <function_name>"
            return 1
        end

        set -l function_name $argv[1]
        set -l owner (__tank_find_function $function_name)
        if test -z "$owner"
            echo "Error: function '$function_name' not found in any local plugin"
            return 1
        end

        set -l rel_path "$owner/functions/$function_name.fish"
        set -l source_file "$fish_tank_dir/$rel_path"
        set -l dest_file "$__fish_config_dir/functions/$function_name.fish"

        if test -e $dest_file
            echo "Error: $dest_file already exists; refusing to overwrite"
            return 1
        end

        if set -q _flag_dry_run
            echo "Would move:"
            echo "  $source_file"
            echo "  -> $dest_file"
            return 0
        end

        set -l stashed 1
        if not set -q _flag_no_commit
            echo "Stashing and pulling before making any changes..."
            __tank_git_stash_pull
            set stashed $status
            if test $stashed -eq 2
                echo "Error: stash failed; aborting"
                return 1
            end
        end

        mkdir -p (dirname $dest_file)
        if not mv "$source_file" "$dest_file"
            echo "Error: failed to move function file"
            if test $stashed -eq 0
                __tank_git_stash_pop
            end
            return 1
        end

        echo "Reloading $owner plugin"
        fisher update "$fish_tank_dir/$owner"

        if not set -q _flag_no_commit
            echo "Committing..."
            if set -q _flag_no_push
                __tank_git_commit "Uncapture $function_name from $owner." $rel_path
            else
                __tank_git_commit_push "Uncapture $function_name from $owner." $rel_path
            end
            if test $stashed -eq 0
                echo "Popping the stash..."
                __tank_git_stash_pop
            end
        end

        echo "Uncaptured $function_name from $owner -> $dest_file"
        return 0
    end

    # Use --------------------------------------------------------------------
    if set -q _flag_use
        if test (count $argv) -ne 1
            echo "Error: use requires 1 argument: <plugin_name|all>"
            return 1
        end
        set -l target $argv[1]

        if test "$target" = all
            echo "Using all local plugins"
            for plugin_dir in $fish_tank_dir/*/
                if test -d "$plugin_dir/functions"
                    set -l plugin_path (string trim --right --chars=/ $plugin_dir)
                    set -l plugin_name (basename $plugin_path)
                    if __tank_is_plugin_installed "$plugin_path"
                        echo "$plugin_name is already in use"
                    else
                        echo "Installing $plugin_name..."
                        fisher install "$plugin_path"
                    end
                end
            end
        else
            if not test -d "$fish_tank_dir/$target"
                echo "Error: plugin '$target' not found"
                return 1
            end
            set -l plugin_path "$fish_tank_dir/$target"
            if __tank_is_plugin_installed "$plugin_path"
                echo "$target is already in use"
            else
                echo "Installing $target plugin..."
                fisher install "$plugin_path"
            end
        end

        echo "Successfully loaded plugin(s)"
        return 0
    end

    # Nouse ------------------------------------------------------------------
    if set -q _flag_nouse
        if test (count $argv) -ne 1
            echo "Error: nouse requires 1 argument: <plugin_name>"
            return 1
        end
        set -l target $argv[1]
        set -l plugin_path "$fish_tank_dir/$target"

        if not test -d "$plugin_path"
            echo "Error: plugin '$target' not found"
            return 1
        end
        if not __tank_is_plugin_installed "$plugin_path"
            echo "Plugin '$target' is not currently in use"
            return 0
        end

        echo "Removing $target plugin..."
        fisher remove "$plugin_path"
        echo "Successfully removed $target"
        return 0
    end

    # List -------------------------------------------------------------------
    if set -q _flag_list
        if test (count $argv) -gt 1
            echo "Error: list accepts at most 1 argument: [plugin_name]"
            return 1
        end

        set -l target_plugin ""
        if test (count $argv) -eq 1
            set target_plugin $argv[1]
        end

        set -l found_any 0
        for plugin_dir in $fish_tank_dir/*/
            set -l plugin_path (string trim --right --chars=/ $plugin_dir)
            set -l plugin_name (basename $plugin_path)

            if test "$plugin_name" = .git; continue; end
            if not __tank_is_plugin_installed "$plugin_path"; continue; end
            if test -n "$target_plugin"; and test "$plugin_name" != "$target_plugin"; continue; end
            if not test -d "$plugin_path/functions"; continue; end

            set -l function_files "$plugin_path/functions"/*.fish
            if not test -e "$function_files[1]"; continue; end

            set found_any 1
            echo "==> Plugin: $plugin_name (in use)"

            for function_file in $plugin_path/functions/*.fish
                set -l function_name (basename "$function_file" .fish)
                set -l description (__tank_extract_function_description "$function_file")
                if test -n "$description"
                    echo "  - $function_name: $description"
                else
                    echo "  - $function_name"
                end
            end
            echo ""
        end

        if test $found_any -eq 0
            if test -n "$target_plugin"
                echo "No in-use plugin named '$target_plugin' found with functions"
            else
                echo "No in-use plugins with functions found"
            end
            return 1
        end
        return 0
    end

    # Refresh ----------------------------------------------------------------
    if set -q _flag_refresh
        if set -q _flag_dry_run
            echo "Dry run: would do the following:"
            if not set -q _flag_local
                echo "  - stash + git pull (+ pop)"
            end
            for plugin_dir in $fish_tank_dir/*/
                if test -d "$plugin_dir/functions"
                    set -l plugin_path (string trim --right --chars=/ $plugin_dir)
                    set -l plugin_name (basename $plugin_path)
                    if __tank_is_plugin_installed "$plugin_path"
                        echo "  - fisher update $plugin_name"
                    end
                end
            end
            if not set -q _flag_local
                set -l TRACKED (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
                set -l INSTALLED (fisher list 2>/dev/null)
                for p in $TRACKED
                    if not contains $p $INSTALLED
                        echo "  - fisher install $p (tracked but missing)"
                    end
                end
            end
            return 0
        end

        if not set -q _flag_local
            echo "Stashing, pulling and popping..."
            __tank_git_stash_pull
            set -l stashed $status
            if test $stashed -eq 0
                __tank_git_stash_pop
            end
        else
            echo "Refreshing using local state (skipping git operations)..."
        end

        for plugin_dir in $fish_tank_dir/*/
            if test -d "$plugin_dir/functions"
                set -l plugin_path (string trim --right --chars=/ $plugin_dir)
                set -l plugin_name (basename $plugin_path)
                if __tank_is_plugin_installed "$plugin_path"
                    echo "Updating $plugin_name..."
                    fisher update "$plugin_path"
                end
            end
        end

        if not set -q _flag_local
            set -l TRACKED (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
            set -l INSTALLED (fisher list 2>/dev/null)
            for p in $TRACKED
                if not contains $p $INSTALLED
                    echo "Installing tracked external plugin $p..."
                    fisher install $p
                end
            end
        end
        return 0
    end

    # Track ------------------------------------------------------------------
    if set -q _flag_track
        if test (count $argv) -ne 1
            echo "Error: track requires 1 argument: <external_plugin>"
            return 1
        end
        set -l external_plugin $argv[1]

        set -l TRACKED (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
        if contains -- $external_plugin $TRACKED
            echo "$external_plugin is already tracked, nothing to do"
            return 0
        end

        if set -q _flag_dry_run
            echo "Would append '$external_plugin' to $fish_tank_dir/external_plugins and commit."
            return 0
        end

        set -l stashed 1
        if not set -q _flag_no_commit
            echo "Stashing and pulling before making any changes..."
            __tank_git_stash_pull
            set stashed $status
            if test $stashed -eq 2
                echo "Error: stash failed; aborting"
                return 1
            end
        end

        echo "$external_plugin" >>$fish_tank_dir/external_plugins

        if not set -q _flag_no_commit
            echo "Committing..."
            if set -q _flag_no_push
                __tank_git_commit "Track external plugin $external_plugin." external_plugins
            else
                __tank_git_commit_push "Track external plugin $external_plugin." external_plugins
            end
            if test $stashed -eq 0
                echo "Popping the stash..."
                __tank_git_stash_pop
            end
        end
        return 0
    end

    # Drop -------------------------------------------------------------------
    if set -q _flag_drop
        if test (count $argv) -ne 1
            echo "Error: drop requires 1 argument: <external_plugin>"
            return 1
        end
        set -l external_plugin $argv[1]

        set -l TRACKED (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
        if not contains -- $external_plugin $TRACKED
            echo "Error: $external_plugin does not appear to be tracked"
            return 1
        end

        if set -q _flag_dry_run
            echo "Would remove '$external_plugin' from $fish_tank_dir/external_plugins and commit."
            return 0
        end

        set -l stashed 1
        if not set -q _flag_no_commit
            echo "Stashing and pulling before making any changes..."
            __tank_git_stash_pull
            set stashed $status
            if test $stashed -eq 2
                echo "Error: stash failed; aborting"
                return 1
            end
        end

        echo "Dropping $external_plugin..."
        sed -i.bak "\#$external_plugin#d" "$fish_tank_dir/external_plugins"
        rm -f "$fish_tank_dir/external_plugins.bak"

        if not set -q _flag_no_commit
            echo "Committing..."
            if set -q _flag_no_push
                __tank_git_commit "Drop external plugin $external_plugin." external_plugins
            else
                __tank_git_commit_push "Drop external plugin $external_plugin." external_plugins
            end
            if test $stashed -eq 0
                echo "Popping the stash..."
                __tank_git_stash_pop
            end
        end
        return 0
    end

    # Edit -------------------------------------------------------------------
    if set -q _flag_edit
        if test (count $argv) -ne 1
            echo "Error: edit requires 1 argument: <function_name>"
            return 1
        end
        set -l fn $argv[1]
        set -l owner (__tank_find_function $fn)
        if test -z "$owner"
            echo "Error: function '$fn' not found in any local plugin"
            return 1
        end
        set -l file "$fish_tank_dir/$owner/functions/$fn.fish"

        set -l editor $EDITOR
        if test -z "$editor"; and type -q nvim; set editor nvim; end
        if test -z "$editor"; and type -q vim;  set editor vim;  end
        if test -z "$editor"; set editor vi; end

        $editor $file
        return $status
    end

    # Where ------------------------------------------------------------------
    if set -q _flag_where
        if test (count $argv) -ne 1
            echo "Error: where requires 1 argument: <function_name>"
            return 1
        end
        set -l fn $argv[1]
        set -l owner (__tank_find_function $fn)
        if test -z "$owner"
            echo "Function '$fn' not found in any local plugin"
            return 1
        end
        echo "$fish_tank_dir/$owner/functions/$fn.fish"
        return 0
    end

    # New --------------------------------------------------------------------
    if set -q _flag_new
        if test (count $argv) -ne 1
            echo "Error: new requires 1 argument: <plugin_name>"
            return 1
        end
        set -l plugin_name $argv[1]
        set -l plugin_dir "$fish_tank_dir/$plugin_name"

        if test -d $plugin_dir
            echo "Error: plugin '$plugin_name' already exists at $plugin_dir"
            return 1
        end

        if set -q _flag_dry_run
            echo "Would create $plugin_dir/functions/"
            return 0
        end

        mkdir -p "$plugin_dir/functions"
        echo "Created $plugin_dir/functions/"
        echo ""
        echo "Next steps:"
        echo "  tank capture <fn> $plugin_name"
        echo "  tank use $plugin_name"
        return 0
    end

    # Doctor -----------------------------------------------------------------
    if set -q _flag_doctor
        set -l problems 0

        echo "==> tank doctor"
        echo ""

        if not set -q fish_tank_dir
            echo "  [FAIL] fish_tank_dir is not set"
            set problems (math $problems + 1)
        else if not test -d $fish_tank_dir
            echo "  [FAIL] fish_tank_dir = $fish_tank_dir but directory does not exist"
            set problems (math $problems + 1)
        else
            echo "  [ OK ] fish_tank_dir = $fish_tank_dir"
        end

        if set -q fish_tank_dir; and test -d $fish_tank_dir
            set -l link "$__fish_config_dir/conf.d/fisher_path.fish"
            set -l want "$fish_tank_dir/fisher_path.fish"
            if not test -L $link
                echo "  [FAIL] $link is not a symlink (run: tank init)"
                set problems (math $problems + 1)
            else
                set -l target (readlink $link)
                if test "$target" != "$want"
                    echo "  [FAIL] $link -> $target (expected $want)"
                    set problems (math $problems + 1)
                else
                    echo "  [ OK ] fisher_path.fish symlinked correctly"
                end
            end

            if type -q fisher
                echo "  [ OK ] fisher installed"
            else
                echo "  [FAIL] fisher not installed (run: tank init)"
                set problems (math $problems + 1)
            end

            if fisher list 2>/dev/null | grep -q "^$fish_tank_dir/tank\$"
                echo "  [ OK ] tank plugin installed"
            else
                echo "  [FAIL] tank plugin not installed (run: tank init)"
                set problems (math $problems + 1)
            end

            set -l TRACKED (cat $fish_tank_dir/external_plugins 2>/dev/null)
            set -l INSTALLED (fisher list 2>/dev/null)
            for p in $TRACKED
                if not contains -- $p $INSTALLED
                    echo "  [FAIL] tracked external plugin not installed: $p (run: tank refresh)"
                    set problems (math $problems + 1)
                end
            end
            if test (count $TRACKED) -gt 0; and test $problems -eq 0
                echo "  [ OK ] all $(count $TRACKED) tracked external plugin(s) installed"
            end
        end

        echo ""
        if test $problems -eq 0
            echo "All good."
            return 0
        else
            echo "$problems problem(s) found."
            return 1
        end
    end

    # Status -----------------------------------------------------------------
    if set -q _flag_status
        echo "==> Local plugins:"
        echo ""
        echo "Use a plugin via 'tank use', undo via 'tank nouse'."
        echo ""
        set -l installed_plugins (fisher list 2>/dev/null)

        for plugin_dir in $fish_tank_dir/*/
            set -l plugin_path (string trim --right --chars=/ $plugin_dir)
            set -l plugin_name (basename $plugin_path)
            if test "$plugin_name" = .git; continue; end

            if string match -q "*$plugin_path*" $installed_plugins
                echo " - $plugin_name: in use"
            else
                echo " - $plugin_name: not used"
            end
        end

        echo ""
        echo "==> Uncaptured functions:"
        echo ""
        echo "Capture via 'tank capture <fn> <plugin>'."
        echo "(Filters fish_*, _*, and symlinks.)"
        echo ""
        for name in (__tank_uncaptured_function_names)
            echo " - $name"
        end

        echo ""
        echo "==> Un-tracked external fisher plugins:"
        echo ""
        echo "Track these via 'tank track <plugin>'."
        echo ""
        set -l EXTERNAL (fisher list 2>/dev/null | grep --invert-match '^/.*' | grep --invert-match 'jorgebucaran/fisher' | sort)
        set -l TRACKED (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
        for plugin in $EXTERNAL
            if not contains -- $plugin $TRACKED
                echo " - $plugin"
            end
        end

        echo ""
        echo "==> Tracked but not installed external fisher plugins:"
        echo ""
        echo "Install these via 'tank refresh' (or 'fisher install <plugin>')."
        echo ""
        for plugin in $TRACKED
            if not contains -- $plugin $EXTERNAL
                echo " - $plugin"
            end
        end

        echo ""
        echo "==> Git status:"
        echo ""
        git -C $fish_tank_dir status

        return 0
    end

    echo "Error: no operation specified. Run 'tank help'."
    return 1
end
