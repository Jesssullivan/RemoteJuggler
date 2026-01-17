# Fish completion for remote-juggler
# Install to ~/.config/fish/completions/remote-juggler.fish

# Disable file completion by default
complete -c remote-juggler -f

# Options
complete -c remote-juggler -l help -d "Show help message"
complete -c remote-juggler -l version -d "Show version"
complete -c remote-juggler -l verbose -d "Enable verbose output"
complete -c remote-juggler -l mode -d "Operation mode" -xa "cli mcp acp"
complete -c remote-juggler -l configPath -d "Override config file path" -r
complete -c remote-juggler -l useKeychain -d "Enable/disable keychain"
complete -c remote-juggler -l gpgSign -d "Enable/disable GPG signing"
complete -c remote-juggler -l provider -d "Filter by provider" -xa "gitlab github bitbucket all"

# Commands
complete -c remote-juggler -n "__fish_use_subcommand" -a "list" -d "List all configured identities"
complete -c remote-juggler -n "__fish_use_subcommand" -a "detect" -d "Detect identity for current repository"
complete -c remote-juggler -n "__fish_use_subcommand" -a "switch" -d "Switch to specified identity"
complete -c remote-juggler -n "__fish_use_subcommand" -a "to" -d "Alias for switch"
complete -c remote-juggler -n "__fish_use_subcommand" -a "validate" -d "Test SSH/API connectivity"
complete -c remote-juggler -n "__fish_use_subcommand" -a "status" -d "Show current identity status"
complete -c remote-juggler -n "__fish_use_subcommand" -a "config" -d "Configuration management"
complete -c remote-juggler -n "__fish_use_subcommand" -a "token" -d "Token management"
complete -c remote-juggler -n "__fish_use_subcommand" -a "gpg" -d "GPG signing management"
complete -c remote-juggler -n "__fish_use_subcommand" -a "debug" -d "Debug utilities"

# Config subcommands
complete -c remote-juggler -n "__fish_seen_subcommand_from config" -a "show" -d "Display configuration"
complete -c remote-juggler -n "__fish_seen_subcommand_from config" -a "add" -d "Add new identity"
complete -c remote-juggler -n "__fish_seen_subcommand_from config" -a "edit" -d "Edit existing identity"
complete -c remote-juggler -n "__fish_seen_subcommand_from config" -a "remove" -d "Remove identity"
complete -c remote-juggler -n "__fish_seen_subcommand_from config" -a "import" -d "Import from SSH config"
complete -c remote-juggler -n "__fish_seen_subcommand_from config" -a "sync" -d "Sync managed blocks"

# Token subcommands
complete -c remote-juggler -n "__fish_seen_subcommand_from token" -a "set" -d "Store token in keychain"
complete -c remote-juggler -n "__fish_seen_subcommand_from token" -a "get" -d "Retrieve token"
complete -c remote-juggler -n "__fish_seen_subcommand_from token" -a "clear" -d "Remove token"
complete -c remote-juggler -n "__fish_seen_subcommand_from token" -a "verify" -d "Test all credentials"

# GPG subcommands
complete -c remote-juggler -n "__fish_seen_subcommand_from gpg" -a "status" -d "Show GPG configuration"
complete -c remote-juggler -n "__fish_seen_subcommand_from gpg" -a "configure" -d "Configure GPG for identity"
complete -c remote-juggler -n "__fish_seen_subcommand_from gpg" -a "verify" -d "Check provider registration"

# Debug subcommands
complete -c remote-juggler -n "__fish_seen_subcommand_from debug" -a "ssh-config" -d "Show parsed SSH config"
complete -c remote-juggler -n "__fish_seen_subcommand_from debug" -a "git-config" -d "Show parsed gitconfig"
complete -c remote-juggler -n "__fish_seen_subcommand_from debug" -a "keychain" -d "Test keychain access"

# Identity name completion for commands that need it
function __remote_juggler_identities
    remote-juggler list 2>/dev/null | grep -E '^  - ' | sed 's/^  - //'
end

complete -c remote-juggler -n "__fish_seen_subcommand_from switch to validate" -a "(__remote_juggler_identities)"
complete -c remote-juggler -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from edit remove" -a "(__remote_juggler_identities)"
complete -c remote-juggler -n "__fish_seen_subcommand_from token; and __fish_seen_subcommand_from set get clear" -a "(__remote_juggler_identities)"
complete -c remote-juggler -n "__fish_seen_subcommand_from gpg; and __fish_seen_subcommand_from configure" -a "(__remote_juggler_identities)"
