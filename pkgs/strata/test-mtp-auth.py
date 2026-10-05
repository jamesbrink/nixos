"""Offline regression checks for optional Hugging Face token-file authentication."""

import importlib.util
import os
import tempfile
import unittest
import urllib.request
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mtp_fetch", "tools/mtp_fetch.py")
mtp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mtp)


class AuthTests(unittest.TestCase):
    def test_no_token(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertNotIn(
                "Authorization", mtp.request_headers("https://huggingface.co/x")
            )

    def test_only_huggingface_gets_token(self):
        with tempfile.TemporaryDirectory() as directory:
            token = Path(directory) / "token"
            token.write_text("fixture-token\n")
            with patch.dict(os.environ, {"STRATA_HF_TOKEN_FILE": str(token)}):
                self.assertEqual(
                    mtp.request_headers("https://huggingface.co/x")["Authorization"],
                    "Bearer fixture-token",
                )
                self.assertNotIn(
                    "Authorization", mtp.request_headers("https://other.example/x")
                )

    def test_redirect_strips_token(self):
        request = urllib.request.Request(
            "https://huggingface.co/x",
            headers={"Authorization": "Bearer fixture-token"},
        )
        for target in ["https://cdn.example/x", "http://huggingface.co/x"]:
            redirected = mtp.SafeRedirect().redirect_request(
                request, None, 302, "Found", {}, target
            )
            self.assertFalse(redirected.has_header("Authorization"))
        redirected = mtp.SafeRedirect().redirect_request(
            request, None, 302, "Found", {}, "https://huggingface.co/y"
        )
        self.assertTrue(redirected.has_header("Authorization"))


if __name__ == "__main__":
    unittest.main()
