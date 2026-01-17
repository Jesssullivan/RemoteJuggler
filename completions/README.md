# Shell Completions for RemoteJuggler

Tab completion support for bash, zsh, and fish shells.

## Installation

### Bash

```bash
# System-wide (requires sudo)
sudo cp completions/remote-juggler.bash /etc/bash_completion.d/

# User-specific
mkdir -p ~/.local/share/bash-completion/completions
cp completions/remote-juggler.bash ~/.local/share/bash-completion/completions/remote-juggler

# Enable immediately
source completions/remote-juggler.bash
```

Add to `~/.bashrc`:
```bash
if [ -f ~/.local/share/bash-completion/completions/remote-juggler ]; then
    source ~/.local/share/bash-completion/completions/remote-juggler
fi
```

### Zsh

```bash
# System-wide (requires sudo)
sudo cp completions/_remote-juggler /usr/local/share/zsh/site-functions/

# User-specific
mkdir -p ~/.zsh/completions
cp completions/_remote-juggler ~/.zsh/completions/

# Add to fpath in ~/.zshrc (before compinit)
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

To rebuild completion cache:
```zsh
rm -f ~/.zcompdump
compinit
```

### Fish

```bash
# User-specific (recommended)
mkdir -p ~/.config/fish/completions
cp completions/remote-juggler.fish ~/.config/fish/completions/

# System-wide (requires sudo)
sudo cp completions/remote-juggler.fish /usr/share/fish/vendor_completions.d/
```

Fish automatically loads completions from these directories.

## Homebrew Installation

If you installed via Homebrew, completions are automatically installed:

```bash
# Bash
source $(brew --prefix)/etc/bash_completion.d/remote-juggler.bash

# Zsh (add to ~/.zshrc)
fpath=($(brew --prefix)/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit

# Fish (auto-loaded)
# No action needed
```

## Features

All shells support:

- Command completion: `remote-juggler <TAB>`
- Subcommand completion: `remote-juggler config <TAB>`
- Identity name completion: `remote-juggler switch <TAB>`
- Option completion: `remote-juggler --<TAB>`
- Provider completion: `remote-juggler --provider <TAB>`

### Examples

```bash
# List available commands
remote-juggler <TAB>

# Complete identity names
remote-juggler switch <TAB>

# Complete config subcommands
remote-juggler config <TAB>

# Complete options
remote-juggler --<TAB>
```

## Testing

Test completions are working:

```bash
# Bash/Zsh
remote-juggler sw<TAB>    # Should complete to "switch"
remote-juggler switch <TAB>   # Should list identities

# Fish
remote-juggler sw<TAB>    # Should show "switch" suggestion
remote-juggler switch <TAB>   # Should list available identities
```

## Troubleshooting

### Bash completions not working

1. Check bash-completion is installed: `brew install bash-completion`
2. Verify sourcing in ~/.bashrc: `grep bash-completion ~/.bashrc`
3. Restart shell or source: `source ~/.bashrc`

### Zsh completions not working

1. Check fpath includes completion directory: `echo $fpath`
2. Rebuild completion cache: `rm ~/.zcompdump && compinit`
3. Verify file permissions: `ls -la ~/.zsh/completions/_remote-juggler`

### Fish completions not working

1. Check completion file location: `ls ~/.config/fish/completions/`
2. Reload completions: `fish_update_completions`
3. Test function: `functions __remote_juggler_identities`

## Dynamic Identity Completion

Identity name completion is dynamic - it calls `remote-juggler list` to get the current list. If the CLI is slow or unavailable, completion may be delayed or empty.

To improve performance, ensure `remote-juggler list` executes quickly:
```bash
time remote-juggler list
```

## Uninstallation

```bash
# Bash
rm ~/.local/share/bash-completion/completions/remote-juggler
# or
sudo rm /etc/bash_completion.d/remote-juggler.bash

# Zsh
rm ~/.zsh/completions/_remote-juggler
# or
sudo rm /usr/local/share/zsh/site-functions/_remote-juggler

# Fish
rm ~/.config/fish/completions/remote-juggler.fish
# or
sudo rm /usr/share/fish/vendor_completions.d/remote-juggler.fish
```
