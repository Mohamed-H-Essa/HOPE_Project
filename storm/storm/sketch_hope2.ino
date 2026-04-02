#include <Wire.h>
#include <MPU6050.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

MPU6050 mpu;

// ===== Flex (2) =====
int flexPins[2] = {1, 2};
int flexZero[2] = {610, 1740};
int flexMax[2]  = {1850, 900};

// ===== FSR =====
int fsrPins[2] = {3, 4};
int fsrMin[2] = {800, 800};
int fsrMax[2] = {3800, 3800};

// ===== EMG =====
#define EMG_PIN 0   // ADC1

int16_t ax, ay, az, gx, gy, gz;

// ===== WiFi =====
const char* ssid     = "YOUR_WIFI";
const char* password = "YOUR_PASSWORD";

// ===== Backend =====
// The glove only knows its own ID and where to send data.
// The backend decides what phase the session is in.
const char* DEVICE_ID  = "hope-glove-01";
const char* INGEST_URL = "https://unj4s6yf6b.execute-api.us-east-1.amazonaws.com/prod/ingest";

// ===== Sample buffer =====
// 100 samples at 50ms intervals = 5 seconds of data per batch
#define NUM_SAMPLES 100
struct Sample {
  unsigned long t;
  int flex1, flex2;
  int fsr1, fsr2;
  int emg;
  int16_t ax, ay, az, gx, gy, gz;
};
Sample buf[NUM_SAMPLES];


// ──────────────────────────────────────────────────────────
int readFast(int pin) {
  return analogRead(pin);
}


// ──────────────────────────────────────────────────────────
// Read all sensors into a Sample struct
// ──────────────────────────────────────────────────────────
Sample readSensors() {
  Sample s;
  s.t = millis();

  mpu.getMotion6(&s.ax, &s.ay, &s.az, &s.gx, &s.gy, &s.gz);

  for (int i = 0; i < 2; i++) {
    int raw        = readFast(flexPins[i]);
    int calibrated = raw - flexZero[i];
    if (calibrated < 0) calibrated = 0;
    int range = flexMax[i] - flexZero[i];
    int angle = constrain(map(calibrated, 0, range, 0, 90), 0, 90);
    if (i == 0) s.flex1 = angle; else s.flex2 = angle;
  }

  for (int i = 0; i < 2; i++) {
    int raw   = readFast(fsrPins[i]);
    int force = constrain(map(raw, fsrMin[i], fsrMax[i], 100, 0), 0, 100);
    if (i == 0) s.fsr1 = force; else s.fsr2 = force;
  }

  int rawEMG = analogRead(EMG_PIN);
  s.emg = abs(rawEMG - 2000) * 2;

  return s;
}


// ──────────────────────────────────────────────────────────
// Collect NUM_SAMPLES samples at 50ms intervals into buf[]
// ──────────────────────────────────────────────────────────
void collectSamples() {
  Serial.println("Collecting samples...");
  for (int i = 0; i < NUM_SAMPLES; i++) {
    buf[i] = readSensors();
    delay(50);
  }
  Serial.println("Collection done.");
}


// ──────────────────────────────────────────────────────────
// POST buf[] to /ingest. Returns HTTP response code.
// The glove sends only device_id and raw data.
// The backend determines the phase from session status.
// ──────────────────────────────────────────────────────────
int postIngest(String &responseBody) {
  // Build JSON: {"device_id":"...","data":[{...},{...},...]}
  // 100 samples x ~100 chars each + wrapper = ~12KB, well within API Gateway's 10MB limit.
  String payload;
  payload.reserve(13000);

  payload = "{\"device_id\":\"";
  payload += DEVICE_ID;
  payload += "\",\"data\":[";

  for (int i = 0; i < NUM_SAMPLES; i++) {
    if (i > 0) payload += ",";
    payload += "{\"time\":";  payload += (unsigned long)buf[i].t;
    payload += ",\"flex1\":"; payload += buf[i].flex1;
    payload += ",\"flex2\":"; payload += buf[i].flex2;
    payload += ",\"fsr1\":";  payload += buf[i].fsr1;
    payload += ",\"fsr2\":";  payload += buf[i].fsr2;
    payload += ",\"emg\":";   payload += buf[i].emg;
    payload += ",\"ax\":";    payload += (int)buf[i].ax;
    payload += ",\"ay\":";    payload += (int)buf[i].ay;
    payload += ",\"az\":";    payload += (int)buf[i].az;
    payload += ",\"gx\":";    payload += (int)buf[i].gx;
    payload += ",\"gy\":";    payload += (int)buf[i].gy;
    payload += ",\"gz\":";    payload += (int)buf[i].gz;
    payload += "}";
  }
  payload += "]}";

  WiFiClientSecure client;
  client.setInsecure(); // Skip TLS cert check — URL is hardcoded and trusted

  HTTPClient http;
  http.begin(client, INGEST_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(20000); // 20s — allows for Lambda cold-start

  int code = http.POST(payload);
  if (code > 0) {
    responseBody = http.getString();
  } else {
    responseBody = "";
  }
  http.end();
  return code;
}


// ──────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Wire.begin(8, 9);
  mpu.initialize();
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  delay(2000);
  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected!");
}


// ──────────────────────────────────────────────────────────
// Main loop:
//
// The glove is dumb. It collects a batch of 100 samples and
// POSTs them to /ingest with only its device_id.
// The backend decides whether this is an assessment or
// exercise batch based on the session's current status.
//
// Cycle:
//   1. Collect 100 samples (5 seconds at 50ms each)
//   2. POST to /ingest
//      - 200: batch accepted → wait 5s then repeat for next batch
//      - 404: no session linked yet → wait 3s and retry
//      - other: error → wait 3s and retry
// ──────────────────────────────────────────────────────────
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost, reconnecting...");
    WiFi.reconnect();
    delay(3000);
    return;
  }

  collectSamples();

  String resp;
  int code = postIngest(resp);
  Serial.print("HTTP code: "); Serial.println(code);

  if (code == 200) {
    Serial.println("Batch accepted.");
    delay(5000); // Brief pause before collecting the next batch

  } else if (code == 404) {
    Serial.println("No active session. Waiting for app to link device...");
    delay(3000);

  } else {
    Serial.print("Error (");
    Serial.print(code);
    Serial.println("), retrying in 3s...");
    delay(3000);
  }
}
