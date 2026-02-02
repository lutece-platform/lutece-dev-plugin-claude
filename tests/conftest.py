"""Shared fixtures for plugin tests."""

import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import pytest

TEST_DIR = Path(__file__).resolve().parent
PLUGIN_ROOT = TEST_DIR.parent
TESTS_JSON = TEST_DIR / "tests.json"
REPORT_PATH = PLUGIN_ROOT / "TEST_REPORT.md"

GIT_ENV = {
    **os.environ,
    "GIT_AUTHOR_NAME": "test",
    "GIT_AUTHOR_EMAIL": "t@t",
    "GIT_COMMITTER_NAME": "test",
    "GIT_COMMITTER_EMAIL": "t@t",
}

# Defaults for optional fields
DEFAULTS = {
    "model": "haiku",
    "max_turns": 10,
    "allowed_tools": ["Read", "Glob"],
}


def load_test_cases() -> list[dict]:
    """Load test declarations from tests.json."""
    with open(TESTS_JSON) as f:
        cases = json.load(f)
    # Apply defaults
    for case in cases:
        for key, default in DEFAULTS.items():
            case.setdefault(key, default)
    return cases


def pytest_generate_tests(metafunc):
    """Parametrize tests from tests.json."""
    if "test_case" in metafunc.fixturenames:
        cases = load_test_cases()
        metafunc.parametrize(
            "test_case",
            cases,
            ids=[c["name"] for c in cases],
        )


@pytest.fixture
def lutece_project(test_case, tmp_path):
    """Copy the declared project into tmp and git init it."""
    project_src = TEST_DIR / "fixtures" / test_case["project"]
    project = tmp_path / test_case["project"]
    shutil.copytree(project_src, project)

    subprocess.run(["git", "init"], cwd=project, capture_output=True)
    subprocess.run(["git", "add", "."], cwd=project, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", "init", "--no-gpg-sign"],
        cwd=project, capture_output=True, env=GIT_ENV,
    )
    return project


@pytest.fixture
def plugin_path():
    """Path to the lutecepowers plugin root."""
    return PLUGIN_ROOT


def pytest_terminal_summary(terminalreporter, exitstatus, config):
    """Write TEST_REPORT.md after all tests complete."""
    passed = terminalreporter.stats.get("passed", [])
    failed = terminalreporter.stats.get("failed", [])
    total = len(passed) + len(failed)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    all_reports = passed + failed
    elapsed = sum(r.duration for r in all_reports)

    cases = load_test_cases()
    case_map = {c["name"]: c for c in cases}

    # Build results grouped by type
    results = {}
    for report in passed:
        name = report.nodeid.split("[")[-1].rstrip("]")
        case = case_map.get(name, {})
        typ = case.get("type", "other")
        results.setdefault(typ, []).append((name, case, "PASS"))
    for report in failed:
        name = report.nodeid.split("[")[-1].rstrip("]")
        case = case_map.get(name, {})
        typ = case.get("type", "other")
        msg = str(report.longrepr).split("\n")[-1][:80] if report.longrepr else ""
        results.setdefault(typ, []).append((name, case, f"FAIL: {msg}"))

    lines = [
        f"# Test Report",
        f"",
        f"**Date:** {now}",
        f"**Result:** {len(passed)}/{total} passed",
        f"**Duration:** {elapsed:.1f}s",
    ]

    for typ, entries in results.items():
        type_passed = sum(1 for _, _, s in entries if s == "PASS")
        lines.append(f"")
        lines.append(f"## {typ} ({type_passed}/{len(entries)})")
        lines.append(f"")
        lines.append(f"| Test | Description | Status |")
        lines.append(f"|------|-------------|--------|")
        for name, case, status in entries:
            desc = case.get("description", "")
            lines.append(f"| {name} | {desc} | {status} |")

    lines.append("")
    REPORT_PATH.write_text("\n".join(lines))
