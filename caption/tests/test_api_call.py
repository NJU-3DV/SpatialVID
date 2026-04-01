"""
Unit and integration tests for caption/utils/api_call.py
"""
import os
import sys
import json
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.abspath(os.path.join(__file__, "../../..")))
from caption.utils.api_call import api_call


def _make_mock_response(content="test response"):
    """Helper to build a mock requests.Response with the standard choices payload."""
    mock_resp = MagicMock()
    mock_resp.json.return_value = {
        "choices": [{"message": {"content": content}}]
    }
    mock_resp.raise_for_status.return_value = None
    return mock_resp


class TestApiCallMiniMax(unittest.TestCase):
    """Unit tests for MiniMax provider routing in api_call()."""

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_endpoint(self, mock_post):
        """MiniMax domain routes to /v1/chat/completions."""
        mock_post.return_value = _make_mock_response("ok")
        api_call("hello", "MiniMax-M2.7", "test-key", "https://api.minimax.io/v1/")
        call_args = mock_post.call_args
        self.assertEqual(call_args[0][0], "https://api.minimax.io/v1/chat/completions")

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_payload_no_enable_thinking(self, mock_post):
        """MiniMax payload must NOT include enable_thinking."""
        mock_post.return_value = _make_mock_response()
        api_call("hello", "MiniMax-M2.7", "test-key", "https://api.minimax.io/v1/")
        payload = mock_post.call_args[1]["json"]
        self.assertNotIn("enable_thinking", payload)

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_temperature_positive(self, mock_post):
        """MiniMax temperature must be in (0.0, 1.0]."""
        mock_post.return_value = _make_mock_response()
        api_call("hello", "MiniMax-M2.7", "test-key", "https://api.minimax.io/v1/")
        payload = mock_post.call_args[1]["json"]
        self.assertIn("temperature", payload)
        self.assertGreater(payload["temperature"], 0.0)
        self.assertLessEqual(payload["temperature"], 1.0)

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_auth_header(self, mock_post):
        """MiniMax request uses Bearer token auth."""
        mock_post.return_value = _make_mock_response()
        api_call("hello", "MiniMax-M2.7", "mykey", "https://api.minimax.io/v1/")
        headers = mock_post.call_args[1]["headers"]
        self.assertEqual(headers["Authorization"], "Bearer mykey")

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_highspeed_model(self, mock_post):
        """MiniMax-M2.7-highspeed model is also handled correctly."""
        mock_post.return_value = _make_mock_response("fast reply")
        result = api_call("test", "MiniMax-M2.7-highspeed", "key",
                          "https://api.minimax.io/v1/")
        payload = mock_post.call_args[1]["json"]
        self.assertEqual(payload["model"], "MiniMax-M2.7-highspeed")
        self.assertEqual(result, "fast reply")

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_multimodal_content(self, mock_post):
        """MiniMax call accepts list-type (multimodal) prompt_text."""
        mock_post.return_value = _make_mock_response("caption")
        multimodal = [
            {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,abc"}},
            {"type": "text", "text": "Describe the scene."},
        ]
        result = api_call(multimodal, "MiniMax-M2.7", "key",
                          "https://api.minimax.io/v1/")
        payload = mock_post.call_args[1]["json"]
        self.assertEqual(payload["messages"][0]["content"], multimodal)
        self.assertEqual(result, "caption")

    @patch("caption.utils.api_call.requests.post")
    def test_minimax_returns_content(self, mock_post):
        """api_call returns the text content from choices[0].message.content."""
        mock_post.return_value = _make_mock_response("spatial caption result")
        result = api_call("prompt", "MiniMax-M2.7", "key",
                          "https://api.minimax.io/v1/")
        self.assertEqual(result, "spatial caption result")


class TestApiCallQwen(unittest.TestCase):
    """Unit tests to verify Qwen routing is unaffected."""

    @patch("caption.utils.api_call.requests.post")
    def test_qwen_endpoint(self, mock_post):
        mock_post.return_value = _make_mock_response()
        api_call("hello", "qwen3-30b-a3b", "key",
                 "https://dashscope.aliyuncs.com/")
        url = mock_post.call_args[0][0]
        self.assertIn("dashscope.aliyuncs.com", url)
        self.assertIn("v1/chat/completions", url)

    @patch("caption.utils.api_call.requests.post")
    def test_qwen_enable_thinking_false(self, mock_post):
        mock_post.return_value = _make_mock_response()
        api_call("hello", "qwen3-30b-a3b", "key",
                 "https://dashscope.aliyuncs.com/")
        payload = mock_post.call_args[1]["json"]
        self.assertFalse(payload.get("enable_thinking"))


class TestApiCallGemini(unittest.TestCase):
    """Unit tests for default (Gemini proxy) routing."""

    @patch("caption.utils.api_call.requests.post")
    def test_gemini_proxy_endpoint(self, mock_post):
        mock_post.return_value = _make_mock_response()
        api_call("hello", "gemini-2.0-flash", "key",
                 "https://cn2us02.opapi.win/")
        url = mock_post.call_args[0][0]
        self.assertIn("v1beta/openai/", url)

    @patch("caption.utils.api_call.requests.post")
    def test_gemini_user_agent_header(self, mock_post):
        mock_post.return_value = _make_mock_response()
        base = "https://cn2us02.opapi.win/"
        api_call("hello", "gemini-2.0-flash", "key", base)
        headers = mock_post.call_args[1]["headers"]
        self.assertIn("User-Agent", headers)


class TestApiCallErrorHandling(unittest.TestCase):
    """Tests for error/exception paths."""

    @patch("caption.utils.api_call.requests.post")
    def test_returns_none_on_exception(self, mock_post):
        mock_post.side_effect = Exception("network error")
        result = api_call("prompt", "MiniMax-M2.7", "key",
                          "https://api.minimax.io/v1/")
        self.assertIsNone(result)


class TestApiCallMiniMaxIntegration(unittest.TestCase):
    """
    Integration tests for MiniMax provider.
    Requires MINIMAX_API_KEY environment variable.
    Skipped automatically when the key is not available.
    """

    @classmethod
    def setUpClass(cls):
        cls.api_key = os.environ.get("MINIMAX_API_KEY")
        if not cls.api_key:
            raise unittest.SkipTest("MINIMAX_API_KEY not set, skipping integration tests")

    def test_minimax_text_completion(self):
        """MiniMax M2.7 should return a non-empty response for a simple prompt."""
        result = api_call(
            "Reply with the single word: OK",
            "MiniMax-M2.7",
            self.api_key,
            "https://api.minimax.io/v1/",
        )
        self.assertIsNotNone(result)
        self.assertIsInstance(result, str)
        self.assertGreater(len(result.strip()), 0)

    def test_minimax_highspeed_text_completion(self):
        """MiniMax-M2.7-highspeed should also return a valid response."""
        result = api_call(
            "Reply with the single word: OK",
            "MiniMax-M2.7-highspeed",
            self.api_key,
            "https://api.minimax.io/v1/",
        )
        self.assertIsNotNone(result)
        self.assertIsInstance(result, str)
        self.assertGreater(len(result.strip()), 0)

    def test_minimax_multimodal_stub(self):
        """MiniMax accepts list-format messages (multimodal) without error."""
        multimodal_content = [
            {"type": "text", "text": "Reply with the single word: OK"}
        ]
        result = api_call(
            multimodal_content,
            "MiniMax-M2.7",
            self.api_key,
            "https://api.minimax.io/v1/",
        )
        self.assertIsNotNone(result)


if __name__ == "__main__":
    unittest.main()
