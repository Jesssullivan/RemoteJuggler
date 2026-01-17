# Bash completion for remote-juggler
# Source this file or install to /usr/local/etc/bash_completion.d/

_remote_juggler() {
    local cur prev words cword
    _init_completion || return

    local commands="list detect switch to validate status config token gpg debug"
    local config_commands="show add edit remove import sync"
    local token_commands="set get clear verify"
    local gpg_commands="status configure verify"
    local debug_commands="ssh-config git-config keychain"
    local options="--help --version --mode --verbose --configPath --useKeychain --gpgSign --provider"
    local providers="gitlab github bitbucket all"

    case "${prev}" in
        remote-juggler)
            COMPREPLY=( $(compgen -W "${commands} ${options}" -- "${cur}") )
            return
            ;;
        --mode)
            COMPREPLY=( $(compgen -W "cli mcp acp" -- "${cur}") )
            return
            ;;
        --provider)
            COMPREPLY=( $(compgen -W "${providers}" -- "${cur}") )
            return
            ;;
        config)
            COMPREPLY=( $(compgen -W "${config_commands}" -- "${cur}") )
            return
            ;;
        token)
            COMPREPLY=( $(compgen -W "${token_commands}" -- "${cur}") )
            return
            ;;
        gpg)
            COMPREPLY=( $(compgen -W "${gpg_commands}" -- "${cur}") )
            return
            ;;
        debug)
            COMPREPLY=( $(compgen -W "${debug_commands}" -- "${cur}") )
            return
            ;;
        switch|to|validate|edit|remove|set|get|clear|configure)
            # Complete with available identity names
            local identities=$(remote-juggler list 2>/dev/null | grep -E "^  - " | sed 's/^  - //')
            COMPREPLY=( $(compgen -W "${identities}" -- "${cur}") )
            return
            ;;
    esac

    # Default completion
    COMPREPLY=( $(compgen -W "${commands} ${options}" -- "${cur}") )
}

complete -F _remote_juggler remote-juggler
