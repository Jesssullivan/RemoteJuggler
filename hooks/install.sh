#!/usr/bin/env bash
# RemoteJuggler Git Hooks Installer
# Installs post-checkout hook globally or per-repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_NAME="post-checkout"
HOOK_FILE="$SCRIPT_DIR/$HOOK_NAME"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install RemoteJuggler git hooks for automatic identity switching.

OPTIONS:
    --global        Install globally for all repos (via git template)
    --local         Install in current repository only
    --repo PATH     Install in specified repository
    --uninstall     Remove hooks
    --check         Check if hooks are installed
    -h, --help      Show this help message

EXAMPLES:
    # Install globally for all new repos
    $0 --global

    # Install in current repo
    $0 --local

    # Install in specific repo
    $0 --repo ~/git/myproject

    # Check installation status
    $0 --check

    # Uninstall global hooks
    $0 --global --uninstall

GLOBAL INSTALLATION:
    Hooks are installed to ~/.git-templates/hooks/ and git is configured
    to use this template directory. All new clones and inits will have the hooks.

LOCAL INSTALLATION:
    Hooks are installed directly to .git/hooks/ in the repository.
    Only affects that specific repository.

POST-CHECKOUT HOOK:
    Runs after 'git checkout' and automatically detects the appropriate
    identity based on the repository's remote URL, then switches to it.

EOF
    exit 0
}

install_global() {
    local template_dir="$HOME/.git-templates/hooks"

    echo "Installing RemoteJuggler hooks globally..."

    # Create template directory
    mkdir -p "$template_dir"

    # Install hook
    cp "$HOOK_FILE" "$template_dir/$HOOK_NAME"
    chmod +x "$template_dir/$HOOK_NAME"

    # Configure git to use template
    git config --global init.templateDir "$HOME/.git-templates"

    echo "✅ Global hooks installed to: $template_dir"
    echo "ℹ️  All new 'git clone' and 'git init' will include the hooks"
    echo "ℹ️  To add to existing repos, run: $0 --local"
}

install_local() {
    local repo_path="${1:-.}"

    # Check if we're in a git repository
    if [ ! -d "$repo_path/.git" ]; then
        echo "❌ Error: $repo_path is not a git repository"
        exit 1
    fi

    local hooks_dir="$repo_path/.git/hooks"

    echo "Installing RemoteJuggler hooks in: $repo_path"

    # Install hook
    cp "$HOOK_FILE" "$hooks_dir/$HOOK_NAME"
    chmod +x "$hooks_dir/$HOOK_NAME"

    echo "✅ Hooks installed to: $hooks_dir"
}

uninstall_global() {
    local template_dir="$HOME/.git-templates/hooks"

    echo "Uninstalling RemoteJuggler global hooks..."

    if [ -f "$template_dir/$HOOK_NAME" ]; then
        rm "$template_dir/$HOOK_NAME"
        echo "✅ Removed: $template_dir/$HOOK_NAME"
    else
        echo "ℹ️  Hook not found: $template_dir/$HOOK_NAME"
    fi

    # Check if template dir is empty
    if [ -d "$template_dir" ] && [ -z "$(ls -A "$template_dir")" ]; then
        rmdir "$template_dir"
        echo "✅ Removed empty hooks directory"
    fi

    # Don't unset init.templateDir as user might have other hooks
    echo "ℹ️  git init.templateDir still set to: $(git config --global init.templateDir)"
}

uninstall_local() {
    local repo_path="${1:-.}"
    local hooks_dir="$repo_path/.git/hooks"

    if [ -f "$hooks_dir/$HOOK_NAME" ]; then
        # Check if it's our hook
        if grep -q "RemoteJuggler" "$hooks_dir/$HOOK_NAME" 2>/dev/null; then
            rm "$hooks_dir/$HOOK_NAME"
            echo "✅ Removed: $hooks_dir/$HOOK_NAME"
        else
            echo "⚠️  Warning: $hooks_dir/$HOOK_NAME exists but is not a RemoteJuggler hook"
            echo "    Skipping removal to preserve custom hook"
        fi
    else
        echo "ℹ️  Hook not found: $hooks_dir/$HOOK_NAME"
    fi
}

check_installation() {
    echo "Checking RemoteJuggler hooks installation..."
    echo

    # Check global
    local template_dir="$(git config --global init.templateDir)"
    if [ -n "$template_dir" ] && [ -f "$template_dir/hooks/$HOOK_NAME" ]; then
        echo "✅ Global hooks: INSTALLED"
        echo "   Template: $template_dir"
    else
        echo "❌ Global hooks: NOT INSTALLED"
    fi

    echo

    # Check local (current directory)
    if [ -d ".git" ]; then
        if [ -f ".git/hooks/$HOOK_NAME" ]; then
            if grep -q "RemoteJuggler" ".git/hooks/$HOOK_NAME" 2>/dev/null; then
                echo "✅ Local hooks (current repo): INSTALLED"
            else
                echo "⚠️  Local hooks (current repo): CUSTOM HOOK DETECTED"
            fi
        else
            echo "❌ Local hooks (current repo): NOT INSTALLED"
        fi
    else
        echo "ℹ️  Not in a git repository"
    fi
}

# Parse arguments
MODE=""
REPO_PATH=""
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --global)
            MODE="global"
            shift
            ;;
        --local)
            MODE="local"
            shift
            ;;
        --repo)
            MODE="local"
            REPO_PATH="$2"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --check)
            check_installation
            exit 0
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Require a mode
if [ -z "$MODE" ]; then
    echo "Error: Must specify --global or --local"
    echo "Run with --help for usage information"
    exit 1
fi

# Execute
if [ "$UNINSTALL" = true ]; then
    if [ "$MODE" = "global" ]; then
        uninstall_global
    else
        uninstall_local "$REPO_PATH"
    fi
else
    if [ "$MODE" = "global" ]; then
        install_global
    else
        install_local "$REPO_PATH"
    fi
fi
