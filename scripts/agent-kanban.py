#!/usr/bin/env python3
"""Conservative GitHub issue queue for Tessarchy's future AI workers."""
import argparse
import json
import os
import subprocess
import sys

STAGES = ("Backlog", "Ready", "In Progress", "Testing", "Review", "Blocked", "Done")


def github_issues(repo, limit):
    result = subprocess.run(
        ["gh", "issue", "list", "--repo", repo, "--state", "open",
         "--limit", str(limit), "--json", "number,title,labels,url,assignees"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def classify(issue):
    labels = {label["name"].lower() for label in issue.get("labels", [])}
    if any("hermes" in label or "theme" in label for label in labels):
        return "Blocked", "Protected theme work: manual approval required"
    if any("vm" in label or "hardware" in label for label in labels):
        return "Testing", "Manual VM or hardware acceptance required"
    if issue.get("assignees"):
        return "In Progress", "Already assigned; do not take ownership"
    return "Backlog", "Not automatically authorized for implementation"


def plan(issues):
    return [
        {"issue": i["number"], "title": i["title"], "url": i["url"],
         "stage": classify(i)[0], "note": classify(i)[1]}
        for i in issues
    ]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("TESSARCHY_REPO", "thediamondsaint/Tessarchy"))
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--input-json", help="Read a saved gh issue list instead of querying GitHub")
    parser.add_argument("--output", help="Write a JSON report (never changes GitHub)")
    args = parser.parse_args(argv)
    if not 1 <= args.limit <= 500:
        parser.error("--limit must be between 1 and 500")
    try:
        with open(args.input_json, encoding="utf-8") if args.input_json else __import__("contextlib").nullcontext() as f:
            issues = json.load(f) if f else github_issues(args.repo, args.limit)
        if not isinstance(issues, list):
            raise ValueError("Expected a JSON list of issues")
        report = {"repository": args.repo, "mode": "read-only", "stages": STAGES,
                  "issues": plan(issues), "worker_calls": 0, "spend_usd": 0}
        output = json.dumps(report, indent=2) + "\n"
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(output)
        else:
            print(output, end="")
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, ValueError) as exc:
        print(f"agent-kanban: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
