import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "agent-kanban.py"
spec = importlib.util.spec_from_file_location("agent_kanban", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class KanbanTests(unittest.TestCase):
    def test_unassigned_is_backlog(self):
        self.assertEqual(module.classify({"labels": [], "assignees": []})[0], "Backlog")

    def test_protect_theme(self):
        issue = {"labels": [{"name": "theme-engine"}], "assignees": []}
        self.assertEqual(module.classify(issue)[0], "Blocked")

    def test_hardware_needs_testing(self):
        issue = {"labels": [{"name": "hardware"}], "assignees": []}
        self.assertEqual(module.classify(issue)[0], "Testing")

    def test_assigned_is_not_claimed(self):
        issue = {"labels": [], "assignees": [{"login": "someone"}]}
        self.assertEqual(module.classify(issue)[0], "In Progress")
