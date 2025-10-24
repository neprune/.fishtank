# Have fisher put things under a '/fisher' directory rather than mix plugin functions, conf.d and completions with system ones.
set fisher_path $__fish_config_dir/fisher

mkdir -p $fisher_path

set --query _fisher_path_initialized && exit
set --global _fisher_path_initialized

# Look at fisher completions and functions after the system ones.
set fish_complete_path $fish_complete_path[1] $fisher_path/completions $fish_complete_path[2..]
set fish_function_path $fish_function_path[1] $fisher_path/functions $fish_function_path[2..]

# Source the plugin conf.d's as long as we don't have one with the same name in the system conf.d.
for file in $fisher_path/conf.d/*.fish
    if ! test -f (string replace --regex "^.*/" $__fish_config_dir/conf.d/ -- $file)
        and test -f $file && test -r $file
        source $file
    end
end
