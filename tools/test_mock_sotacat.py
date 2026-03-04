#!/usr/bin/env python3
"""Tests for the mock SOTACat server.

Run:
    python3 -m pytest tools/test_mock_sotacat.py -v
    python3 -m unittest tools.test_mock_sotacat -v
"""

import http.client
import threading
import time
import unittest
from urllib.parse import urlencode

# Import the mock server module
from tools.mock_sotacat import create_server, radio, RadioState, VALID_MODES, cw_duration

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
        radio.cw_wpm = 0  # disable keyer delay for fast tests


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


class TestCWDuration(unittest.TestCase):

    def test_zero_wpm_returns_zero(self):
        self.assertEqual(cw_duration("CQ SOTA", 0), 0.0)

    def test_single_char(self):
        # "E" = 8 dit-units at 15 WPM: 8 * (1.2/15) = 0.64s
        self.assertAlmostEqual(cw_duration("E", 15), 0.64)

    def test_spaces_add_less_than_chars(self):
        # Space = 4 dit-units vs char = 8 dit-units
        self.assertLess(cw_duration(" ", 15), cw_duration("E", 15))

    def test_longer_message_takes_longer(self):
        self.assertGreater(cw_duration("CQ SOTA DE W1AW K", 15),
                           cw_duration("CQ", 15))


class TestKeyerBlocking(unittest.TestCase):
    """Verify the keyer blocks the single-threaded server."""

    def setUp(self):
        radio.cw_wpm = 15

    def tearDown(self):
        radio.cw_wpm = 0

    def test_keyer_blocks_concurrent_request(self):
        """A GET during keyer send should be delayed until CW finishes."""
        # "E" at 15 WPM blocks for ~0.64s — long enough to measure
        results = {}

        def send_keyer():
            results["keyer"] = _put("/api/v1/keyer?message=EE")

        def poll_frequency():
            # Small delay so keyer starts first
            time.sleep(0.1)
            start = time.monotonic()
            results["poll"] = _get("/api/v1/frequency")
            results["poll_delay"] = time.monotonic() - start

        t1 = threading.Thread(target=send_keyer)
        t2 = threading.Thread(target=poll_frequency)
        t1.start()
        t2.start()
        t1.join(timeout=10)
        t2.join(timeout=10)

        # Keyer should return 204
        self.assertEqual(results["keyer"][0], 204)
        # Poll should eventually succeed
        self.assertEqual(results["poll"][0], 200)
        # Poll should have been delayed (blocked by keyer)
        # "EE" at 15 WPM = 16 dit-units * 0.08s = 1.28s, minus 0.1s head start
        self.assertGreater(results["poll_delay"], 0.3)


if __name__ == "__main__":
    unittest.main()
