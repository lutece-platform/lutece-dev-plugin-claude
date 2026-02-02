"""
Test runner: executes test cases declared in tests.json via Claude Agent SDK.

Each test case declares a project, prompt, and assertions.
See tests.json for the format and conftest.py for fixtures.
"""

from pathlib import Path

import pytest
from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    TextBlock,
    ToolUseBlock,
    query,
)
from claude_agent_sdk.types import SystemMessage, Message


@pytest.mark.asyncio
async def test_plugin(test_case, lutece_project, plugin_path):
    """Run a single test case from tests.json."""
    all_messages: list[Message] = []

    options = ClaudeAgentOptions(
        cwd=str(lutece_project),
        max_turns=test_case["max_turns"],
        model=test_case["model"],
        allowed_tools=test_case["allowed_tools"],
        permission_mode="bypassPermissions",
        system_prompt={"type": "preset", "preset": "claude_code"},
        setting_sources=["project"],
        plugins=[{"type": "local", "path": str(plugin_path)}],
    )

    async for msg in query(prompt=test_case["prompt"], options=options):
        all_messages.append(msg)

    # --- Assertions ---

    if "assert_file_exists" in test_case:
        for path in test_case["assert_file_exists"]:
            full = lutece_project / path
            assert full.exists(), f"Expected file not found: {path}"

    if "assert_tool_read" in test_case:
        read_paths = [
            block.input.get("file_path", "")
            for msg in all_messages
            if isinstance(msg, AssistantMessage)
            for block in msg.content
            if isinstance(block, ToolUseBlock) and block.name == "Read"
        ]
        for keyword in test_case["assert_tool_read"]:
            assert any(keyword in p for p in read_paths), (
                f"Claude never Read a file matching '{keyword}'. Reads: {read_paths}"
            )

    if "assert_tool_used" in test_case:
        tools_used = {
            block.name
            for msg in all_messages
            if isinstance(msg, AssistantMessage)
            for block in msg.content
            if isinstance(block, ToolUseBlock)
        }
        for tool in test_case["assert_tool_used"]:
            assert tool in tools_used, (
                f"Claude never used tool '{tool}'. Used: {tools_used}"
            )

    if "assert_hook_output" in test_case:
        hook_outputs = [
            msg.data.get("stdout", "")
            for msg in all_messages
            if isinstance(msg, SystemMessage) and msg.subtype == "hook_response"
        ]
        all_output = "\n".join(hook_outputs).lower()
        for keyword in test_case["assert_hook_output"]:
            assert keyword.lower() in all_output, (
                f"No hook output matching '{keyword}'. Output: {all_output[:500]}"
            )

    if "assert_skill_used" in test_case:
        skill_calls = [
            block.input.get("skill", "")
            for msg in all_messages
            if isinstance(msg, AssistantMessage)
            for block in msg.content
            if isinstance(block, ToolUseBlock) and block.name == "Skill"
        ]
        for keyword in test_case["assert_skill_used"]:
            assert any(keyword in s for s in skill_calls), (
                f"Claude never invoked Skill matching '{keyword}'. Skill calls: {skill_calls}"
            )

    if "assert_response_contains" in test_case:
        all_text = "\n".join(
            block.text
            for msg in all_messages
            if isinstance(msg, AssistantMessage)
            for block in msg.content
            if isinstance(block, TextBlock)
        ).lower()
        for keyword in test_case["assert_response_contains"]:
            assert keyword.lower() in all_text, (
                f"Response does not contain '{keyword}'. Text: {all_text[:500]}"
            )
