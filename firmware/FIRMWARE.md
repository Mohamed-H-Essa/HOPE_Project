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
      "time": 0,
      "flex1": 45, "flex2": 38,
      "fsr1": 62, "fsr2": 55,
      "emg": 340,
      "ax": 1024, "ay": -512, "az": 16384,
      "gx": 100, "gy": -50, "gz": 30
    },
    ... (99 more samples)
  ]
}
```

## Sensors

| Sensor | Pins | Range | What It Measures |
|--------|------|-------|-----------------|
| 2x Flex | ADC 1, 2 | 0-90° | Finger bend angle |
| 2x FSR | ADC 3, 4 | 0-100 | Grip force |
| EMG | ADC 0 | Raw ADC | Muscle electrical activity |
| MPU6050 IMU | I2C (SDA=8, SCL=9) | 6-DOF | Acceleration + rotation |

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
