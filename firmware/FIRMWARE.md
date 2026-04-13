# HOPE Glove Firmware

## Overview

Arduino sketch for ESP32 Dev Module. The glove is a **dumb sensor-streaming device** that sends raw data over WiFi to the backend. It has zero knowledge of sessions, assessment logic, or exercise types.

## Communication

- **Transport:** WiFi → HTTPS POST
- **Endpoint:** `https://unj4s6yf6b.execute-api.us-east-1.amazonaws.com/prod/ingest`
- **Protocol:** Plain HTTP POST with JSON body. No Bluetooth. No direct connection to phone.

## What It Sends

Every 5 seconds, the glove collects 100 sensor samples (at 50ms intervals) and sends them as a single batch:

```json
{
  "device_id": "hope-glove-01",
  "data": [
    {
      "time": 19136,
      "flex1": 45, "flex2": 38,
      "fsr1": 62, "fsr2": 55,
      "emg": 340,
      "ax": 1024, "ay": -512, "az": 16384,
      "gx": 100, "gy": -50, "gz": 30
    },
    ... (99 more samples, `time` increments by ~50 ms)
  ]
}
```

## Sensors

This is the **canonical schema** for the `data[]` items in the `/ingest` payload. All other docs (`docs/api.md`, `flutter_app/docs/api_contract.md`, etc.) must match this table.

| Field | Pin(s) | Type | Range | Units | Meaning |
|---|---|---|---|---|---|
| `time` | — | uint32 | `millis()` since boot (monotonic) | ms | **Not** zero-reset per batch. Sample spacing ≈ 50 ms. |
| `flex1`, `flex2` | ADC 1, 2 | int | 0–90 | degrees | Finger bend angle (linearly calibrated, constrained). Finger 2 calibration is reversed (`FLEX_ZERO=1740 > FLEX_MAX=900`). |
| `fsr1`, `fsr2` | ADC 3, 4 | int | 0–100 | percent | Grip force percentage. **0 = no force, 100 = max force.** Calibration `FSR_MIN=800` (no force) → `FSR_MAX=3800` (full force). |
| `emg` | ADC 0 | int | ~0–4000 | rectified magnitude | `abs(rawADC - 2000) * 2`. **Not raw ADC** — centered at 2000 and doubled. |
| `ax`, `ay`, `az` | I2C (MPU6050) | int16 | ±32768 LSB | raw | Accelerometer at default FS_SEL=0 (±2g, 16384 LSB/g). A stationary glove reads ≈ ±16384 on the gravity axis. |
| `gx`, `gy`, `gz` | I2C (MPU6050) | int16 | ±32768 LSB | raw | Gyroscope at default FS_SEL=0 (±250°/s, 131 LSB per °/s). |

MPU6050 I2C pins: SDA=8, SCL=9. If `testConnection()` fails at boot the firmware still continues — on some MPU6050 boards the test is a false negative but `getMotion6()` still returns valid data (look for `az ≈ 16384` at rest to confirm).

## Behavior

1. Boot → connect to WiFi
2. Collect 100 samples over 5 seconds
3. POST batch to `/ingest`
4. If 200 OK → wait 5s → repeat
5. If 404 (no active session) → retry every 3s
6. If error → retry every 3s (reconnect WiFi if needed)

## Key Facts

- The glove does NOT know which session it belongs to. The backend figures that out by matching `device_id`.
- The glove does NOT know if it's in assessment or exercise mode. Same data, same endpoint.
- TLS connection is reused across requests to avoid re-handshake overhead.
- HTTP timeout is 30 seconds (covers Lambda cold-start).

## When to Reflash

Only if the API Gateway URL changes (i.e., after a full `teardown.sh` + `deploy.sh`). Update `INGEST_URL` in `hope_glove.ino`.
