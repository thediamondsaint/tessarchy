# Agent Kanban MVP

This is a **read-only queue prototype**, not an autonomous coding service. It does
not create a GitHub Projects board, spend model credits, call an LLM, modify
issues, push branches or merge PRs. It is a safe starting point for an
owner-approved multi-agent system.

## Inspect the queue

Install and authenticate GitHub CLI (`gh auth login`) on your own machine.
Run:

```sh
python3 scripts/agent-kanban.py --output /tmp/tessarchy-queue.json
python3 -m unittest discover -s tests -p 'test_agent_kanban.py' -v
```

The report is JSON, with Kanban stage suggestions. Labels mentioning themes or
Hermes are protected. VM and hardware labels are flagged for manual testing.
Already assigned issues are not claimed. All other open issues remain Backlog:
no issue is automatically safe for AI implementation.

## Proposed next stage (requires explicit approval and provider configuration)

1. Choose a GitHub Projects board and authorize creation with the correct account.
2. Add a small planning manager triggered only on new/changed Ready issues.
3. Add one sequential worker using a **separately billed** model provider, never
   the owner's ChatGPT subscription. Store tokens only in encrypted secrets.
4. Enforce provider-side spending limits where supported; track local estimates,
   cap each task at two attempts and stop on uncertainty or budget exhaustion.
5. Use isolated worktrees and focused PRs; run `./scripts/check.sh`, log actual
   tests, and require human review before merge.
6. Require VM acceptance for GUI work and physical-device acceptance for
   hardware changes. Never modify Hermes's unmerged theme work.
7. Host the dispatcher on a suitable cloud runner so the MacBook can be off.
   Compare actual hosting, inference and storage costs against the $30/month cap.

Do not assume a local budget counter can prevent provider charges after network
errors or concurrent workers. Use provider hard limits where available.
