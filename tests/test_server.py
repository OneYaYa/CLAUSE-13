import json
import unittest

import server


class DialogueServerTests(unittest.TestCase):
    def test_payload_uses_responses_structured_output(self):
        payload = server.build_openai_payload({"npc": {"name": "槐姨"}}, "你是谁？", "test-model")
        self.assertEqual(payload["model"], "test-model")
        self.assertEqual(payload["text"]["format"]["type"], "json_schema")
        self.assertTrue(payload["text"]["format"]["strict"])
        self.assertEqual(payload["input"][-1]["content"], "你是谁？")

    def test_extracts_structured_output_text(self):
        response = {
            "output": [
                {"type": "reasoning", "content": []},
                {"type": "message", "content": [{"type": "output_text", "text": json.dumps({"reply": "门外很冷。"}, ensure_ascii=False)}]},
            ]
        }
        self.assertEqual(json.loads(server.extract_output_text(response))["reply"], "门外很冷。")

    def test_prompt_preserves_authoritative_boundary(self):
        prompt = server.build_system_prompt({
            "npc": {"name": "缝影人", "kind": "影界实体"},
            "state": {"trust": 50, "pressure": 30},
            "public_dossier": {"risk_flags": ["所有权偷换"]},
            "authoritative_read": {"required_fact": "只需要进入儿童房。"},
        })
        self.assertIn("不得宣布玩家的身份判断正确", prompt)
        self.assertIn("只需要进入儿童房", prompt)
        self.assertIn("所有权偷换", prompt)


if __name__ == "__main__":
    unittest.main()
