function gwipp --wraps=git\ commit\ -m\ \'wip\'\ \&\&\ git\ push --description alias\ gwipp=git\ commit\ -m\ \'wip\'\ \&\&\ git\ push
  git commit -m 'wip' && git push $argv
        
end
