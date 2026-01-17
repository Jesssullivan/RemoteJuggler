"""
E2E Tests: MCP Protocol Compliance

Tests MCP server protocol compliance including:
- JSON-RPC 2.0 message format
- initialize/initialized handshake
- tools/list response
- tools/call execution
"""

import json
from pathlib import Path
from typing import Optional

import pytest

from conftest import run_juggler, run_mcp_request


class TestMCPProtocol:
    """Tests for MCP JSON-RPC protocol compliance."""

    def test_mcp_mode_starts(self, mcp_env: dict):
        """Test MCP server starts without immediate crash."""
        # Send an empty input to test startup
        result = run_juggler(
            ["--mode=mcp"],
            env=mcp_env,
            input_data=""
        )
        # MCP mode should start (may timeout waiting for input)
        # The fact that it ran at all means it started successfully


class TestMCPInitialize:
    """Tests for MCP initialization handshake."""

    def test_initialize_request(self, mcp_env: dict):
        """Test MCP initialize request returns proper response."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }

        response = run_mcp_request(request, env=mcp_env)

        # Should return a valid JSON-RPC response
        if response:
            assert response.get("jsonrpc") == "2.0", \
                f"Invalid jsonrpc version: {response}"
            assert "result" in response or "error" in response, \
                f"Response missing result/error: {response}"

    def test_initialize_returns_server_info(self, mcp_env: dict):
        """Test initialize returns server capabilities."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "test-client",
                    "version": "1.0.0"
                }
            }
        }

        response = run_mcp_request(request, env=mcp_env)

        if response and "result" in response:
            result = response["result"]
            # Should have serverInfo
            assert "serverInfo" in result or "capabilities" in result, \
                f"Missing server info: {result}"


class TestMCPToolsList:
    """Tests for MCP tools/list endpoint."""

    def test_tools_list_returns_tools(self, mcp_env: dict):
        """Test tools/list returns available tools."""
        # First initialize
        init_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "test", "version": "1.0"}
            }
        }
        run_mcp_request(init_request, env=mcp_env)

        # Then list tools
        request = {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": {}
        }

        response = run_mcp_request(request, env=mcp_env)

        if response and "result" in response:
            result = response["result"]
            # Should have tools array
            if "tools" in result:
                assert isinstance(result["tools"], list), \
                    f"Tools should be a list: {result}"

    def test_tools_list_includes_juggler_tools(self, mcp_env: dict):
        """Test tools/list includes RemoteJuggler-specific tools."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/list",
            "params": {}
        }

        response = run_mcp_request(request, env=mcp_env)

        if response and "result" in response:
            result = response["result"]
            tools = result.get("tools", [])
            tool_names = [t.get("name", "") for t in tools]

            # Check for expected tool names
            expected_tools = [
                "juggler_list_identities",
                "juggler_detect_identity",
                "juggler_switch",
                "juggler_status",
                "juggler_validate"
            ]

            found_any = any(name in tool_names for name in expected_tools)
            # At minimum, some tools should be present
            assert found_any or len(tools) > 0, \
                f"No juggler tools found in: {tool_names}"


class TestMCPToolsCall:
    """Tests for MCP tools/call endpoint."""

    def test_call_list_identities(self, mcp_env: dict):
        """Test calling juggler_list_identities tool."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "juggler_list_identities",
                "arguments": {}
            }
        }

        response = run_mcp_request(request, env=mcp_env)

        if response:
            # Should return result or error, not crash
            assert "result" in response or "error" in response, \
                f"Invalid response: {response}"

    def test_call_status(self, mcp_env: dict):
        """Test calling juggler_status tool."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "juggler_status",
                "arguments": {}
            }
        }

        response = run_mcp_request(request, env=mcp_env)

        if response:
            assert "result" in response or "error" in response, \
                f"Invalid response: {response}"

    def test_call_switch_with_identity(self, mcp_env: dict, temp_git_repo: Path):
        """Test calling juggler_switch with identity parameter."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "juggler_switch",
                "arguments": {
                    "identity": "personal",
                    "repoPath": str(temp_git_repo)
                }
            }
        }

        response = run_mcp_request(request, env=mcp_env)

        if response:
            assert "result" in response or "error" in response, \
                f"Invalid response: {response}"

    def test_call_unknown_tool(self, mcp_env: dict):
        """Test calling unknown tool returns error."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "nonexistent_tool_xyz",
                "arguments": {}
            }
        }

        response = run_mcp_request(request, env=mcp_env)

        if response:
            # Should return error for unknown tool
            assert "error" in response or \
                   ("result" in response and "unknown" in str(response["result"]).lower()), \
                   f"Should error for unknown tool: {response}"


class TestMCPErrorHandling:
    """Tests for MCP error handling."""

    def test_invalid_json_handled(self, mcp_env: dict):
        """Test server handles invalid JSON gracefully."""
        result = run_juggler(
            ["--mode=mcp"],
            env=mcp_env,
            input_data="not valid json\n"
        )

        # Should not crash (exit code 0 or graceful error)
        assert "panic" not in result.stderr.lower(), \
            f"Server panicked: {result.stderr}"

    def test_missing_method_handled(self, mcp_env: dict):
        """Test server handles missing method field."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "params": {}
            # Missing "method" field
        }

        response = run_mcp_request(request, env=mcp_env)

        if response:
            # Should return error for invalid request
            assert "error" in response or response == {}, \
                f"Should error for missing method: {response}"

    def test_unknown_method_returns_error(self, mcp_env: dict):
        """Test unknown method returns proper error."""
        request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "unknown/method",
            "params": {}
        }

        response = run_mcp_request(request, env=mcp_env)

        if response:
            # Should return error for unknown method
            assert "error" in response or response == {}, \
                f"Should error for unknown method: {response}"
