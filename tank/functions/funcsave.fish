function funcsave --description 'Save function to disk; reminds you it can be captured into the tank.'
    set -l options q/quiet h/help d/directory=
    argparse -n funcsave $options -- $argv
    or return

    if set -q _flag_help
        echo "Usage: funcsave [-q] [-d DIR] FUNCNAME..."
        echo ""
        echo "Saves each FUNCNAME to DIR/FUNCNAME.fish (DIR defaults to ~/.config/fish/functions)."
        echo "If FUNCNAME isn't defined but the file exists, the file is removed."
        echo "Prints a 'tank capture' reminder unless -q, \$tank_funcsave_quiet, or -d is used."
        return 0
    end

    set -l funcdir
    if set -q _flag_directory
        set funcdir $_flag_directory
    else
        set funcdir $__fish_config_dir/functions
    end

    if not set -q argv[1]
        echo "funcsave: expected at least 1 argument" >&2
        return 1
    end

    if not mkdir -p $funcdir
        echo "funcsave: could not create directory '$funcdir'" >&2
        return 1
    end

    set -l retval 0
    set -l saved
    for funcname in $argv
        set -l funcpath "$funcdir/$funcname.fish"
        if functions -q -- $funcname
            if functions --no-details -- $funcname >$funcpath
                set -a saved $funcname
                set -q _flag_quiet
                or printf "funcsave: wrote %s\n" $funcpath
            else
                set retval 1
            end
        else if test -w $funcpath
            if command rm $funcpath
                set -q _flag_quiet
                or printf "funcsave: removed %s\n" $funcpath
            else
                set retval 1
            end
        else
            printf "funcsave: Unknown function '%s'\n" $funcname >&2
            set retval 1
        end
    end

    # Tank reminder ----------------------------------------------------------
    # Skip if quiet, opt-out env var set, custom directory, or no tank context.
    if test (count $saved) -eq 0
        or set -q _flag_quiet
        or set -q tank_funcsave_quiet
        or set -q _flag_directory
        or not set -q fish_tank_dir
        or not test -d $fish_tank_dir
        return $retval
    end

    set -l plugins
    for plugin_dir in $fish_tank_dir/*/
        set -l plugin_path (string trim --right --chars=/ $plugin_dir)
        set -l plugin_name (basename $plugin_path)
        test "$plugin_name" = .git; and continue
        test -d "$plugin_path/functions"; or continue
        set -a plugins $plugin_name
    end

    for funcname in $saved
        echo ""
        echo "Tip: capture into the tank with: tank capture $funcname <plugin>"
        if test (count $plugins) -gt 0
            echo "     Available plugins: "(string join " " $plugins)
        end
        echo "     (silence with: set -U tank_funcsave_quiet 1)"
    end

    return $retval
end
