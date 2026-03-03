# SOTAcat HTTP API Reference

> **Firmware:** v260215.1853 (commit `103be5e`, 2026-02-26)
> **Repository:** github.com/SOTAmat/SOTAcat

Consolidated from the SOTAcat firmware source code (C++ handler files, web server configuration, and integration tests). No OpenAPI specification exists upstream; this reference was derived from the handler table and implementation.

## General

**Base URL:** `http://sotacat.local/` (port 80, HTTP only)

**Discovery:** mDNS hostname `sotacat` with two advertised services:
- `_http._tcp` on port 80 — TXT: `path=/`, `type=http`, `mobile=true`, `device=sotacat`
- `_device-info._tcp` on port 9090 — TXT: `model=SOTAcat`, `version=<firmware>`, `manufacturer=<hardware>`

**WiFi:** Simultaneous AP+STA mode.
- **AP defaults:** SSID `SOTAcat-XXYY` (last 2 bytes of MAC), password `12345678`, IP `192.168.4.1`, WPA2-PSK, max 8 clients
- **STA defaults:** 3 configurable slots with rotation on failure. STA1 defaults to SSID `ham-hotspot`, password `sotapota`
- **IP pinning:** Optional per-STA setting pins host octet to 222

**Authentication:** None. All endpoints are open to any client on the WiFi network.

**Supported radios:**

| Radio | Baud Rate | Notes |
|-------|-----------|-------|
| Elecraft KX2 | 38,400 | Full support (keyer, volume, ATU) |
| Elecraft KX3 | 38,400 | Full support (keyer, volume, ATU) |
| Elecraft KH1 | 9,600 | Keyer/volume support varies |

---

## Response Conventions

Most GET endpoints return **plain text** (`text/plain`). JSON endpoints are noted individually.

| Pattern | HTTP Status | Body |
|---------|------------|------|
| Success with value | 200 | Value as plain text or JSON, `Connection: close` |
| Success, no body | 204 | Empty |
| Bad request | 400 | Error message |
| Invalid parameter / unsupported | 404 | Error message |
| Radio / internal failure | 500 | Error message |
| Radio busy (mutex) | 503 | Error message |

Error bodies are intended as JSON (`{"error":"..."}`) but served with `Content-Type: text/plain`.

---

## Radio Control

### GET `/api/v1/frequency`

Return the current VFO frequency.

**Requires radio:** Yes

**Parameters:** None

**Caching:** 200ms cache. During FT8, returns cached value without querying the radio.

**Response (200):** Plain text integer — frequency in Hz (e.g., `14060000`).

| Status | Meaning | Description |
|--------|---------|-------------|
| 200 | OK | Frequency in Hz |
| 500 | Internal Error | `"radio busy"` or `"invalid frequency from radio"` |

---

### PUT `/api/v1/frequency`

Set the VFO frequency.

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| frequency | query | integer | true | Frequency in Hz (e.g., `14060000`) |

**Retries:** Automatic retries on communication failure.

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 404 | Not Found | `"missing query string"` or `"invalid frequency"` (frequency <= 0) |
| 500 | Internal Error | `"failed to set frequency"` |

---

### GET `/api/v1/mode`

Return the current operating mode.

**Requires radio:** Yes

**Parameters:** None

**Caching:** 200ms cache.

**Response (200):** Plain text mode string — one of `LSB`, `USB`, `CW`, `FM`, `AM`, `DATA`, `CW_R`, `DATA_R`, `UNKNOWN`.

| Status | Meaning | Description |
|--------|---------|-------------|
| 200 | OK | Mode string |
| 500 | Internal Error | `"unrecognized mode"` |

---

### PUT `/api/v1/mode`

Set the operating mode.

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| mode | query | string | true | Mode name (case-insensitive) |

**Accepted values:**
- Primary: `LSB`, `USB`, `CW`, `FM`, `AM`, `DATA`, `CW_R`, `DATA_R`
- Smart: `SSB` — auto-selects `LSB` below 10 MHz, `USB` at or above 10 MHz
- Data aliases (all map to `DATA`): `FT8`, `JS8`, `PK31`, `FT4`, `RTTY`

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 404 | Not Found | `"invalid mode"` or `"invalid mode for radio"` |
| 500 | Internal Error | Radio mutex timeout |

---

### GET `/api/v1/power`

Return the current transmit power level.

**Requires radio:** Yes

**Parameters:** None

**Response (200):** Plain text integer — power in watts (e.g., `5`).

| Status | Meaning | Description |
|--------|---------|-------------|
| 200 | OK | Power in watts |
| 404 | Not Found | `"power read not supported"` |

---

### PUT `/api/v1/power`

Set the transmit power level.

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| power | query | integer | true | Power in watts (e.g., 5). Max varies by radio: KX2 = 10W, KX3 = 15W |

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 404 | Not Found | `"unable to set power"` |

---

### GET `/api/v1/volume`

Return the current audio volume level.

**Requires radio:** Yes

**Parameters:** None

**Response (200):** Plain text integer — volume level (0–255).

| Status | Meaning | Description |
|--------|---------|-------------|
| 200 | OK | Volume level |
| 404 | Not Found | `"volume not supported on this radio"` |
| 500 | Internal Error | `"unable to read volume"` |

---

### PUT `/api/v1/volume`

Adjust the audio volume (relative, not absolute).

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| delta | query | integer | true | Volume adjustment — positive = louder, negative = quieter |

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 404 | Not Found | `"volume not supported on this radio"` |
| 500 | Internal Error | `"unable to set volume"` |

---

### PUT `/api/v1/xmit`

Toggle transmit/receive state.

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| state | query | integer | true | `0` = receive (RX), non-zero = transmit (TX) |

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 500 | Internal Error | `"unable to set xmit"` |

---

### PUT `/api/v1/keyer`

Send a CW message via the radio's built-in keyer.

**Requires radio:** Yes

**Lock tier:** Critical (10s timeout).

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| message | query | string | true | URL-encoded text to key in Morse. Long messages (> ~24 chars) are automatically split at word boundaries. |

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 404 | Not Found | `"Morse keying not supported on this radio"` |
| 500 | Internal Error | `"keyer send failed"` |

---

### PUT `/api/v1/msg`

Play a stored CW message bank on the radio.

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| bank | query | integer | true | Message bank number (1 or 2) |

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 500 | Internal Error | `"unable to play message bank"` |

---

### PUT `/api/v1/atu`

Trigger the antenna tuner (ATU).

**Requires radio:** Yes

**Lock tier:** Critical (10s timeout).

**Parameters:** None

Radio-specific commands: `SWT44` (KX3), `SWT20` (KX2), `SW3T` (KH1).

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 500 | Internal Error | `"Failed to send ATU command"` |

---

### PUT `/api/v1/time`

Synchronize the radio's clock.

**Requires radio:** Yes

**Lock tier:** Critical (10s timeout).

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| time | query | integer | true | Seconds since UTC epoch (Unix timestamp) |

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Success |
| 400 | Bad Request | `"invalid time value"` |
| 500 | Internal Error | `"failed to sync radio time"` |

---

## FT8 Operations

FT8 uses a three-phase workflow: prepare, transmit, cancel. Transmissions align to 15-second FT8 windows.

### POST `/api/v1/prepareft8`

Prepare the radio for FT8 transmission. Sets frequency, mode, and encodes tones.

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| messageText | query | string | true | FT8 message text (max 13 chars, URL-encoded) |
| timeNow | query | integer | true | Current UTC time in milliseconds since epoch |
| rfFrequency | query | integer | true | Base RF frequency in Hz |
| audioFrequency | query | integer | true | Audio frequency offset in Hz |
| requestToken | query | string | true | Client-generated workflow token (max 64 chars) for correlating retries |

**Idempotent:** Repeated identical requests extend the preparation deadline.

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Radio prepared for FT8 |
| 404 | Not Found | `"parameter parsing error"` |
| 500 | Internal Error | Various: `"prepare called while another command already in progress"`, `"ft8 cleanup in progress"`, `"ft8 already prepared with different parameters"`, `"can't parse FT8 message"`, `"radio busy, please retry"`, `"failed to prepare radio for ft8"` |

---

### POST `/api/v1/ft8`

Queue or start an FT8 transmission. Must be preceded by `prepareft8` (or include auto-prepare parameters).

**Requires radio:** Yes

**Parameters:**

| Name | In | Type | Required | Description |
|------|------|---------|----------|-------------|
| rfFrequency | query | integer | true | Base RF frequency in Hz |
| audioFrequency | query | integer | true | Audio frequency offset in Hz |
| requestToken | query | string | true | Workflow token (must match `prepareft8`) |
| sequenceNumber | query | integer | true | Monotonically increasing number for idempotent retries |
| messageText | query | string | conditional | Required if no prior `prepareft8` call (auto-prepare) |
| timeNow | query | integer | conditional | Required if no prior `prepareft8` call (auto-prepare) |

**Queue:** Max 4 queued transmissions.

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Transmission queued or started |
| 404 | Not Found | `"parameter parsing error"`, `"missing or invalid requestToken"`, `"missing or invalid sequenceNumber"` |
| 500 | Internal Error | Various: `"ft8 request token mismatch"`, `"stale ft8 sequenceNumber"`, `"out-of-order ft8 sequenceNumber"`, `"ft8 cleanup in progress"`, `"ft8 not prepared"`, `"FT8 queue full"` |

---

### POST `/api/v1/cancelft8`

Cancel any in-progress or queued FT8 transmissions. The cleanup watchdog restores the radio to its pre-FT8 state asynchronously.

**Requires radio:** Yes

**Parameters:** None

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Cancellation initiated |

---

## Status & Info

### GET `/api/v1/connectionStatus`

Return the radio connection and transmit state as a single emoji character.

**Requires radio:** No

**Parameters:** None

**Response (200):** Plain text, one Unicode character:

| Character | Meaning |
|-----------|---------|
| &#x26AB; (black circle) | Radio not connected |
| &#x26AA; (white circle) | Connected but busy (FT8) or unknown state |
| &#x1F7E2; (green circle) | Connected, receiving (RX) |
| &#x1F534; (red circle) | Connected, transmitting (TX) |

---

### GET `/api/v1/batteryInfo`

Return battery status. Response format depends on hardware (smart fuel gauge vs. analog ADC).

**Requires radio:** No

**Parameters:** None

**Response (200):** `Content-Type: application/json`

Smart battery (MAX17260 fuel gauge):

```json
{
  "is_smart": true,
  "voltage_v": 3.85,
  "current_ma": -45.2,
  "temp_c": 25.3,
  "state_of_charge_pct": 78.5,
  "capacity_mah": 1200.0,
  "time_to_empty_hrs": 12.50,
  "time_to_full_hrs": 0.00,
  "charging": false
}
```

Analog battery:

```json
{
  "is_smart": false,
  "voltage_v": 3.72,
  "state_of_charge_pct": 65.0
}
```

---

### GET `/api/v1/rssi`

Return the WiFi received signal strength.

**Requires radio:** No

**Parameters:** None

**Response (200):** Plain text integer — RSSI in dBm (e.g., `"-45"`). Returns `"0"` if not connected to a station.

---

### GET `/api/v1/version`

Return the firmware version string.

**Requires radio:** No

**Parameters:** None

**Response (200):** Plain text version string (constructed from build date/time and debug/release indicator).

---

### GET `/api/v1/radioType`

Return the detected radio model.

**Requires radio:** No

**Parameters:** None

**Response (200):** Plain text — one of `KX2`, `KX3`, `KH1`, or `Unknown`.

---

## Settings

All settings endpoints persist values to NVS (non-volatile storage). GET endpoints return `Content-Type: application/json`.

### GET `/api/v1/settings`

Return WiFi and AP configuration.

**Requires radio:** No

**Parameters:** None

**Response (200):**

```json
{
  "sta1_ssid": "ham-hotspot",
  "sta1_pass": "sotapota",
  "sta2_ssid": "",
  "sta2_pass": "",
  "sta3_ssid": "",
  "sta3_pass": "",
  "ap_ssid": "SOTAcat-A480",
  "ap_pass": "12345678",
  "sta1_ip_pin": false,
  "sta2_ip_pin": false,
  "sta3_ip_pin": false
}
```

---

### POST `/api/v1/settings`

Update WiFi and AP configuration. **Device reboots ~2 seconds after response.**

**Requires radio:** No

**Request body:** JSON with any subset of settings keys (same schema as GET response).

**Response (200):** Returns the stored settings JSON, then the device reboots.

---

### GET `/api/v1/gps`

Return stored GPS coordinates.

**Requires radio:** No

**Parameters:** None

**Response (200):**

```json
{
  "gps_lat": "39.7392",
  "gps_lon": "-104.9903"
}
```

---

### POST `/api/v1/gps`

Update stored GPS coordinates.

**Requires radio:** No

**Request body:** `{"gps_lat": "39.7392", "gps_lon": "-104.9903"}`

**Response (200):** Returns updated GPS settings JSON.

---

### GET `/api/v1/callsign`

Return the configured operator callsign.

**Requires radio:** No

**Parameters:** None

**Response (200):**

```json
{"callsign": "W1AW"}
```

---

### POST `/api/v1/callsign`

Update the operator callsign.

**Requires radio:** No

**Request body:** `{"callsign": "W1AW"}`

**Response (200):** Returns updated callsign JSON.

---

### GET `/api/v1/license`

Return the configured license class.

**Requires radio:** No

**Parameters:** None

**Response (200):**

```json
{"license": "E"}
```

Valid values: `"T"` (Technician), `"G"` (General), `"E"` (Extra), or `""` (not set). Max 3 characters.

---

### POST `/api/v1/license`

Update the license class.

**Requires radio:** No

**Request body:** `{"license": "G"}`

**Response (200):** Returns updated license JSON.

---

### GET `/api/v1/tuneTargets`

Return WebSDR/KiwiSDR tune target URLs.

**Requires radio:** No

**Parameters:** None

**Response (200):**

```json
{
  "targets": ["http://websdr.example.com", "http://kiwisdr.example.com"],
  "mobile": true
}
```

Target URLs support placeholders: `{FREQ-HZ}`, `{FREQ-KHZ}`, `{FREQ-MHZ}`, `{MODE}`.

---

### POST `/api/v1/tuneTargets`

Update tune target URLs.

**Requires radio:** No

**Request body:** `{"targets": ["http://websdr.example.com"], "mobile": false}`

**Response (200):** Returns updated tune targets JSON.

---

### GET `/api/v1/cwMacros`

Return CW macro definitions.

**Requires radio:** No

**Parameters:** None

**Response (200):**

```json
{
  "macros": [
    {"label": "CQ SOTA", "template": "CQ SOTA DE {MYCALL} K"},
    {"label": "TU 73", "template": "TU 73 DE {MYCALL}"}
  ]
}
```

Max 8 macros. Templates support placeholders: `{MYCALL}`, `{MYREF}`.

---

### POST `/api/v1/cwMacros`

Update CW macro definitions.

**Requires radio:** No

**Request body:** JSON (same schema as GET response).

**Response (200):** Returns updated CW macros JSON.

---

## Device Management

### GET `/api/v1/reboot`

Reboot the device. Response is sent before the reboot occurs (~2 second delay).

**Requires radio:** No

**Parameters:** None

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | Reboot scheduled |

---

### POST `/api/v1/ota`

Upload a firmware image for over-the-air update. Device reboots ~2 seconds after a successful flash.

**Requires radio:** No

**Request body:** Raw binary firmware image (`application/octet-stream`).

| Status | Meaning | Description |
|--------|---------|-------------|
| 204 | No Content | OTA succeeded, rebooting |
| 500 | Internal Error | Various: `"OTA update not supported on this platform"`, `"No OTA partition available"`, `"OTA begin failed"`, `"OTA write failed"`, `"OTA end failed"`, `"OTA data reception error"`, `"Setting boot partition failed"` |

---

## Endpoint Summary

| # | Method | Endpoint | Radio | Response | Description |
|---|--------|----------|:-----:|----------|-------------|
| 1 | GET | `/api/v1/connectionStatus` | No | text | Radio connection/TX state emoji |
| 2 | GET | `/api/v1/batteryInfo` | No | JSON | Battery voltage, SoC, current |
| 3 | GET | `/api/v1/rssi` | No | text | WiFi RSSI in dBm |
| 4 | GET | `/api/v1/frequency` | Yes | text | VFO frequency in Hz |
| 5 | PUT | `/api/v1/frequency` | Yes | 204 | Set VFO frequency |
| 6 | GET | `/api/v1/mode` | Yes | text | Operating mode string |
| 7 | PUT | `/api/v1/mode` | Yes | 204 | Set operating mode |
| 8 | GET | `/api/v1/power` | Yes | text | TX power in watts |
| 9 | PUT | `/api/v1/power` | Yes | 204 | Set TX power |
| 10 | GET | `/api/v1/volume` | Yes | text | Audio volume (0–255) |
| 11 | PUT | `/api/v1/volume` | Yes | 204 | Adjust volume (relative) |
| 12 | PUT | `/api/v1/xmit` | Yes | 204 | Toggle TX/RX |
| 13 | PUT | `/api/v1/keyer` | Yes | 204 | Send CW via keyer |
| 14 | PUT | `/api/v1/msg` | Yes | 204 | Play CW message bank |
| 15 | PUT | `/api/v1/atu` | Yes | 204 | Trigger antenna tuner |
| 16 | PUT | `/api/v1/time` | Yes | 204 | Sync radio clock |
| 17 | POST | `/api/v1/prepareft8` | Yes | 204 | Prepare FT8 transmission |
| 18 | POST | `/api/v1/ft8` | Yes | 204 | Queue/start FT8 transmission |
| 19 | POST | `/api/v1/cancelft8` | Yes | 204 | Cancel FT8 |
| 20 | GET | `/api/v1/version` | No | text | Firmware version string |
| 21 | GET | `/api/v1/radioType` | No | text | Detected radio model |
| 22 | GET | `/api/v1/settings` | No | JSON | WiFi/AP configuration |
| 23 | POST | `/api/v1/settings` | No | JSON | Update WiFi/AP config (reboots) |
| 24 | GET | `/api/v1/gps` | No | JSON | Stored GPS coordinates |
| 25 | POST | `/api/v1/gps` | No | JSON | Update GPS coordinates |
| 26 | GET | `/api/v1/callsign` | No | JSON | Operator callsign |
| 27 | POST | `/api/v1/callsign` | No | JSON | Update callsign |
| 28 | GET | `/api/v1/license` | No | JSON | License class |
| 29 | POST | `/api/v1/license` | No | JSON | Update license class |
| 30 | GET | `/api/v1/tuneTargets` | No | JSON | WebSDR/KiwiSDR URLs |
| 31 | POST | `/api/v1/tuneTargets` | No | JSON | Update tune targets |
| 32 | GET | `/api/v1/cwMacros` | No | JSON | CW macro definitions |
| 33 | POST | `/api/v1/cwMacros` | No | JSON | Update CW macros |
| 34 | GET | `/api/v1/reboot` | No | 204 | Reboot device |
| 35 | POST | `/api/v1/ota` | No | 204 | OTA firmware update (reboots) |

---

## Constraints

**Mutex tiers** — All radio operations are serialized through a timed mutex. Timeouts vary by operation complexity:

| Tier | Timeout | Used For |
|------|---------|----------|
| Fast | 500ms | GET (read radio state) |
| Quick | 1,000ms | Quick SET operations |
| Moderate | 2,000ms | SET operations (change state) |
| Critical | 10,000ms | TX/RX toggle, keyer, ATU, time sync |
| FT8 | 20,000ms | FT8 transmission (~13s + margin) |

**Caching** — Frequency and mode GET endpoints cache for 200ms to reduce radio mutex contention. During FT8 operations, cached values are returned without querying the radio.

**Connection limits** — Max 12 open sockets, max 8 WiFi clients on the AP. Stress tests show >90% success rate with 7 concurrent clients.

**FT8 queue** — Max 4 queued transmissions. An exclusive flag (`Ft8RadioExclusive`) prevents other radio operations during FT8.

**Auto-shutdown** — Deep sleep after 30 minutes of inactivity.

**Battery shutoff** — Operations restricted when battery falls below 70% state of charge.

**Web UI poll intervals** — Connection status every 5s, VFO state every 3s, battery info every 60s.
