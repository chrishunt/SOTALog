#!/usr/bin/env python3
"""Tests for the mock SOTACat server.

Run:
    python3 -m pytest tools/test_mock_sotacat.py -v
    python3 -m unittest tools.test_mock_sotacat -v
"""

import http.client
import threading
import unittest
from urllib.parse import urlencode

# Import the mock server module
from tools.mock_sotacat import create_server, radio, RadioState, VALID_MODES

# ---------------------------------------------------------------------------
# Shared server — started once for the entire test module
# ---------------------------------------------------------------------------

_server = create_server(port=0)
_port = _server.server_address[1]
_thread = threading.Thread(target=_server.serve_forever)
_thread.daemon = True
_thread.start()


def _get(path):
    conn = http.client.HTTPConnection("127.0.0.1", _port, timeout=5)
    conn.request("GET", path)
    resp = conn.getresponse()
    body = resp.read().decode("utf-8")
    conn.close()
    return resp.status, body


def _put(path):
    conn = http.client.HTTPConnection("127.0.0.1", _port, timeout=5)
    conn.request("PUT", path)
    resp = conn.getresponse()
    body = resp.read().decode("utf-8")
    conn.close()
    return resp.status, body


class MockSOTACatTestCase(unittest.TestCase):
    """Base class that resets radio state before each test."""

    def setUp(self):
        radio.set_frequency(14_060_000)
        radio.set_mode("CW")


class TestVersion(MockSOTACatTestCase):

    def test_version_returns_200(self):
        status, body = _get("/api/v1/version")
        self.assertEqual(status, 200)
        self.assertIn("mock", body)


class TestFrequency(MockSOTACatTestCase):

    def test_frequency_get_returns_hz(self):
        status, body = _get("/api/v1/frequency")
        self.assertEqual(status, 200)
        self.assertEqual(body, "14060000")

    def test_frequency_put_updates_state(self):
        status, _ = _put("/api/v1/frequency?frequency=7030000")
        self.assertEqual(status, 204)
        status, body = _get("/api/v1/frequency")
        self.assertEqual(body, "7030000")

    def test_frequency_put_returns_204(self):
        status, _ = _put("/api/v1/frequency?frequency=7030000")
        self.assertEqual(status, 204)

    def test_frequency_put_missing_param_returns_404(self):
        status, _ = _put("/api/v1/frequency")
        self.assertEqual(status, 404)

    def test_frequency_put_invalid_returns_404(self):
        status, _ = _put("/api/v1/frequency?frequency=0")
        self.assertEqual(status, 404)

    def test_frequency_put_negative_returns_404(self):
        status, _ = _put("/api/v1/frequency?frequency=-100")
        self.assertEqual(status, 404)


class TestMode(MockSOTACatTestCase):

    def test_mode_get_returns_string(self):
        status, body = _get("/api/v1/mode")
        self.assertEqual(status, 200)
        self.assertEqual(body, "CW")

    def test_mode_put_updates_state(self):
        status, _ = _put("/api/v1/mode?mode=USB")
        self.assertEqual(status, 204)
        status, body = _get("/api/v1/mode")
        self.assertEqual(body, "USB")

    def test_mode_put_returns_204(self):
        status, _ = _put("/api/v1/mode?mode=LSB")
        self.assertEqual(status, 204)

    def test_mode_put_ssb_smart_select_below_10mhz(self):
        radio.set_frequency(7_030_000)  # 7 MHz < 10 MHz -> LSB
        status, _ = _put("/api/v1/mode?mode=SSB")
        self.assertEqual(status, 204)
        _, body = _get("/api/v1/mode")
        self.assertEqual(body, "LSB")

    def test_mode_put_ssb_smart_select_above_10mhz(self):
        radio.set_frequency(14_060_000)  # 14 MHz >= 10 MHz -> USB
        status, _ = _put("/api/v1/mode?mode=SSB")
        self.assertEqual(status, 204)
        _, body = _get("/api/v1/mode")
        self.assertEqual(body, "USB")

    def test_mode_put_invalid_returns_404(self):
        status, _ = _put("/api/v1/mode?mode=BOGUS")
        self.assertEqual(status, 404)

    def test_mode_put_missing_param_returns_404(self):
        status, _ = _put("/api/v1/mode")
        self.assertEqual(status, 404)


class TestKeyer(MockSOTACatTestCase):

    def test_keyer_put_returns_204(self):
        status, _ = _put("/api/v1/keyer?message=CQ")
        self.assertEqual(status, 204)

    def test_keyer_url_decodes_message(self):
        # The server should accept URL-encoded messages (app sends them encoded)
        status, _ = _put("/api/v1/keyer?message=CQ%20SOTA%20DE%20W1AW%20K")
        self.assertEqual(status, 204)

    def test_keyer_missing_message_returns_404(self):
        status, _ = _put("/api/v1/keyer")
        self.assertEqual(status, 404)


class TestStatus(MockSOTACatTestCase):

    def test_connection_status_returns_emoji(self):
        status, body = _get("/api/v1/connectionStatus")
        self.assertEqual(status, 200)
        self.assertEqual(body, "\U0001F7E2")  # green circle

    def test_radio_type_returns_string(self):
        status, body = _get("/api/v1/radioType")
        self.assertEqual(status, 200)
        self.assertEqual(body, "KX2")


class TestUnknownEndpoint(MockSOTACatTestCase):

    def test_unknown_endpoint_returns_404(self):
        status, _ = _get("/api/v1/bogus")
        self.assertEqual(status, 404)

    def test_unknown_put_endpoint_returns_404(self):
        status, _ = _put("/api/v1/bogus")
        self.assertEqual(status, 404)


class TestExternalStateChange(MockSOTACatTestCase):

    def test_external_state_change_reflected(self):
        """Directly setting radio state (simulating console commands) is
        reflected in subsequent GET requests."""
        radio.set_frequency(3_560_000)
        radio.set_mode("LSB")

        _, freq_body = _get("/api/v1/frequency")
        self.assertEqual(freq_body, "3560000")

        _, mode_body = _get("/api/v1/mode")
        self.assertEqual(mode_body, "LSB")


if __name__ == "__main__":
    unittest.main()
