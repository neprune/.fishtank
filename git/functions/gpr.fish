function gpr --wraps='gh pr create' --description 'alias gpr=gh pr create'
    gh pr create $argv
end
