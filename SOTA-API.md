# SOTA Database API Reference

> **Version:** api-db v2.0.0
> **Author:** Andrew Ryan VK3ARR
> **Contact:** reflector.sota.org.uk

Consolidated from the official SOTA API documentation PDFs for alerts endpoints (25 October 2025), spots endpoints (25 October 2025), and upload endpoint (6 February 2026).

## General

**Base URL:** `https://api-db2.sota.org.uk/`

**Authentication:** HTTP Authentication, scheme: Bearer token using a JWT obtained from SOTA SSO with user credentials.

---

## Alerts

### GET `/api/alerts/epoch`

Return current alert epoch. If this is different to the previous stored epoch, call the alerts endpoint to fetch new alerts.

**Authentication required:** No

**Parameters:** None

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | none        | None   |

---

### GET `/api/alerts/{lag}/{limit}/{band}/{mode}`

Return list of alerts.

**Authentication required:** No

**Parameters:**

| Name  | In   | Type    | Required | Description |
|-------|------|---------|----------|-------------|
| lag   | path | integer | true     | Lower bound on for alert schedule, being this number of hours prior to the current time |
| limit | path | integer | true     | Upper bound on for alert schedule, being this number of hours after to the current time |
| bands | path | string  | true     | A comma separated list of bands to filter against, or one of either 'hf', 'vhf' or 'all'. Currently ignored as the band entries for a lot of alerts are unparseable. |
| modes | path | string  | true     | A comma separated list of modes to include, or 'all' for all modes. |

**Example 200 response:**

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "dateActivated": "2019-08-24T14:15:22Z",
    "activatingCallsign": "string",
    "activatorName": "string",
    "posterCallsign": "string",
    "comments": "string",
    "mode": "string",
    "associationCode": "string",
    "summitCode": "string",
    "summitDetails": "string",
    "frequency": "string",
    "userID": 0
  }
]
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Array of Alerts. Store the 'epoch' field in the first alert and compare with the epoch endpoint before fetching again when different. | AlertViewArray |
| 400    | Bad Request | Invalid request | None |

---

### POST `/api/alerts`

Add or edit an alert. If no alert ID is specified, a new alert is created. If an alert ID is specified, the alert is edited.

**Authentication required:** Yes (bearerToken)

**Body parameter:**

```json
{
  "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "dateActivated": "2019-08-24T14:15:22Z",
  "activatingCallsign": "string",
  "activatorName": "string",
  "posterCallsign": "string",
  "comments": "string",
  "mode": "string",
  "associationCode": "string",
  "summitCode": "string",
  "summitDetails": "string",
  "frequency": "string",
  "userID": 0
}
```

| Name               | In   | Type             | Required | Description |
|--------------------|------|------------------|----------|-------------|
| body               | body | AlertView        | true     | none |
| epoch              | body | string(uuid)     | false    | Current alerts epoch. This must be stored and compared with the output from the /api/alerts/epoch endpoint before calling this endpoint again |
| id                 | body | integer          | false    | Unique identifier for the alert. |
| timeStamp          | body | string(date-time)| false    | Time this alert was posted (UTC) |
| dateActivated      | body | string(date-time)| false    | Time of the activation (UTC) |
| activatingCallsign | body | string           | false    | Callsign of person being alerted |
| activatorName      | body | string           | false    | Name of person being alerted |
| posterCallsign     | body | string           | false    | Callsign of person who submitted the alert |
| comments           | body | string           | false    | Comments added to spot |
| mode               | body | string           | false    | Operating mode |
| associationCode    | body | string           | false    | Association for this summit alert (eg, G) |
| summitCode         | body | string           | false    | Summit code part of summit reference (eg, TW-004) |
| summitDetails      | body | string           | false    | Text description of summit |
| frequency          | body | string           | false    | List of band-mode pairs planned for this alert |
| userID             | body | integer          | false    | SOTA user ID for alert poster |

**Example 200 response:**

```json
{
  "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "dateActivated": "2019-08-24T14:15:22Z",
  "activatingCallsign": "string",
  "activatorName": "string",
  "posterCallsign": "string",
  "comments": "string",
  "mode": "string",
  "associationCode": "string",
  "summitCode": "string",
  "summitDetails": "string",
  "frequency": "string",
  "userID": 0
}
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Alert that was inserted, with ID and epoch. | AlertView |
| 400    | Bad Request | Invalid request | None |

---

### DELETE `/api/alerts/{id}`

Delete an alert. Must be authenticated via bearer token.

**Authentication required:** Yes (bearerToken)

| Name | In   | Type    | Required | Description |
|------|------|---------|----------|-------------|
| id   | path | integer | false    | The alert ID to delete (from the Id field of the alert object). |

**Example 200 response:**

```
"string"
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Empty string if successful. | string |
| 400    | Bad Request | Invalid request, such as trying to delete an alert the authenticated user doesn't own, or where the alert no longer exists | None |

---

### GET `/api/alerts/{lag}` *(deprecated)*

DEPRECATED. Return list of alerts. This is a translation layer for older clients.

**Authentication required:** No

| Name | In   | Type    | Required | Description |
|------|------|---------|----------|-------------|
| lag  | path | integer | true     | Return all alerts scheduled for after this number of hours prior to the current time |

**Example 200 response:**

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "dateActivated": "2019-08-24T14:15:22Z",
    "activatingCallsign": "string",
    "activatorName": "string",
    "posterCallsign": "string",
    "comments": "string",
    "mode": "string",
    "associationCode": "string",
    "summitCode": "string",
    "summitDetails": "string",
    "frequency": "string",
    "userID": 0
  }
]
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Array of Alerts. Store the 'epoch' field in the first alert and compare with the epoch endpoint before fetching again when different. | AlertViewArray |
| 400    | Bad Request | Invalid request | None |

---

### GET `/api/alerts/` *(deprecated)*

DEPRECATED. Return list of alerts. This is a translation layer for older clients, and equivalent to calling /api/alerts/12.

**Authentication required:** No

**Parameters:** None

**Example 200 response:**

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "dateActivated": "2019-08-24T14:15:22Z",
    "activatingCallsign": "string",
    "activatorName": "string",
    "posterCallsign": "string",
    "comments": "string",
    "mode": "string",
    "associationCode": "string",
    "summitCode": "string",
    "summitDetails": "string",
    "frequency": "string",
    "userID": 0
  }
]
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Array of Alerts. Store the 'epoch' field in the first alert and compare with the epoch endpoint before fetching again when different. | AlertViewArray |
| 400    | Bad Request | Invalid request | None |

---

## Spots

### GET `/api/spots/epoch`

Return current spot epoch. If this is different to the previous stored epoch, call the spots endpoint to fetch new spots.

**Authentication required:** No

**Parameters:** None

**Example response:**

```
769770d2-e9b9-4f62-b7a9-465905ac49bf
```

| Status | Meaning | Description | Schema |
|--------|---------|-------------|--------|
| 200    | OK      | Unique string for current spot epoch. If this is different to the previous stored epoch, call the spots endpoint to fetch new spots | None |

---

### GET `/api/spots/{limit}/{bands}/{modes}`

Return list of spots.

**Authentication required:** No

**Parameters:**

| Name  | In   | Type    | Required | Description |
|-------|------|---------|----------|-------------|
| limit | path | integer | true     | If positive, the number of spots to return (max 200). If negative, the number of hours of previous spots to return (maximum 168 hours) |
| bands | path | string  | true     | A comma separated list of bands to filter against, or one of either 'hf', 'vhf' or 'all' |
| modes | path | string  | true     | A comma separated list of modes to include, or 'all' for all modes. |

**Example 200 response:**

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "activatorCallsign": "string",
    "activatorName": "string",
    "callsign": "string",
    "comments": "string",
    "frequency": null,
    "mode": "string",
    "summitCode": "string",
    "summitName": "string",
    "AltM": 0,
    "AltFt": 0,
    "points": 0,
    "userID": 0,
    "type": "NORMAL"
  }
]
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Array of Spots. Store the 'epoch' field in the first spot and compare with the epoch endpoint before fetching again when different. | SpotArray |
| 400    | Bad Request | Invalid request | None |

---

### POST `/api/spots`

Add or edit a spot. If no spot ID is specified, a new spot is created. If a spot ID is specified, the spot is edited.

**Authentication required:** Yes (bearerToken)

**Body parameter:**

```json
{
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "activatorCallsign": "string",
  "callsign": "string",
  "comments": "string",
  "frequency": null,
  "mode": "string",
  "associationCode": "string",
  "summitCode": "string",
  "userID": 0,
  "type": "NORMAL"
}
```

| Name              | In   | Type             | Required | Description |
|-------------------|------|------------------|----------|-------------|
| body              | body | SpotUpload       | true     | none |
| id                | body | integer          | false    | Unique identifier for the spot. |
| timeStamp         | body | string(date-time)| false    | timestamp field. Recalculated on upload |
| activatorCallsign | body | string           | false    | Callsign of person being spotted |
| callsign          | body | string           | false    | Callsign of person who submitted the spot. Will be pulled from bearer token |
| comments          | body | string           | false    | Comments added to spot |
| frequency         | body | float            | false    | Frequency in megahertz |
| mode              | body | string           | false    | Operating mode |
| associationCode   | body | string           | false    | Association for this summit alert (eg, G) |
| summitCode        | body | string           | false    | Summit code part of summit reference (eg, TW-004) |
| userID            | body | integer          | false    | SOTA user ID for spot poster |
| type              | body | string           | false    | Either NORMAL, QRT, TEST. If unspecified, NORMAL is assumed |
| anonymous (oneOf) | body | any              | false    | A normal Spot, with frequency and mode specified |
| anonymous (xor)   | body | any              | false    | A QRT spot |
| anonymous (xor)   | body | any              | false    | A test spot |

**Example 200 response:**

```json
{
  "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "activatorCallsign": "string",
  "activatorName": "string",
  "callsign": "string",
  "comments": "string",
  "frequency": null,
  "mode": "string",
  "summitCode": "string",
  "summitName": "string",
  "AltM": 0,
  "AltFt": 0,
  "points": 0,
  "userID": 0,
  "type": "NORMAL"
}
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Spot that was inserted, with ID and epoch. | Spot |
| 400    | Bad Request | Invalid request | None |

---

### DELETE `/api/spots/{id}`

Delete a spot.

**Authentication required:** Yes (bearerToken)

| Name | In   | Type    | Required | Description |
|------|------|---------|----------|-------------|
| id   | path | integer | false    | The spot ID to delete (from the Id field of the spot object). |

**Example 200 response:**

```
"string"
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Empty string if successful. | string |
| 400    | Bad Request | Invalid request, such as trying to delete a spot the authenticated user doesn't own, or where the spot no longer exists | None |

---

### GET `/api/spots/{limit}/{filter}` *(deprecated)*

DEPRECATED. This endpoint exists only to support older clients as they transition to the new API.

**Authentication required:** No

| Name   | In   | Type    | Required | Description |
|--------|------|---------|----------|-------------|
| limit  | path | integer | true     | If positive, the number of spots to return (max 200). If negative, the number of hours of previous spots to return (maximum 168 hours) |
| filter | path | string  | true     | Ignored and treated as if 'all' |

**Example 200 response:**

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "activatorCallsign": "string",
    "activatorName": "string",
    "callsign": "string",
    "comments": "string",
    "frequency": null,
    "mode": "string",
    "summitCode": "string",
    "summitName": "string",
    "AltM": 0,
    "AltFt": 0,
    "points": 0,
    "userID": 0,
    "type": "NORMAL"
  }
]
```

| Status | Meaning     | Description | Schema |
|--------|-------------|-------------|--------|
| 200    | OK          | Array of Spots. Store the 'epoch' field in the first spot and compare with the epoch endpoint before fetching again when different. | SpotArray |
| 400    | Bad Request | Invalid request | None |

---

### GET `/rss` *(deprecated)*

DEPRECATED. Return RSS feed of last 10 spots.

**Authentication required:** No

**Parameters:** None

| Status | Meaning | Description | Schema |
|--------|---------|-------------|--------|
| 200    | OK      | none        | None   |

---

## Upload

### POST `/uploads`

Upload activations.

**Authentication required:** Yes (bearerToken)

**Body parameter:**

```json
{
  "id": 0,
  "chases": [
    {
      "date": "string",
      "timeStr": "string",
      "band": "string",
      "mode": "string",
      "ownCallsign": "string",
      "otherCallsign": "string",
      "s2sSummitCode": "string",
      "summitCode": "string",
      "notes": "string",
      "latitude": 0,
      "longitude": 0,
      "location": "string",
      "swl": true
    }
  ],
  "s2s": [
    {
      "date": "string",
      "timeStr": "string",
      "band": "string",
      "mode": "string",
      "ownCallsign": "string",
      "otherCallsign": "string",
      "s2sSummitCode": "string"
    }
  ],
  "activations": [
    {
      "qsos": [
        {
          "date": "string",
          "time": "string",
          "band": "string",
          "mode": "string",
          "callsign": "string",
          "s2sSummitCode": "string",
          "comments": "string",
          "latitude": 0,
          "longitude": 0,
          "location": "string"
        }
      ],
      "date": "string",
      "summit": "string",
      "ownCallsign": "string"
    }
  ]
}
```

| Name | In   | Type   | Required | Description |
|------|------|--------|----------|-------------|
| body | body | Upload | true     | none |

| Status | Meaning     | Description   | Schema |
|--------|-------------|---------------|--------|
| 200    | OK          | Upload result | None   |
| 400    | Bad Request | Invalid request | None |

---

## Schemas

### AlertView

```json
{
  "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "dateActivated": "2019-08-24T14:15:22Z",
  "activatingCallsign": "string",
  "activatorName": "string",
  "posterCallsign": "string",
  "comments": "string",
  "mode": "string",
  "associationCode": "string",
  "summitCode": "string",
  "summitDetails": "string",
  "frequency": "string",
  "userID": 0
}
```

| Name               | Type              | Required | Restrictions | Description |
|--------------------|-------------------|----------|--------------|-------------|
| epoch              | string(uuid)      | false    | none         | Current alerts epoch. This must be stored and compared with the output from the /api/alerts/epoch endpoint before calling this endpoint again |
| id                 | integer           | false    | none         | Unique identifier for the alert. |
| timeStamp          | string(date-time) | false    | none         | Time this alert was posted (UTC) |
| dateActivated      | string(date-time) | false    | none         | Time of the activation (UTC) |
| activatingCallsign | string            | false    | none         | Callsign of person being alerted |
| activatorName      | string            | false    | none         | Name of person being alerted |
| posterCallsign     | string            | false    | none         | Callsign of person who submitted the alert |
| comments           | string            | false    | none         | Comments added to spot |
| mode               | string            | false    | none         | Operating mode |
| associationCode    | string            | false    | none         | Association for this summit alert (eg, G) |
| summitCode         | string            | false    | none         | Summit code part of summit reference (eg, TW-004) |
| summitDetails      | string            | false    | none         | Text description of summit |
| frequency          | string            | false    | none         | List of band-mode pairs planned for this alert |
| userID             | integer           | false    | none         | SOTA user ID for alert poster |

### AlertViewArray

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "dateActivated": "2019-08-24T14:15:22Z",
    "activatingCallsign": "string",
    "activatorName": "string",
    "posterCallsign": "string",
    "comments": "string",
    "mode": "string",
    "associationCode": "string",
    "summitCode": "string",
    "summitDetails": "string",
    "frequency": "string",
    "userID": 0
  }
]
```

| Name      | Type        | Required | Restrictions | Description |
|-----------|-------------|----------|--------------|-------------|
| anonymous | [AlertView] | false    | none         | none        |

---

### Spot

```json
{
  "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "activatorCallsign": "string",
  "activatorName": "string",
  "callsign": "string",
  "comments": "string",
  "frequency": null,
  "mode": "string",
  "summitCode": "string",
  "summitName": "string",
  "AltM": 0,
  "AltFt": 0,
  "points": 0,
  "userID": 0,
  "type": "NORMAL"
}
```

| Name              | Type              | Required | Restrictions | Description |
|-------------------|-------------------|----------|--------------|-------------|
| epoch             | string(uuid)      | false    | none         | Current spots epoch. This must be stored and compared with the output from the /api/spots/epoch endpoint before calling this endpoint again |
| id                | integer           | false    | none         | Unique identifier for the spot. |
| timeStamp         | string(date-time) | false    | none         | none |
| activatorCallsign | string            | false    | none         | Callsign of person being spotted |
| activatorName     | string            | false    | none         | Name of person being spotted |
| callsign          | string            | false    | none         | Callsign of person who submitted the spot |
| comments          | string            | false    | none         | Comments added to spot |
| frequency         | float             | false    | none         | Frequency in megahertz |
| mode              | string            | false    | none         | Operating mode |
| summitCode        | string            | false    | none         | Summit reference (eg, G/TW-004) |
| summitName        | string            | false    | none         | none |
| AltM              | integer           | false    | none         | Altitude in metres |
| AltFt             | integer           | false    | none         | Altitude in feet |
| points            | integer           | false    | none         | Summit points value |
| userID            | integer           | false    | none         | SOTA user ID for spot poster |
| type              | string            | false    | none         | Either NORMAL, QRT, TEST. If unspecified, NORMAL is assumed |

**Type discriminator (oneOf):**

| Name      | Type | Required | Restrictions | Description |
|-----------|------|----------|--------------|-------------|
| anonymous | any  | false    | none         | A normal Spot, with frequency and mode specified |

**xor:**

| Name      | Type | Required | Restrictions | Description |
|-----------|------|----------|--------------|-------------|
| anonymous | any  | false    | none         | A QRT spot |

**xor:**

| Name      | Type | Required | Restrictions | Description |
|-----------|------|----------|--------------|-------------|
| anonymous | any  | false    | none         | A test spot |

### SpotArray

```json
[
  {
    "epoch": "769770d2-e9b9-4f62-b7a9-465905ac49bf",
    "id": 0,
    "timeStamp": "2019-08-24T14:15:22Z",
    "activatorCallsign": "string",
    "activatorName": "string",
    "callsign": "string",
    "comments": "string",
    "frequency": null,
    "mode": "string",
    "summitCode": "string",
    "summitName": "string",
    "AltM": 0,
    "AltFt": 0,
    "points": 0,
    "userID": 0,
    "type": "NORMAL"
  }
]
```

| Name      | Type   | Required | Restrictions | Description |
|-----------|--------|----------|--------------|-------------|
| anonymous | [Spot] | false    | none         | none        |

---

### SpotUpload

```json
{
  "id": 0,
  "timeStamp": "2019-08-24T14:15:22Z",
  "activatorCallsign": "string",
  "callsign": "string",
  "comments": "string",
  "frequency": null,
  "mode": "string",
  "associationCode": "string",
  "summitCode": "string",
  "userID": 0,
  "type": "NORMAL"
}
```

| Name              | Type              | Required | Restrictions | Description |
|-------------------|-------------------|----------|--------------|-------------|
| id                | integer           | false    | none         | Unique identifier for the spot. |
| timeStamp         | string(date-time) | false    | none         | timestamp field. Recalculated on upload |
| activatorCallsign | string            | false    | none         | Callsign of person being spotted |
| callsign          | string            | false    | none         | Callsign of person who submitted the spot. Will be pulled from bearer token |
| comments          | string            | false    | none         | Comments added to spot |
| frequency         | float             | false    | none         | Frequency in megahertz |
| mode              | string            | false    | none         | Operating mode |
| associationCode   | string            | false    | none         | Association for this summit alert (eg, G) |
| summitCode        | string            | false    | none         | Summit code part of summit reference (eg, TW-004) |
| userID            | integer           | false    | none         | SOTA user ID for spot poster |
| type              | string            | false    | none         | Either NORMAL, QRT, TEST. If unspecified, NORMAL is assumed |

**Type discriminator (oneOf):**

| Name      | Type | Required | Restrictions | Description |
|-----------|------|----------|--------------|-------------|
| anonymous | any  | false    | none         | A normal Spot, with frequency and mode specified |

**xor:**

| Name      | Type | Required | Restrictions | Description |
|-----------|------|----------|--------------|-------------|
| anonymous | any  | false    | none         | A QRT spot |

**xor:**

| Name      | Type | Required | Restrictions | Description |
|-----------|------|----------|--------------|-------------|
| anonymous | any  | false    | none         | A test spot |

---

### Upload

```json
{
  "id": 0,
  "chases": [],
  "s2s": [],
  "activations": []
}
```

| Name        | Type           | Required | Restrictions | Description |
|-------------|----------------|----------|--------------|-------------|
| id          | number         | false    | none         | If present, this is the upload ID to be edited, otherwise a new upload will be created |
| chases      | [ChaseUpload]  | false    | none         | none |
| s2s         | [ChaseUpload]  | false    | none         | none |
| activations | [Activation]   | false    | none         | none |

---

### ChaseUpload

```json
{
  "date": "string",
  "timeStr": "string",
  "band": "string",
  "mode": "string",
  "ownCallsign": "string",
  "otherCallsign": "string",
  "s2sSummitCode": "string",
  "summitCode": "string",
  "notes": "string",
  "latitude": 0,
  "longitude": 0,
  "location": "string",
  "swl": true
}
```

| Name          | Type    | Required | Restrictions | Description |
|---------------|---------|----------|--------------|-------------|
| date          | string  | false    | none         | UTC date of chase in dd/mm/yyyy format (zero-padded) |
| timeStr       | string  | false    | none         | UTC time of chase QSO in hh:mm format (zero-padded) |
| band          | string  | false    | none         | Band for QSO. SOTA bands are specific enumerations, such as 3.5MHz, 7MHz, 10MHz. Invalid entries will flag an error |
| mode          | string  | false    | none         | Mode for QSO. One of AM, CW, DATA, DV, FM, SSB, OTHER |
| ownCallsign   | string  | false    | none         | Callsign of chaser |
| otherCallsign | string  | false    | none         | Callsign of activator |
| s2sSummitCode | string  | false    | none         | location of remote/activator's summit |
| summitCode    | string  | false    | none         | location of chaser's summit if S2S |
| notes         | string  | false    | none         | Any comments or notes for this QSO |
| latitude      | number  | false    | none         | latitude of chaser (-90.0000 to 90.0000) |
| longitude     | number  | false    | none         | longitude of chaser (-180.0000 to 180.0000) |
| location      | string  | false    | none         | String of chaser location, either lat/long pair (such as '-12.345,123.456') or maidenhead locator (6 or 8 figures) |
| swl           | boolean | false    | none         | Must be set to true if chase was a SWL chase (heard only), false for a normal chase |

---

### Activation

```json
{
  "qsos": [
    {
      "date": "string",
      "time": "string",
      "band": "string",
      "mode": "string",
      "callsign": "string",
      "s2sSummitCode": "string",
      "comments": "string",
      "latitude": 0,
      "longitude": 0,
      "location": "string"
    }
  ],
  "date": "string",
  "summit": "string",
  "ownCallsign": "string"
}
```

| Name        | Type   | Required | Restrictions | Description |
|-------------|--------|----------|--------------|-------------|
| qsos        | [QSO]  | false    | none         | Array of QSO entries for this activation |
| date        | string | false    | none         | Date of Activation, in dd/mm/yyyy format (zero-padded). For activations that span a UTC day, only the first date is used. |
| summit      | string | false    | none         | Summit activated, eg, VK3/VE-001 |
| ownCallsign | string | false    | none         | Callsign used by activator |

---

### QSO

```json
{
  "date": "string",
  "time": "string",
  "band": "string",
  "mode": "string",
  "callsign": "string",
  "s2sSummitCode": "string",
  "comments": "string",
  "latitude": 0,
  "longitude": 0,
  "location": "string"
}
```

| Name          | Type   | Required | Restrictions | Description |
|---------------|--------|----------|--------------|-------------|
| date          | string | false    | none         | UTC date of Activation QSO in dd/mm/yyyy format (zero-padded) |
| time          | string | false    | none         | UTC time of Activation QSO in hhmm format (zero-padded) |
| band          | string | false    | none         | Band for QSO. SOTA bands are specific enumerations, such as 3.5MHz, 7MHz, 10MHz. Invalid entries will flag an error |
| mode          | string | false    | none         | Mode for QSO. One of AM, CW, DATA, DV, FM, SSB, OTHER |
| callsign      | string | false    | none         | Callsign of chaser |
| s2sSummitCode | string | false    | none         | If chaser is on a summit (ie, S2S) the location of remote summit |
| comments      | string | false    | none         | Any comments or notes for this QSO |
| latitude      | number | false    | none         | latitude of chaser (-90.0000 to 90.0000) |
| longitude     | number | false    | none         | longitude of chaser (-180.0000 to 180.0000) |
| location      | string | false    | none         | String of chaser location, either lat/long pair (such as '-12.345,123.456') or maidenhead locator (6 or 8 figures) |

---

### UploadResult

```json
{
  "id": 0,
  "error": "string",
  "chaser": 0,
  "s2s": 0,
  "activator": []
}
```

| Name      | Type   | Required | Restrictions | Description |
|-----------|--------|----------|--------------|-------------|
| id        | number | false    | none         | Upload ID |
| error     | string | false    | none         | Error message from upload process |
| chaser    | number | false    | none         | Chaser points total |
| s2s       | number | false    | none         | S2S points total |
| activator | array  | false    | none         | Tuple of activators points - total points, activator points and bonus points (activator + bonus = total) |
