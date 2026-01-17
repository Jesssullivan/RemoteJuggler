# RemoteJuggler Git Hooks

Automatic identity switching via git hooks. When you checkout a branch or clone a repository, RemoteJuggler detects the appropriate identity and switches to it automatically.

## Quick Start

### Global Installation (Recommended)

Install hooks for all future repositories:

```bash
./hooks/install.sh --global
```

After this, every `git clone` and `git init` will include the RemoteJuggler hooks.

### Local Installation

Install hooks for current repository only:

```bash
cd /path/to/your/repo
/path/to/remote-juggler/hooks/install.sh --local
```

Or specify a repository path:

```bash
./hooks/install.sh --repo ~/git/myproject
```

## How It Works

### post-checkout Hook

Runs after `git checkout <branch>` and automatically:

1. Detects the repository's remote URL
2. Matches it against configured identities
3. Switches to the appropriate identity
4. Updates git user.name and user.email

**Example:**

```bash
$ git checkout feature-branch
Switched to branch 'feature-branch'
[RemoteJuggler] Detected identity: personal
[RemoteJuggler] Switched to: personal (xoxdjess <jess@sulliwood.org>)
```

### When Hooks Trigger

- ✅ `git checkout <branch>` - Branch switching
- ✅ `git clone <url>` - After clone completes (if global hooks installed)
- ✅ `git worktree add` - New worktree creation
- ❌ File-level checkouts (e.g., `git checkout -- file.txt`) - Skipped for performance

## Installation Options

### Global (Template-Based)

Hooks are installed to `~/.git-templates/hooks/` and git is configured to use this template directory.

**Advantages:**
- Automatic for all new repositories
- One-time setup
- Works with `git clone`

**Command:**
```bash
./hooks/install.sh --global
```

**Git Configuration:**
```bash
git config --global init.templateDir ~/.git-templates
```

### Local (Per-Repository)

Hooks are installed directly to `.git/hooks/` in a specific repository.

**Advantages:**
- Opt-in per repository
- No global configuration changes
- Explicit control

**Command:**
```bash
# Current directory
./hooks/install.sh --local

# Specific repo
./hooks/install.sh --repo ~/git/myproject
```

## Checking Installation

```bash
./hooks/install.sh --check
```

Output example:
```
Checking RemoteJuggler hooks installation...

✅ Global hooks: INSTALLED
   Template: /Users/you/.git-templates

✅ Local hooks (current repo): INSTALLED
```

## Uninstallation

### Remove Global Hooks

```bash
./hooks/install.sh --global --uninstall
```

This removes hooks from `~/.git-templates/hooks/` but preserves the `init.templateDir` setting in case you have other hooks.

### Remove Local Hooks

```bash
# Current directory
./hooks/install.sh --local --uninstall

# Specific repo
./hooks/install.sh --repo ~/git/myproject --uninstall
```

The uninstaller checks if the hook is a RemoteJuggler hook before removing it, preserving any custom hooks you may have.

## Advanced Usage

### Add to Existing Repositories

If you install global hooks, they only apply to new `git clone` and `git init` operations. To add them to existing repositories:

```bash
# Install in all repos under ~/git
for repo in ~/git/*; do
    if [ -d "$repo/.git" ]; then
        ./hooks/install.sh --repo "$repo"
    fi
done
```

### Custom Hook Behavior

The hooks respect these environment variables:

```bash
# Disable RemoteJuggler hooks temporarily
export REMOTE_JUGGLER_HOOKS_DISABLED=1
git checkout main  # Hook will not run

# Verbose output
export REMOTE_JUGGLER_VERBOSE=1
git checkout main  # Shows detailed identity detection
```

### Combining with Existing Hooks

If you already have a `post-checkout` hook, you can call RemoteJuggler from it:

```bash
#!/usr/bin/env bash
# Your existing post-checkout hook

# Your existing logic
echo "Running custom hook logic..."

# Call RemoteJuggler
if command -v remote-juggler &> /dev/null; then
    remote-juggler detect --auto-switch --quiet || true
fi

# More of your logic
echo "Continuing with rest of hook..."
```

## Troubleshooting

### Hooks not running

1. **Check if hooks are executable:**
   ```bash
   ls -la .git/hooks/post-checkout
   ```
   Should show `rwxr-xr-x`. If not:
   ```bash
   chmod +x .git/hooks/post-checkout
   ```

2. **Check if hook is installed:**
   ```bash
   ./hooks/install.sh --check
   ```

3. **Test hook manually:**
   ```bash
   ./.git/hooks/post-checkout 0 0 1
   ```

### Identity not switching

1. **Check if remote-juggler is in PATH:**
   ```bash
   which remote-juggler
   ```

2. **Test detection manually:**
   ```bash
   remote-juggler detect
   ```

3. **Enable verbose mode:**
   ```bash
   export REMOTE_JUGGLER_VERBOSE=1
   git checkout main
   ```

### Hook interfering with workflow

Temporarily disable:

```bash
# Disable for current shell session
export REMOTE_JUGGLER_HOOKS_DISABLED=1

# Or rename the hook
mv .git/hooks/post-checkout .git/hooks/post-checkout.disabled
```

## Security Considerations

### Hook Safety

- Hooks are shell scripts that run with your permissions
- Review `post-checkout` before installation
- The hook only runs `remote-juggler detect`, which is read-only
- No network requests or destructive operations

### Shared Repositories

If you commit `.git/hooks/` to version control (uncommon but possible with git worktrees):

- Each team member needs RemoteJuggler installed
- Configure identity names to match across team members
- Or use environment variable to disable: `REMOTE_JUGGLER_HOOKS_DISABLED=1`

## Performance

The post-checkout hook adds ~50-200ms to checkout operations:
- Detection: ~20ms (parsing remote URL)
- Switch operation: ~50-150ms (updating git config, authenticating)

This is negligible for typical workflows but can be disabled for scripted mass checkouts.

## Integration with CI/CD

Hooks don't interfere with CI/CD:
- They check for `remote-juggler` availability first
- Exit silently if not found
- Don't fail the checkout operation

## Examples

### Scenario 1: Work on multiple forks

```bash
# Install globally
./hooks/install.sh --global

# Clone work repo
git clone git@gitlab-work:company/project.git
# → Auto-switches to "work" identity

# Clone personal fork
git clone git@gitlab-personal:yourusername/project.git
# → Auto-switches to "personal" identity
```

### Scenario 2: Multiple remotes

```bash
# Add work remote to personal repo
cd myproject
git remote add work git@gitlab-work:company/myproject.git

# Checkout branch
git checkout main
# → Still uses "personal" (based on origin remote)

# Fetch from work
git fetch work
git checkout -b work-feature work/main
# → Still uses "personal" (only origin triggers identity detection)
```

## Future Enhancements

Planned improvements:

- `pre-push` hook for identity verification before push
- `prepare-commit-msg` hook for automatic co-author attribution
- Configuration option for strict mode (fail checkout if identity unknown)
- Support for per-branch identity overrides

## Related Commands

```bash
# View current identity
remote-juggler status

# List all identities
remote-juggler list

# Manually switch
remote-juggler switch personal

# Detect without switching
remote-juggler detect

# Validate identity
remote-juggler validate personal
```

## See Also

- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
- [RemoteJuggler CLI Documentation](../README.md)
- [Identity Configuration Guide](../docs/getting-started/configuration.md)
