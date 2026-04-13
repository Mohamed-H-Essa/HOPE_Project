// ============================================================
// HOPE Smart Rehabilitation Glove — Firmware
// ============================================================
//
// REQUIRED LIBRARIES (install via Arduino IDE → Library Manager):
//   • "MPU6050" by Electronic Cats  (also installs I2Cdev dependency)
//   • "ArduinoJson" by Benoit Blanchon  ← NOT needed; removed
//
// WiFiClientSecure and HTTPClient are bundled with the ESP32
// Arduino core — no separate install needed.
//
// BOARD: ESP32 Dev Module (ESP32 Arduino core 2.x)
//
// BEFORE FLASHING: fill in WiFi credentials below.
// Everything else is pre-configured.
// ============================================================

#include <Wire.h>
#include <MPU6050.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// ============================================================
// CONFIG — only edit this section
// ============================================================
const char* WIFI_SSID     = "YOUR_WIFI";
const char* WIFI_PASSWORD = "YOUR_PASSWORD";

// Device ID must match what the Flutter app links via PUT /sessions/{id}/device
const char* DEVICE_ID  = "hope-glove-01";

// Full URL to the /ingest endpoint. Only changes if you run teardown.sh and redeploy.
const char* INGEST_URL = "https://unj4s6yf6b.execute-api.us-east-1.amazonaws.com/prod/ingest";
// ============================================================

// ===== I2C pins for MPU6050 =====
#define I2C_SDA 8
#define I2C_SCL 9

// ===== Flex sensor pins & calibration =====
// flex[0] = finger 1, flex[1] = finger 2
const int FLEX_PINS[2]  = {1, 2};
const int FLEX_ZERO[2]  = {610, 1740};   // ADC value when fully straight
const int FLEX_MAX[2]   = {1850, 900};   // ADC value when fully bent to 90°

// ===== FSR (pressure) sensor pins & calibration =====
const int FSR_PINS[2] = {3, 4};
const int FSR_MIN[2]  = {800, 800};      // ADC value = no force
const int FSR_MAX[2]  = {3800, 3800};    // ADC value = full force

// ===== EMG pin =====
#define EMG_PIN 0
const int EMG_BASELINE = 2000;           // midpoint of the centered EMG signal

// ===== Sampling =====
#define NUM_SAMPLES 100                  // 100 samples × 50ms = 5 seconds per batch

// ============================================================
// Globals — declared here so they live on the heap, not the
// stack, avoiding TLS session churn and heap fragmentation.
// ============================================================
MPU6050 mpu;
WiFiClientSecure tlsClient;
HTTPClient http;

// Static JSON buffer — avoids repeated heap alloc/free of a 13KB String each loop.
// Max size: ~130 bytes per sample × 100 samples + 50 byte header = ~13050 bytes.
static char jsonBuf[14000];

struct Sample {
  unsigned long t;
  int flex1, flex2;
  int fsr1, fsr2;
  int emg;
  int16_t ax, ay, az, gx, gy, gz;
};
Sample buf[NUM_SAMPLES];


// ============================================================
// Read one sample from all sensors
// ============================================================
Sample readSensors() {
  Sample s;
  s.t = millis();

  mpu.getMotion6(&s.ax, &s.ay, &s.az, &s.gx, &s.gy, &s.gz);

  for (int i = 0; i < 2; i++) {
    int raw        = analogRead(FLEX_PINS[i]);
    int calibrated = raw - FLEX_ZERO[i];
    if (calibrated < 0) calibrated = 0;
    int range = FLEX_MAX[i] - FLEX_ZERO[i];
    int angle = constrain(map(calibrated, 0, range, 0, 90), 0, 90);
    if (i == 0) s.flex1 = angle; else s.flex2 = angle;
  }

  for (int i = 0; i < 2; i++) {
    int raw   = analogRead(FSR_PINS[i]);
    int force = constrain(map(raw, FSR_MIN[i], FSR_MAX[i], 0, 100), 0, 100);
    if (i == 0) s.fsr1 = force; else s.fsr2 = force;
  }

  int rawEMG = analogRead(EMG_PIN);
  s.emg = abs(rawEMG - EMG_BASELINE) * 2;

  return s;
}


// ============================================================
// Collect NUM_SAMPLES into buf[] at 50ms intervals
// ============================================================
void collectSamples() {
  Serial.println("[GLOVE] Collecting 100 samples...");
  for (int i = 0; i < NUM_SAMPLES; i++) {
    buf[i] = readSensors();
    delay(50);
  }
  Serial.println("[GLOVE] Collection done.");
}


// ============================================================
// Build JSON into jsonBuf[] and POST to /ingest.
// Returns the HTTP response code (200 = success, 404 = no
// session linked yet, negative = network error).
// responseBody is filled with the server's response string.
// ============================================================
int postIngest(String &responseBody) {
  // Build JSON: {"device_id":"...","data":[{...},...]}
  // Using a static char buffer avoids heap fragmentation from
  // repeated 13KB String alloc/free cycles.
  int pos = 0;
  pos += snprintf(jsonBuf + pos, sizeof(jsonBuf) - pos,
                  "{\"device_id\":\"%s\",\"data\":[", DEVICE_ID);

  for (int i = 0; i < NUM_SAMPLES && pos < (int)sizeof(jsonBuf) - 200; i++) {
    if (i > 0) {
      jsonBuf[pos++] = ',';
    }
    pos += snprintf(jsonBuf + pos, sizeof(jsonBuf) - pos,
      "{\"time\":%lu,\"flex1\":%d,\"flex2\":%d,"
      "\"fsr1\":%d,\"fsr2\":%d,\"emg\":%d,"
      "\"ax\":%d,\"ay\":%d,\"az\":%d,"
      "\"gx\":%d,\"gy\":%d,\"gz\":%d}",
      buf[i].t,
      buf[i].flex1, buf[i].flex2,
      buf[i].fsr1, buf[i].fsr2, buf[i].emg,
      (int)buf[i].ax, (int)buf[i].ay, (int)buf[i].az,
      (int)buf[i].gx, (int)buf[i].gy, (int)buf[i].gz
    );
  }

  // Close the JSON
  pos += snprintf(jsonBuf + pos, sizeof(jsonBuf) - pos, "]}");

  Serial.printf("[GLOVE] Payload size: %d bytes\n", pos);

  // POST using the global HTTPClient + WiFiClientSecure.
  // setReuse(true) keeps the TLS connection alive between requests,
  // avoiding a full TLS re-handshake on every batch (saves ~500ms).
  http.begin(tlsClient, INGEST_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(30000);  // 30s: covers Lambda cold-start (~3-15s) + processing

  int code = http.POST((uint8_t*)jsonBuf, pos);

  if (code > 0) {
    responseBody = http.getString();
    Serial.printf("[GLOVE] HTTP %d: %s\n", code, responseBody.c_str());
  } else {
    responseBody = "";
    Serial.printf("[GLOVE] POST error: %s\n", http.errorToString(code).c_str());
  }

  http.end();
  return code;
}


// ============================================================
// WiFi reconnect — reliable pattern for ESP32 core 2.x
// ============================================================
void reconnectWiFi() {
  Serial.println("[GLOVE] WiFi lost, reconnecting...");
  WiFi.disconnect();
  WiFi.reconnect();
  // Wait up to 15s for reconnection
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 15000) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[GLOVE] WiFi reconnected.");
  } else {
    Serial.println("\n[GLOVE] Reconnect failed, will retry next loop.");
  }
}


// ============================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n[GLOVE] HOPE Glove firmware starting...");

  // I2C for MPU6050
  Wire.begin(I2C_SDA, I2C_SCL);
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("[GLOVE] ERROR: MPU6050 not detected. Check I2C wiring (SDA=8, SCL=9).");
    // Continue anyway — sensor data will be zeroed but the glove won't brick
  } else {
    Serial.println("[GLOVE] MPU6050 OK.");
  }

  // ADC config
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  // TLS client — global, reused across all requests
  tlsClient.setInsecure();  // Skip cert verification — URL is hardcoded

  // HTTPClient — persistent connection reuse to avoid TLS re-handshake every batch
  http.setReuse(true);

  // Prevent WiFi credentials being written to flash on every begin()
  WiFi.persistent(false);

  Serial.printf("[GLOVE] Connecting to WiFi: %s\n", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\n[GLOVE] WiFi connected. IP: %s\n", WiFi.localIP().toString().c_str());
  Serial.println("[GLOVE] Ready. Waiting for app to start a session...");
}


// ============================================================
// Main loop:
//
// The glove is dumb. It collects 100 samples and POSTs them
// to /ingest with only its device_id.
// The backend decides the phase from the session's status:
//   - not yet assessed → runs assessment logic
//   - already assessed → runs exercise logic (using the first
//                         item from needed_training)
//
// Responses:
//   200  → batch accepted, wait 5s then collect next batch
//   404  → no session linked yet, wait 3s and retry
//   400  → bad request (should never happen with correct firmware)
//   -ve  → network/TLS error, wait 3s and retry
// ============================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    reconnectWiFi();
    return;
  }

  collectSamples();

  String resp;
  int code = postIngest(resp);

  if (code == 200) {
    Serial.println("[GLOVE] Batch accepted. Waiting 5s before next batch...");
    delay(5000);

  } else if (code == 404) {
    Serial.println("[GLOVE] No active session. Waiting for app to link device...");
    delay(3000);

  } else if (code > 0) {
    // HTTP error from server (400, 500, etc.) — log and retry
    Serial.printf("[GLOVE] Server error %d. Retrying in 3s...\n", code);
    delay(3000);

  } else {
    // Network/TLS error — negative code
    delay(3000);
  }
}
