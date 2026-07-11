function remove_path
  if set -l index (contains -i "$argv" $PATH)
    set -e PATH[$index]
    echo "Removed $argv from the path"
  else
    echo "$argv not found in path"
    return 1
  end
end
