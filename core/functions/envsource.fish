function envsource --description 'Source environment variables from a .env-style file'
    if test (count $argv) -ne 1
        echo "Usage: envsource <file>" >&2
        return 1
    end
    if not test -f $argv[1]
        echo "envsource: file not found: $argv[1]" >&2
        return 1
    end
    while read -l line
        set line (string replace -r '^\s+' '' -- $line)
        if test -z "$line"
            or string match -q '#*' -- $line
            continue
        end
        set line (string replace -r '^export\s+' '' -- $line)
        set -l parts (string split -m 1 '=' -- $line)
        if test (count $parts) -ne 2
            continue
        end
        set -l key $parts[1]
        set -l value $parts[2]
        set value (string replace -r '^"(.*)"$' '$1' -- $value)
        set value (string replace -r "^'(.*)'\$" '$1' -- $value)
        set -gx $key $value
        echo "Exported $key"
    end <$argv[1]
end
