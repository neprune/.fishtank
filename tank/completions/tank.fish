# Fish shell completions for the tank command
# Manages personal git-backed fisher plugins

# Helper function to get available local plugins
function __tank_local_plugins
    set -l tank_dir $fish_tank_dir
    if test -z "$tank_dir"
        return 1
    end

    for plugin_dir in $tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)

        # Skip .git directory
        if test "$plugin_name" = ".git"
            continue
        end

        # Skip if plugin doesn't have functions directory
        if not test -d "$plugin_path/functions"
            continue
        end

        echo $plugin_name
    end
end

# Helper function to get installed (in-use) local plugins
function __tank_installed_plugins
    set -l tank_dir $fish_tank_dir
    if test -z "$tank_dir"
        return 1
    end

    set -l installed_plugins (fisher list 2>/dev/null)

    for plugin_dir in $tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)

        # Skip .git directory
        if test "$plugin_name" = ".git"
            continue
        end

        # Check if plugin is installed
        if string match -q "*$plugin_path*" $installed_plugins
            echo $plugin_name
        end
    end
end

# Helper function to get available functions in ~/.config/fish/functions
function __tank_uncaptured_functions
    if test -d "$__fish_config_dir/functions"
        for func_file in $__fish_config_dir/functions/*.fish
            if test -f "$func_file"
                basename "$func_file" .fish
            end
        end
    end
end

# Helper function to get tracked external plugins
function __tank_tracked_external_plugins
    if test -f "$fish_tank_dir/external_plugins"
        cat "$fish_tank_dir/external_plugins" 2>/dev/null
    end
end

# Helper function to get untracked external plugins
function __tank_untracked_external_plugins
    set -l external_plugins (fisher list 2>/dev/null | grep --invert-match '^/.*' | grep --invert-match 'jorgebucaran/fisher')
    set -l tracked_plugins (__tank_tracked_external_plugins)

    for plugin in $external_plugins
        if not contains $plugin $tracked_plugins
            echo $plugin
        end
    end
end

# Disable file completions for tank command
complete -c tank -f

# Main options
complete -c tank -s i -l init -d "Initialize (symlink fisher_path, install fisher and tank)"
complete -c tank -s c -l capture -d "Move function into tank under given plugin"
complete -c tank -s u -l use -d "Use the given local plugin or all plugins"
complete -c tank -s n -l nouse -d "Stop using the given local plugin"
complete -c tank -s l -l list -d "List functions from in-use plugins"
complete -c tank -s r -l refresh -d "Pull repo and update in-use plugins"
complete -c tank -l local -d "Use with --refresh to skip git operations (for testing)"
complete -c tank -s t -l track -d "Track an external plugin"
complete -c tank -s d -l drop -d "Stop tracking an external plugin"
complete -c tank -s s -l status -d "Show overview of plugins and status"
complete -c tank -s h -l help -d "Show help message"

# Completions for --capture: first argument is function name, second is plugin name
complete -c tank -n "__fish_seen_subcommand_from -c --capture; and not __fish_seen_argument -n 2" -a "(__tank_uncaptured_functions)" -d "Function to capture"
complete -c tank -n "__fish_seen_subcommand_from -c --capture; and __fish_seen_argument -n 2" -a "(__tank_local_plugins)" -d "Target plugin"

# Completions for --use: plugin name or "all"
complete -c tank -n "__fish_seen_subcommand_from -u --use" -a "(__tank_local_plugins)" -d "Local plugin"
complete -c tank -n "__fish_seen_subcommand_from -u --use" -a "all" -d "All plugins"

# Completions for --nouse: only installed plugins
complete -c tank -n "__fish_seen_subcommand_from -n --nouse" -a "(__tank_installed_plugins)" -d "Plugin to remove"

# Completions for --list: only installed plugins (optional argument)
complete -c tank -n "__fish_seen_subcommand_from -l --list" -a "(__tank_installed_plugins)" -d "Plugin to list"

# Completions for --track: untracked external plugins
complete -c tank -n "__fish_seen_subcommand_from -t --track" -a "(__tank_untracked_external_plugins)" -d "External plugin to track"

# Completions for --drop: tracked external plugins
complete -c tank -n "__fish_seen_subcommand_from -d --drop" -a "(__tank_tracked_external_plugins)" -d "Tracked plugin to drop"
