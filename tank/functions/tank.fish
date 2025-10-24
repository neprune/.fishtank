function __tank_git_stash_pull
    pushd $fish_tank_dir

    # Check if there are any uncommitted changes
    if git diff-index --quiet HEAD --
        # No changes to stash
        git pull
        popd
        return 1
    else
        # Changes exist, stash them
        git stash
        git pull
        popd
        return 0
    end
end

function __tank_git_stash_pop
    pushd $fish_tank_dir
    git stash pop
    popd
end

function __tank_git_commit_push
    set -l message $argv[1]
    pushd $fish_tank_dir
    git add .
    git commit -m "$message"
    git push
    popd
end

function __tank_is_plugin_installed
    set -l plugin_path $argv[1]
    fisher list 2>/dev/null | grep -q "^$plugin_path\$"
end

function __tank_extract_function_description
    set -l function_file $argv[1]

    # Try to extract --description flag first (matches anywhere on the function line)
    # First try single quotes
    set -l description (grep -E '^\s*function\s+\w+.*--description\s+' "$function_file" | sed -nE "s/.*--description '([^']*)'.*/\1/p")

    if test -z "$description"
        # Then try double quotes
        set description (grep -E '^\s*function\s+\w+.*--description\s+' "$function_file" | sed -nE 's/.*--description "([^"]*)".*/\1/p')
    end

    if test -z "$description"
        # Then try unquoted (extract everything after --description, remove backslashes)
        set description (grep -o '\--description.*' "$function_file" | head -n 1 | sed 's/^--description //' | tr -d '\\')
    end

    if test -n "$description"
        echo $description
        return 0
    end

    # Fall back to first comment line
    set -l first_comment (grep -E '^\s*#' "$function_file" | head -n 1 | sed 's/^\s*#\s*//')

    if test -n "$first_comment"
        echo $first_comment
        return 0
    end

    # No description found
    echo ""
end

function tank --description 'Manage personal git-backed fisher plugins.'

    argparse --name=tank \
        'i/init' \
        'c/capture' \
        'u/use' \
        'n/nouse' \
        'l/list' \
        'r/refresh' \
        'local' \
        't/track' \
        'd/drop' \
        's/status' \
        'h/help' \
        -- $argv
    or return

    if set -q _flag_help
        echo "Usage: tank [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -i, --init                        Initialize (symlink fisher_path, install fisher and tank)."
        echo "  -c, --capture <function> <plugin> Move the function into the tank under the given local plugin, creating it if needed, and push the changes."
        echo "  -u, --use <plugin|all>            Use the given local plugin / all plugins."
        echo "  -n, --nouse <plugin>              No longer use the given local plugin."
        echo "  -l, --list [plugin]               List functions and descriptions from in-use plugins (or specific plugin)."
        echo "  -r, --refresh                     Pull the repo and update in use plugins."
        echo "      --local                       Use with --refresh to skip git operations (for testing local changes)."
        echo "  -t, --track <external plugin>     Track the external plugin."
        echo "  -d, --drop <external plugin>      Stop tracking the external plugin."
        echo "  -s, --status                      Give an overview of what's in use what's available."
        echo "  -h, --help                        Show this help message."
        return 0
    end

    # Init mode
    if set -q _flag_init
        echo "Initializing fish dotfiles setup..."

        # Step 1: Symlink fisher_path.fish
        set fisher_path_source "$fish_tank_dir/fisher_path.fish"
        set fisher_path_dest "$__fish_config_dir/conf.d/fisher_path.fish"

        echo "Symlinking fisher_path.fish to $fisher_path_dest"
        mkdir -p "$__fish_config_dir/conf.d"
        ln -sf "$fisher_path_source" "$fisher_path_dest"
        echo "Sourcing fisher_path.fish to set up fisher_path..."
        source "$fisher_path_dest"

        # Step 2: Install fisher if not already installed
        if type -q fisher
            echo "fisher is already installed"
        else
            echo "Installing fisher..."
            curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
            fisher install jorgebucaran/fisher
        end

        # Step 3: Install tank plugin
        if fisher list | grep -q "^$fish_tank_dir/tank\$"
            echo "tank plugin is already installed"
        else
            echo "Installing tank plugin..."
            fisher install "$fish_tank_dir/tank"
        end

        echo ""
        echo "Initialization complete!"
        echo ""
        echo ""
        echo "Printing status:"

        tank --status
        return 0
    end

    # Capture mode
    if set -q _flag_capture
        if test (count $argv) -ne 2
            echo "Error: --capture requires exactly 2 arguments: <function_name> <plugin_name>"
            return 1
        end

        set function_name $argv[1]
        set plugin_name $argv[2]
        set plugin_dir "$fish_tank_dir/$plugin_name"
        set function_file "$__fish_config_dir/functions/$function_name.fish"

        # Check if function exists
        if not test -f $function_file
            echo "Error: Function file '$function_file' not found"
            return 1
        end

        echo "Stashing and pulling before making any changes..."
        __tank_git_stash_pull
        set stashed $status

        # Create plugin directory and functions subdirectory if needed
        mkdir -p "$plugin_dir/functions"

        # Move function to plugin
        echo "Moving $function_name to $plugin_name plugin"
        mv "$function_file" "$plugin_dir/functions/"

        # Reload plugin with fisher
        echo "Reloading $plugin_name plugin"
        fisher update "$plugin_dir"

        echo "Committing the change..."
        __tank_git_commit_push "Capture $function_name under $plugin_name."

        if test $stashed -eq 0
            echo "Popping the stash..."
            __tank_git_stash_pop
        end

        echo "Successfully captured $function_name under $plugin_name"
        return 0
    end

    # Use mode
    if set -q _flag_use
        if test (count $argv) -ne 1
            echo "Error: --use requires exactly 1 argument: <plugin_name|all>"
            return 1
        end

        set target $argv[1]

        # Use plugin(s)
        if test "$target" = "all"
            echo "Using all local plugins"
            for plugin_dir in $fish_tank_dir/*/
                if test -d "$plugin_dir/functions"
                    set plugin_path (string trim --right --chars=/ $plugin_dir)
                    set plugin_name (basename $plugin_path)

                    if __tank_is_plugin_installed "$plugin_path"
                        echo "$plugin_name is already in use"
                    else
                        echo "Installing $plugin_name..."
                        fisher install "$plugin_path"
                    end
                end
            end
        else
            if test -d "$fish_tank_dir/$target"
                set plugin_path "$fish_tank_dir/$target"

                if __tank_is_plugin_installed "$plugin_path"
                    echo "$target is already in use"
                else
                    echo "Installing $target plugin..."
                    fisher install "$plugin_path"
                end
            else
                echo "Error: Plugin '$target' not found"
                return 1
            end
        end

        echo "Successfully loaded plugin(s)"
        return 0
    end

    # Nouse mode
    if set -q _flag_nouse
        if test (count $argv) -ne 1
            echo "Error: --nouse requires exactly 1 argument: <plugin_name>"
            return 1
        end

        set target $argv[1]
        set plugin_path "$fish_tank_dir/$target"

        if not test -d "$plugin_path"
            echo "Error: Plugin '$target' not found"
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

    # List mode
    if set -q _flag_list
        if test (count $argv) -gt 1
            echo "Error: --list accepts at most 1 argument: [plugin_name]"
            return 1
        end

        set target_plugin ""
        if test (count $argv) -eq 1
            set target_plugin $argv[1]
        end

        set found_any 0

        for plugin_dir in $fish_tank_dir/*/
            set plugin_path (string trim --right --chars=/ $plugin_dir)
            set plugin_name (basename $plugin_path)

            # Skip .git directory
            if test "$plugin_name" = ".git"
                continue
            end

            # Skip if not in use
            if not __tank_is_plugin_installed "$plugin_path"
                continue
            end

            # Skip if target specified and doesn't match
            if test -n "$target_plugin" -a "$plugin_name" != "$target_plugin"
                continue
            end

            # Check if plugin has functions
            if not test -d "$plugin_path/functions"
                continue
            end

            set function_files "$plugin_path/functions"/*.fish
            if not test -e "$function_files[1]"
                continue
            end

            set found_any 1
            echo "==> Plugin: $plugin_name (in use)"

            for function_file in $plugin_path/functions/*.fish
                set function_name (basename "$function_file" .fish)
                set description (__tank_extract_function_description "$function_file")

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

    # Refresh mode
    if set -q _flag_refresh
        # Skip git operations if --local flag is set (for testing local changes)
        if not set -q _flag_local
            echo "Stashing, pulling and popping..."
            __tank_git_stash_pull
            set stashed $status
            if test $stashed -eq 0
                __tank_git_stash_pop
            end
        else
            echo "Refreshing using local state (skipping git operations)..."
        end

        for plugin_dir in $fish_tank_dir/*/
            if test -d "$plugin_dir/functions"
                set plugin_path (string trim --right --chars=/ $plugin_dir)
                set plugin_name (basename $plugin_path)

                if __tank_is_plugin_installed "$plugin_path"
                    echo "Updating $plugin_name..."
                    fisher update "$plugin_path"
                end
            end
        end
        return 0
    end

    # Track mode
    if set -q _flag_track
        if test (count $argv) -ne 1
            echo "Error: --track requires exactly 1 argument: <external_plugin>"
            return 1
        end

        set external_plugin $argv[1]

        echo "Stashing and pulling before making any changes..."
        __tank_git_stash_pull
        set stashed $status

        set TRACKED_EXTERNAL_PLUGINS (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
        for p in $TRACKED_EXTERNAL_PLUGINS
            if test "$p" = "$external_plugin"
                echo "$external_plugin is already tracked, nothing to do"
                if test $stashed -eq 0
                    __tank_git_stash_pop
                end
                return 0
            end
        end

        echo "$external_plugin" >>$fish_tank_dir/external_plugins

        echo "Committing the change..."
        __tank_git_commit_push "Track external plugin $external_plugin."

        if test $stashed -eq 0
            echo "Popping the stash..."
            __tank_git_stash_pop
        end

        return 0
    end

    # Drop mode
    if set -q _flag_drop
        if test (count $argv) -ne 1
            echo "Error: --drop requires exactly 1 argument: <external_plugin>"
            return 1
        end

        set external_plugin $argv[1]

        echo "Stashing and pulling before making any changes..."
        __tank_git_stash_pull
        set stashed $status

        set TRACKED_EXTERNAL_PLUGINS (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
        set found 0
        for p in $TRACKED_EXTERNAL_PLUGINS
            if test "$p" = "$external_plugin"
                set found 1
                break
            end
        end

        if test $found -eq 0
            echo "Error: $external_plugin does not appear to be tracked"
            if test $stashed -eq 0
                __tank_git_stash_pop
            end
            return 1
        end

        echo "Dropping $external_plugin..."
        sed -i.bak "\#$external_plugin#d" "$fish_tank_dir/external_plugins"
        rm -f "$fish_tank_dir/external_plugins.bak"

        echo "Committing the change..."
        __tank_git_commit_push "Drop external plugin $external_plugin."

        if test $stashed -eq 0
            echo "Popping the stash..."
            __tank_git_stash_pop
        end

        return 0
    end

    # Status mode
    if set -q _flag_status
        echo "==> Local plugins:"
        echo ""
        echo "Use a plugin via --use and undo this via --nouse."
        echo ""
        set installed_plugins (fisher list 2>/dev/null)

        for plugin_dir in $fish_tank_dir/*/
            set plugin_path (string trim --right --chars=/ $plugin_dir)
            set plugin_name (basename $plugin_path)

            # Skip .git directory
            if test "$plugin_name" = ".git"
                continue
            end

            # Check if plugin is installed
            if string match -q "*$plugin_path*" $installed_plugins
                echo " - $plugin_name: in use"
            else
                echo " - $plugin_name: not used"
            end
        end

        echo ""
        echo "==> Uncaptured functions:"
        echo ""
        echo "Capture a function via --capture <function> <plugin>"
        echo ""
        if test -d "$__fish_config_dir/functions"
            ls $__fish_config_dir/functions 2>/dev/null | string replace -r '(.*)\.fish' '$1' | sed 's/^/ - /'
        end

        echo ""
        echo "==> Un-tracked 'external' fisher plugins:"
        echo ""
        echo "These can be tracked by --track <plugin>"
        echo ""
        set EXTERNAL_PLUGINS (fisher list 2>/dev/null | grep --invert-match '^/.*' | grep --invert-match 'jorgebucaran/fisher' | sort)
        set TRACKED_EXTERNAL_PLUGINS (cat $fish_tank_dir/external_plugins 2>/dev/null | sort)
        for plugin in $EXTERNAL_PLUGINS
            if not contains $plugin $TRACKED_EXTERNAL_PLUGINS
                echo " - $plugin"
            end
        end

        echo ""
        echo "==> Tracked but not installed 'external' fisher plugins:"
        echo ""
        echo "You can install these via fisher install <plugin>"
        echo ""
        for plugin in $TRACKED_EXTERNAL_PLUGINS
            if not contains $plugin $EXTERNAL_PLUGINS
                echo " - $plugin"
            end
        end

        echo ""
        echo "==> Git status:"
        echo ""
        pushd $fish_tank_dir
        git status
        popd

        return 0
    end

    # No flags provided
    echo "Error: No operation specified. Use -h for help."
    return 1

end
