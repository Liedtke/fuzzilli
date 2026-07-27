#!/usr/bin/env python3

import json
import sys
import os
import subprocess
import tempfile

def run_tests_and_parse():
    if len(sys.argv) < 2:
        print("Usage: ./run_tests.py <expected_failures_file> [swift_test_args...]")
        return 1

    expected_file_path = sys.argv[1]
    test_args = sys.argv[2:]

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = os.path.join(temp_dir, "event_stream.json")
        cmd = ["swift", "test", "--event-stream-output-path", temp_path] + test_args
        print(f"Running command: {' '.join(cmd)}\n", flush=True)

        try:
            subprocess.run(cmd)
        except KeyboardInterrupt:
            print("\nTest run interrupted by user.")
            return 130

        tests_metadata = {}
        actual_failures = set()
        run_tests = set()

        for line in open(temp_path, "r").read().strip().split("\n"):
            data = json.loads(line)
            kind = data.get("kind")
            payload = data.get("payload", {})

            if kind == "test" and payload.get("kind") != "suite":
                test_id = payload.get("id")
                if test_id:
                    tests_metadata[test_id] = payload.get("name", test_id)
            elif kind == "event":
                event_kind = payload.get("kind")
                test_id = payload.get("testID")

                if event_kind in ("testStarted", "testEnded") and test_id:
                    run_tests.add(test_id)
                if event_kind == "issueRecorded":
                    issue = payload.get("issue", {})
                    if issue.get("isFailure", False) and test_id:
                        actual_failures.add(test_id)

    # Read expected failures.
    expected_failures = set()
    if os.path.exists(expected_file_path):
        with open(expected_file_path, "r") as f:
            expected_failures = {line.strip() for line in f if line.strip() and not line.strip().startswith("#")}
    else:
        print(f"Error: Expected failures file '{expected_file_path}' not found.")
        return 1

    # Map test IDs to their simple names.
    run_names = {tests_metadata[tid] for tid in run_tests if tid in tests_metadata}
    actual_failing_names = {tests_metadata[tid] for tid in actual_failures if tid in tests_metadata}

    # Calculate and print results.
    unexpected_failures = actual_failing_names - expected_failures
    unexpected_passes = (expected_failures & run_names) - actual_failing_names

    if not unexpected_failures and not unexpected_passes:
        print(f"\nAll run tests matched expectations ({len(expected_failures)} expected failure(s))")
        return 0

    for (title, unexpected) in ("Failures", unexpected_failures), ("Passes", unexpected_passes):
        if unexpected:
            print(f"\nUnexpected {title}:\n{'\n'.join(map(lambda name: f'  • {name}', sorted(unexpected)))}")

    return 1

if __name__ == "__main__":
    sys.exit(run_tests_and_parse())
