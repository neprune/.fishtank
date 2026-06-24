function gu --wraps='git rev-parse --abbrev-ref --symbolic-full-name @{u}' --description 'alias gu=git rev-parse --abbrev-ref --symbolic-full-name @{u}'
    git rev-parse --abbrev-ref --symbolic-full-name @{u} $argv
end
