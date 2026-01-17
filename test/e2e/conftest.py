"""
RemoteJuggler E2E Test Fixtures

Provides pytest fixtures for end-to-end testing of RemoteJuggler
identity switching and MCP protocol compliance.
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Generator, Optional

import pytest


# Path to the RemoteJuggler binary
REMOTE_JUGGLER_BIN = os.environ.get(
    "REMOTE_JUGGLER_BIN",
    str(Path(__file__).parent.parent.parent / "target" / "release" / "remote_juggler")
)


@pytest.fixture
def temp_git_repo() -> Generator[Path, None, None]:
    """Create a temporary git repository for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        repo_path = Path(tmpdir) / "test-repo"
        repo_path.mkdir()

        # Initialize git repo
        subprocess.run(
            ["git", "init"],
            cwd=repo_path,
            check=True,
            capture_output=True
        )

        # Configure minimal git settings
        subprocess.run(
            ["git", "config", "user.name", "Test User"],
            cwd=repo_path,
            check=True,
            capture_output=True
        )
        subprocess.run(
            ["git", "config", "user.email", "test@example.com"],
            cwd=repo_path,
            check=True,
            capture_output=True
        )

        # Add a remote (using a placeholder)
        subprocess.run(
            ["git", "remote", "add", "origin", "git@gitlab-personal:test/repo.git"],
            cwd=repo_path,
            check=True,
            capture_output=True
        )

        yield repo_path


@pytest.fixture
def temp_config_dir() -> Generator[Path, None, None]:
    """Create a temporary config directory with test identities."""
    with tempfile.TemporaryDirectory() as tmpdir:
        config_dir = Path(tmpdir) / ".config" / "remote-juggler"
        config_dir.mkdir(parents=True)

        # Create test config
        config = {
            "version": "2.0.0",
            "identities": {
                "personal": {
                    "provider": "gitlab",
                    "host": "gitlab-personal",
                    "hostname": "gitlab.com",
                    "user": "personaluser",
                    "email": "personal@example.com",
                    "identityFile": "~/.ssh/id_ed25519_personal"
                },
                "work": {
                    "provider": "gitlab",
                    "host": "gitlab-work",
                    "hostname": "gitlab.com",
                    "user": "workuser",
                    "email": "work@company.com",
                    "identityFile": "~/.ssh/id_ed25519_work",
                    "gpg": {
                        "keyId": "ABCD1234",
                        "signCommits": True
                    }
                },
                "github": {
                    "provider": "github",
                    "host": "github.com",
                    "hostname": "github.com",
                    "user": "githubuser",
                    "email": "github@example.com",
                    "identityFile": "~/.ssh/id_ed25519_github"
                }
            },
            "settings": {
                "defaultProvider": "gitlab",
                "autoDetect": True,
                "useKeychain": False,
                "gpgSign": True
            }
        }

        config_file = config_dir / "config.json"
        config_file.write_text(json.dumps(config, indent=2))

        yield config_dir


@pytest.fixture
def juggler_env(temp_config_dir: Path) -> dict:
    """Create environment with custom config path."""
    env = os.environ.copy()
    env["HOME"] = str(temp_config_dir.parent.parent)
    env["REMOTE_JUGGLER_CONFIG"] = str(temp_config_dir / "config.json")
    return env


def run_juggler(
    args: list[str],
    env: Optional[dict] = None,
    cwd: Optional[Path] = None,
    input_data: Optional[str] = None
) -> subprocess.CompletedProcess:
    """Run RemoteJuggler with given arguments."""
    cmd = [REMOTE_JUGGLER_BIN] + args

    return subprocess.run(
        cmd,
        env=env or os.environ,
        cwd=cwd,
        capture_output=True,
        text=True,
        input=input_data
    )


def run_mcp_request(
    request: dict,
    env: Optional[dict] = None
) -> dict:
    """Send a JSON-RPC request to RemoteJuggler MCP server."""
    request_str = json.dumps(request) + "\n"

    result = run_juggler(
        ["--mode=mcp"],
        env=env,
        input_data=request_str
    )

    # Parse the response (skip any debug output on stderr)
    if result.stdout:
        for line in result.stdout.strip().split("\n"):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue

    return {}


@pytest.fixture
def mcp_env(temp_config_dir: Path) -> dict:
    """Environment for MCP server testing."""
    env = os.environ.copy()
    env["HOME"] = str(temp_config_dir.parent.parent)
    return env
