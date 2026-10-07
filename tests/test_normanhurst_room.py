import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAP = ROOT / "normanhurst/maps/001-first-room.json"
if not MAP.exists():
    MAP = ROOT / "game-source/001-first-room.json"


class NormanhurstRoomTests(unittest.TestCase):
    def setUp(self):
        self.room = json.loads(MAP.read_text())
        self.events = {event["id"]: event for event in self.room["events"]}

    def test_only_gacha_and_gym_npcs_are_visible(self):
        visible = {event["id"] for event in self.events.values() if event.get("graphic")}
        self.assertEqual(visible, {7, 8})
        self.assertEqual(set(self.events), {2, 4, 7, 8})
        self.assertEqual(self.events[8]["position"], [10, 2])
        self.assertEqual(self.events[7]["position"], [2, 7])
        self.assertEqual(self.events[8]["actions"][-1]["script"], "CLINormanhurstGacha.scientist")
        self.assertEqual(self.events[7]["actions"][-1]["script"], "CLINormanhurstGymTests.menu")

    def test_invisible_initialization_and_follower_anchor_survive(self):
        self.assertEqual(self.events[2]["trigger"], "autorun")
        self.assertTrue(self.events[2]["actions"][-1]["erase"])
        self.assertIn("$game_player.opacity = 255", self.events[2]["actions"][0]["script"])
        self.assertFalse(self.events[2].get("graphic"))
        self.assertFalse(self.events[4].get("graphic"))
        self.assertEqual(self.room["size"], [12, 10])
        self.assertEqual(self.room["tileset"], 3)


if __name__ == "__main__":
    unittest.main()
