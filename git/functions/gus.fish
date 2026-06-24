function gus --description "Set upstream to <remote> for current branch"
    if test (count $argv) -eq 0
        echo "usage: gus <remote>"
        return 1
    end

    set branch (git rev-parse --abbrev-ref HEAD)

    if test "$branch" = HEAD
        echo "gus: detached HEAD, no current branch"
        return 1
    end

    git branch -u $argv[1]/$branch $branch
end
