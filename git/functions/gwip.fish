function gwip --wraps='git commit -m wip' --description 'commit -m wip'
    git commit -m wip $argv
end
