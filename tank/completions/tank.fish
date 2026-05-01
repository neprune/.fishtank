# Fish shell completions for the tank command
# Manages personal git-backed fisher plugins

# Helpers --------------------------------------------------------------------

function __tank_local_plugins
    test -z "$fish_tank_dir"; and return 1
    for plugin_dir in $fish_tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)
        test "$plugin_name" = .git; and continue
        test -d "$plugin_path/functions"; or continue
        echo $plugin_name
    end
end

function __tank_installed_plugins
    test -z "$fish_tank_dir"; and return 1
    set -l installed_plugins (fisher list 2>/dev/null)
    for plugin_dir in $fish_tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)
        test "$plugin_name" = .git; and continue
        if string match -q "*$plugin_path*" $installed_plugins
            echo $plugin_name
        end
    end
end

function __tank_uncaptured_functions
    test -d "$__fish_config_dir/functions"; or return 0
    for f in $__fish_config_dir/functions/*.fish
        test -f $f; or continue
        set -l name (basename $f .fish)
        if string match -q 'fish_*' -- $name
            or string match -q '_*' -- $name
            or test -L $f
            continue
        end
        echo $name
    end
end

function __tank_captured_functions
    test -z "$fish_tank_dir"; and return 1
    for plugin_dir in $fish_tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)
        test "$plugin_name" = .git; and continue
        test -d "$plugin_path/functions"; or continue
        for f in $plugin_path/functions/*.fish
            test -f $f; or continue
            basename $f .fish
        end
    end
end

function __tank_tracked_external_plugins
    test -f "$fish_tank_dir/external_plugins"; or return 0
    cat "$fish_tank_dir/external_plugins" 2>/dev/null
end

function __tank_untracked_external_plugins
    set -l external (fisher list 2>/dev/null | grep --invert-match '^/.*' | grep --invert-match 'jorgebucaran/fisher')
    set -l tracked (__tank_tracked_external_plugins)
    for plugin in $external
        contains -- $plugin $tracked; or echo $plugin
    end
end

# Returns 0 if --<long> (or -<short> if given) flag is set, OR <long> appears
# as a subcommand keyword in argv.
function __tank_in_mode
    set -l long $argv[1]
    set -l short $argv[2]
    if test -n "$short"
        __fish_contains_opt -s $short $long; and return 0
    else
        __fish_contains_opt $long; and return 0
    end
    __fish_seen_subcommand_from $long
end

set -l __tank_subcommands init capture uncapture use nouse list refresh \
    track drop status edit where new doctor delete help

# Completions ----------------------------------------------------------------

complete -c tank -f

# Top-level subcommand keywords (only when nothing relevant has been typed yet)
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands; and not string match -qr -- '^-' (commandline -opc)[-1]" \
    -a init       -d "Initialize (symlink fisher_path, install fisher and tank)"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a capture    -d "Move function into tank under given plugin"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a uncapture  -d "Move function back out of tank"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a delete     -d "Delete a function wherever it lives"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a use        -d "Use a local plugin"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a nouse      -d "Stop using a local plugin"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a list       -d "List functions in in-use plugins"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a refresh    -d "Pull and update plugins"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a track      -d "Track an external plugin"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a drop       -d "Stop tracking an external plugin"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a status     -d "Show overview"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a edit       -d "Open a function in \$EDITOR (captured, local, or new)"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a where      -d "Print which plugin owns a function"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a new        -d "Create a new empty plugin"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a doctor     -d "Diagnose tank's setup"
complete -c tank -n "not __fish_seen_subcommand_from $__tank_subcommands" -a help       -d "Show help"

# Long/short flag forms (always available)
complete -c tank -s i -l init      -d "Initialize"
complete -c tank -s c -l capture   -d "Move function into tank under given plugin"
complete -c tank      -l uncapture -d "Move function back out of tank"
complete -c tank      -l delete    -d "Delete a function wherever it lives"
complete -c tank -s u -l use       -d "Use a local plugin (or all)"
complete -c tank -s n -l nouse     -d "Stop using a local plugin"
complete -c tank -s l -l list      -d "List functions"
complete -c tank -s r -l refresh   -d "Pull and update plugins"
complete -c tank      -l local     -d "Refresh: skip git ops"
complete -c tank -s t -l track     -d "Track an external plugin"
complete -c tank -s d -l drop      -d "Stop tracking an external plugin"
complete -c tank -s s -l status    -d "Show overview"
complete -c tank      -l edit      -d "Open a function in \$EDITOR (captured, local, or new)"
complete -c tank      -l where     -d "Print which plugin owns a function"
complete -c tank      -l new       -d "Create a new empty plugin"
complete -c tank      -l doctor    -d "Diagnose tank's setup"
complete -c tank      -l no-commit -d "Skip stash/pull/commit/push"
complete -c tank      -l no-push   -d "Commit but don't push"
complete -c tank      -l dry-run   -d "Show what would happen"
complete -c tank -s f -l force     -d "Capture: overwrite an existing captured copy"
complete -c tank -s h -l help      -d "Show help"

# Argument completions per mode

# capture <function> <plugin>   (offer both pools; fish narrows as you type)
complete -c tank -n "__tank_in_mode capture c" -a "(__tank_uncaptured_functions)" -d "Function to capture"
complete -c tank -n "__tank_in_mode capture c" -a "(__tank_local_plugins)"        -d "Target plugin"

# uncapture <function>
complete -c tank -n "__tank_in_mode uncapture" -a "(__tank_captured_functions)" -d "Function to uncapture"

# delete <function>  (any captured or local function)
complete -c tank -n "__tank_in_mode delete" -a "(__tank_captured_functions)"   -d "Captured function"
complete -c tank -n "__tank_in_mode delete" -a "(__tank_uncaptured_functions)" -d "Local function"

# edit <function>  (captured, local-only, or a new name)
complete -c tank -n "__tank_in_mode edit" -a "(__tank_captured_functions)"   -d "Captured function"
complete -c tank -n "__tank_in_mode edit" -a "(__tank_uncaptured_functions)" -d "Local function"

# where <function>
complete -c tank -n "__tank_in_mode where" -a "(__tank_captured_functions)" -d "Function to locate"

# use <plugin|all>
complete -c tank -n "__tank_in_mode use u" -a "(__tank_local_plugins)" -d "Local plugin"
complete -c tank -n "__tank_in_mode use u" -a "all"                    -d "All plugins"

# nouse <plugin>
complete -c tank -n "__tank_in_mode nouse n" -a "(__tank_installed_plugins)" -d "Plugin to remove"

# list [plugin]
complete -c tank -n "__tank_in_mode list l" -a "(__tank_installed_plugins)" -d "Plugin to list"

# track <external_plugin>
complete -c tank -n "__tank_in_mode track t" -a "(__tank_untracked_external_plugins)" -d "External plugin to track"

# drop <external_plugin>
complete -c tank -n "__tank_in_mode drop d" -a "(__tank_tracked_external_plugins)" -d "Tracked plugin to drop"
