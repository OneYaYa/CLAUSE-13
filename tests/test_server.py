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
        required = payload["text"]["format"]["schema"]["required"]
        self.assertEqual(required, ["utterance", "action", "referenced_ids", "proposed_actions"])

    def test_extracts_structured_output_text(self):
        response = {
            "output": [
                {"type": "reasoning", "content": []},
                {"type": "message", "content": [{"type": "output_text", "text": json.dumps({"utterance": "门外很冷。"}, ensure_ascii=False)}]},
            ]
        }
        self.assertEqual(json.loads(server.extract_output_text(response))["utterance"], "门外很冷。")

    def test_prompt_preserves_authoritative_boundary(self):
        prompt = server.build_system_prompt({
            "npc": {
                "name": "缝影人",
                "kind": "影界实体",
                "persona_core": {"default_strategy": "把关系理解成工钱"},
                "active_scene_mode": {"mode_id": "watchful", "behavior": "只谈当前工序"},
            },
            "public_dossier": {"risk_flags": ["所有权偷换"]},
            "known_beliefs": [{
                "belief_id": "room_boundary",
                "content": "只需要进入儿童房。",
                "confidence": 0.95,
                "source": "npc_experience",
                "truth_status": "npc_belief",
            }],
            "authoritative_read": {"semantic_anchor": "只需要进入儿童房。"},
        })
        self.assertIn("不得宣布身份判断正确", prompt)
        self.assertIn("只需要进入儿童房", prompt)
        self.assertNotIn("所有权偷换", prompt)
        self.assertIn("未列入 KNOWN_BELIEFS", prompt)

    def test_context_whitelist_drops_legacy_dossier_and_hidden_answer(self):
        safe = server.sanitize_context({
            "case_id": "rain_guest",
            "npc": {"name": "槐姨"},
            "public_dossier": {"secret": "不应进入模型"},
            "is_impostor": True,
            "verdict_explanation": "隐藏答案",
            "known_beliefs": [{"belief_id": "claim", "content": "我只是来避雨。"}],
        })
        serialized = json.dumps(safe, ensure_ascii=False)
        self.assertNotIn("不应进入模型", serialized)
        self.assertNotIn("隐藏答案", serialized)
        self.assertNotIn("is_impostor", serialized)
        self.assertIn("我只是来避雨", serialized)

    def test_model_output_references_only_authorized_context_ids(self):
        context = server.sanitize_context({
            "known_beliefs": [{"belief_id": "known", "content": "已知"}],
            "relevant_memories": [{"memory_id": "memory:1", "subjective_text": "记得承诺"}],
        })
        output = server.validate_model_output({
            "utterance": "我只谈我知道的事。",
            "action": "她把手收回袖中。",
            "referenced_ids": ["known", "secret", "memory:1"],
            "proposed_actions": [
                {"type": "gesture", "target": "袖口", "reason_code": "CHARACTER_EXPRESSION"},
                {"type": "change_world", "target": "开门", "reason_code": "CHARACTER_EXPRESSION"},
            ],
        }, context)
        self.assertEqual(output["referenced_ids"], ["known", "memory:1"])
        self.assertEqual([item["type"] for item in output["proposed_actions"]], ["gesture"])


if __name__ == "__main__":
    unittest.main()
