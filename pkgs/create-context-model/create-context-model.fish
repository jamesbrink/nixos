function __create_context_model_models
    ollama list 2>/dev/null | awk 'NR > 1 { print $1 }'
end

complete -c create-context-model -f -n '__fish_is_first_arg' -a '(__create_context_model_models)' -d 'Source model'
complete -c create-context-model -f -n 'set -l args (commandline -opc); test (count $args) -eq 2' -a '4 8 16 32 64 128 256' -d 'Context size in K'
complete -c create-context-model -s h -l help -d 'Show help'

complete -c create_context_model.sh -f -n '__fish_is_first_arg' -a '(__create_context_model_models)' -d 'Source model'
complete -c create_context_model.sh -f -n 'set -l args (commandline -opc); test (count $args) -eq 2' -a '4 8 16 32 64 128 256' -d 'Context size in K'
complete -c create_context_model.sh -s h -l help -d 'Show help'
