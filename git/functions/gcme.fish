function gcme --wraps='git commit --message' --description 'alias gcme=git commit --message'
  git commit --message $argv
        
end
