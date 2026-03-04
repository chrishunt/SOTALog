#!/usr/bin/env python3
"""Mock SOTACat HTTP server for simulator testing.

Impersonates a SOTACat device (ESP32 + Elecraft radio) so the iOS Simulator
can exercise the full SOTACat integration path: mDNS discovery, HTTP polling,
VFO sync, tune commands, and CW keyer.

Usage:
    sudo python3 tools/mock_sotacat.py

Requires sudo because the app connects to http://sotacat.local (port 80).
"""

import atexit
import os
import signal
import subprocess
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote


# ---------------------------------------------------------------------------
# Radio state
# ---------------------------------------------------------------------------

VALID_MODES = {"CW", "CW_R", "LSB", "USB", "AM", "FM", "DATA", "DATA_R"}

class RadioState:
    """Mutable radio state shared between HTTP handler and console thread."""

    def __init__(self):
        self.frequency = 14_060_000  # Hz  (14.060 MHz CW)
        self.mode = "CW"
        self.lock = threading.Lock()

    def get_frequency(self):
        with self.lock:
            return self.frequency

    def set_frequency(self, hz):
        with self.lock:
            self.frequency = hz

    def get_mode(self):
        with self.lock:
            return self.mode

    def set_mode(self, mode):
        with self.lock:
            self.mode = mode


# Module-level state (accessible from handler and console)
radio = RadioState()


# ---------------------------------------------------------------------------
# SSB smart-select
# ---------------------------------------------------------------------------

def resolve_mode(mode_str):
    """Resolve mode string, handling SSB → USB/LSB smart-select."""
    mode_upper = mode_str.upper()
    if mode_upper == "SSB":
        freq = radio.get_frequency()
        return "LSB" if freq < 10_000_000 else "USB"
    return mode_upper


# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------

def _ts():
    return time.strftime("%H:%M:%S")


def log_request(method, path):
    print(f"[{_ts()}] {method} {path}")


def log_frequency(hz):
    mhz = hz / 1_000_000
    print(f"\U0001F4FB Frequency \u2192 {mhz:.3f} MHz")


def log_mode(mode):
    print(f"\U0001F4FB Mode \u2192 {mode}")


def log_keyer(message):
    print(f"\U0001F511 CW: {message}")
    print()


# ---------------------------------------------------------------------------
# HTTP request handler
# ---------------------------------------------------------------------------

class SOTACatHandler(BaseHTTPRequestHandler):
    """Handles the subset of SOTACat REST API used by the app."""

    def log_message(self, format, *args):
        # Suppress default stderr logging; we do our own.
        pass

    # -- Routing -------------------------------------------------------------

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        log_request("GET", self.path)

        routes = {
            "/api/v1/version": self._get_version,
            "/api/v1/frequency": self._get_frequency,
            "/api/v1/mode": self._get_mode,
            "/api/v1/connectionStatus": self._get_connection_status,
            "/api/v1/radioType": self._get_radio_type,
        }
        handler = routes.get(path)
        if handler:
            handler()
        else:
            self._send_error(404, "unknown endpoint")

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        params = parse_qs(parsed.query)
        log_request("PUT", self.path)

        routes = {
            "/api/v1/frequency": self._put_frequency,
            "/api/v1/mode": self._put_mode,
            "/api/v1/keyer": self._put_keyer,
        }
        handler = routes.get(path)
        if handler:
            handler(params)
        else:
            self._send_error(404, "unknown endpoint")

    # -- GET handlers --------------------------------------------------------

    def _get_version(self):
        self._send_text(200, "mock-260226")

    def _get_frequency(self):
        self._send_text(200, str(radio.get_frequency()))

    def _get_mode(self):
        self._send_text(200, radio.get_mode())

    def _get_connection_status(self):
        self._send_text(200, "\U0001F7E2")  # 🟢

    def _get_radio_type(self):
        self._send_text(200, "KX2")

    # -- PUT handlers --------------------------------------------------------

    def _put_frequency(self, params):
        values = params.get("frequency")
        if not values:
            self._send_error(404, "missing frequency parameter")
            return
        try:
            hz = int(values[0])
        except (ValueError, IndexError):
            self._send_error(404, "invalid frequency")
            return
        if hz <= 0:
            self._send_error(404, "invalid frequency")
            return
        radio.set_frequency(hz)
        log_frequency(hz)
        self._send_no_content()

    def _put_mode(self, params):
        values = params.get("mode")
        if not values:
            self._send_error(404, "missing mode parameter")
            return
        raw = values[0]
        resolved = resolve_mode(raw)
        if resolved not in VALID_MODES:
            self._send_error(404, "invalid mode")
            return
        radio.set_mode(resolved)
        log_mode(resolved)
        self._send_no_content()

    def _put_keyer(self, params):
        values = params.get("message")
        if not values:
            self._send_error(404, "missing message parameter")
            return
        message = unquote(values[0])
        log_keyer(message)
        self._send_no_content()

    # -- Response helpers ----------------------------------------------------

    def _send_text(self, code, text):
        body = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_no_content(self):
        self.send_response(204)
        self.end_headers()

    def _send_error(self, code, message):
        body = message.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# ---------------------------------------------------------------------------
# Interactive console (runs in a background thread)
# ---------------------------------------------------------------------------

def console_loop():
    """Read commands from stdin to simulate VFO changes."""
    print()
    print("Commands:")
    print("  f <hz>    \u2014 set frequency (e.g. f 7030000)")
    print("  m <mode>  \u2014 set mode (e.g. m SSB)")
    print("  q         \u2014 quit")
    print()

    while True:
        try:
            line = input("Mock SOTACat> ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not line:
            continue
        parts = line.split(None, 1)
        cmd = parts[0].lower()

        if cmd == "q":
            print("Shutting down...")
            os.kill(os.getpid(), signal.SIGINT)
            break
        elif cmd == "f" and len(parts) == 2:
            try:
                hz = int(parts[1])
                if hz <= 0:
                    print("Frequency must be positive")
                    continue
                radio.set_frequency(hz)
                log_frequency(hz)
            except ValueError:
                print("Usage: f <hz>")
        elif cmd == "m" and len(parts) == 2:
            resolved = resolve_mode(parts[1])
            if resolved not in VALID_MODES:
                print(f"Unknown mode. Valid: {', '.join(sorted(VALID_MODES))}, SSB")
                continue
            radio.set_mode(resolved)
            log_mode(resolved)
        else:
            print("Unknown command. Type q to quit.")


# ---------------------------------------------------------------------------
# Bonjour registration
# ---------------------------------------------------------------------------

_dns_sd_proc = None


def register_bonjour(port=80):
    """Register sotacat.local via dns-sd Bonjour proxy."""
    global _dns_sd_proc
    cmd = [
        "dns-sd", "-P", "SOTAcat", "_http._tcp", ".", str(port),
        "sotacat.local", "127.0.0.1",
    ]
    try:
        _dns_sd_proc = subprocess.Popen(
            cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        print(f"Bonjour: registered sotacat.local \u2192 127.0.0.1:{port}")
    except FileNotFoundError:
        print("Warning: dns-sd not found \u2014 Bonjour registration skipped")


def cleanup_bonjour():
    global _dns_sd_proc
    if _dns_sd_proc:
        _dns_sd_proc.terminate()
        _dns_sd_proc.wait()
        _dns_sd_proc = None


atexit.register(cleanup_bonjour)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def create_server(port=80):
    """Create and return an HTTPServer instance (does not start serving)."""
    return HTTPServer(("", port), SOTACatHandler)


def main():
    port = 80
    try:
        server = create_server(port)
    except PermissionError:
        print(f"Error: cannot bind port {port} \u2014 try: sudo python3 {sys.argv[0]}")
        sys.exit(1)
    except OSError as e:
        print(f"Error: {e}")
        sys.exit(1)

    register_bonjour(port)

    # Start interactive console in a daemon thread
    console_thread = threading.Thread(target=console_loop, daemon=True)
    console_thread.start()

    print(f"Mock SOTACat listening on port {port}")
    print(f"Radio: {radio.get_frequency()} Hz ({radio.get_mode()})")
    print()

    def shutdown(signum, frame):
        print("\nShutting down...")
        server._BaseServer__shutdown_request = True

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    server.serve_forever()
    cleanup_bonjour()


if __name__ == "__main__":
    main()
