_create_context_model() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=()

  case "$COMP_CWORD" in
    1)
      mapfile -t COMPREPLY < <(compgen -W "$(ollama list 2>/dev/null | awk 'NR > 1 { print $1 }')" -- "$cur")
      ;;
    2)
      mapfile -t COMPREPLY < <(compgen -W "4 8 16 32 64 128 256" -- "$cur")
      ;;
  esac
}

complete -F _create_context_model create-context-model create_context_model.sh
