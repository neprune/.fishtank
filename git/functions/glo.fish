function glo --wraps='git log --oneline --graph --decorate' --description 'alias glo=git log --oneline --graph --decorate'
    git log --oneline --graph --decorate $argv
end
