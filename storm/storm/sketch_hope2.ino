#include <Wire.h>
#include <MPU6050.h>
#include <WiFi.h>
#include <HTTPClient.h>

MPU6050 mpu;

// ===== Flex (2 ) =====
int flexPins[2] = {1,2};
int flexZero[2] = {610,1740};
int flexMax[2]  = {1850,900};

// ===== FSR =====
int fsrPins[2] = {3,4};
int fsrMin[2] = {800,800};
int fsrMax[2] = {3800,3800};

// ===== EMG =====
#define EMG_PIN 0   //  ADC1

int16_t ax, ay, az, gx, gy, gz;

// ===== WiFi Config =====
const char* ssid = "YOUR_WIFI";
const char* password = "YOUR_PASSWORD";

// ===== Backend URL =====
const char* serverName = "http://192.168.x.x:5000/data"; //  IP   

int readFast(int pin){
  return analogRead(pin);
}

void setup() {
  Serial.begin(115200);
  Wire.begin(8,9);
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
  Serial.println("\nConnected to WiFi!");
}

void loop() {
  unsigned long t = millis();

  // ===== IMU =====
  mpu.getMotion6(&ax,&ay,&az,&gx,&gy,&gz);

  // ===== FLEX =====
  int flexVals[2];
  for(int i=0;i<2;i++){
    int raw = readFast(flexPins[i]);
    int calibrated = raw - flexZero[i];
    if(calibrated < 0) calibrated = 0;
    int range = flexMax[i] - flexZero[i];
    int angle = map(calibrated,0,range,0,90);
    angle = constrain(angle,0,90);
    flexVals[i] = angle;
  }

  // ===== FSR =====
  int fsrVals[2];
  for(int i=0;i<2;i++){
    int raw = readFast(fsrPins[i]);
    int force = map(raw, fsrMin[i], fsrMax[i], 100, 0);
    force = constrain(force,0,100);
    fsrVals[i] = force;
  }

  // ===== EMG =====
  int rawEMG = analogRead(EMG_PIN);
  int baseline = 2000;
  int centered = rawEMG - baseline;
  int emgProcessed = abs(centered) * 2;

  // ===== JSON Data =====
  String jsonData = "[{";
  jsonData += "\"time\":" + String(t) + ",";
  jsonData += "\"flex1\":" + String(flexVals[0]) + ",";
  jsonData += "\"flex2\":" + String(flexVals[1]) + ",";
  jsonData += "\"fsr1\":" + String(fsrVals[0]) + ",";
  jsonData += "\"fsr2\":" + String(fsrVals[1]) + ",";
  jsonData += "\"emg\":" + String(emgProcessed) + ",";
  jsonData += "\"ax\":" + String(ax) + ",";
  jsonData += "\"ay\":" + String(ay) + ",";
  jsonData += "\"az\":" + String(az) + ",";
  jsonData += "\"gx\":" + String(gx) + ",";
  jsonData += "\"gy\":" + String(gy) + ",";
  jsonData += "\"gz\":" + String(gz);
  jsonData += "}]";

  Serial.println(jsonData); // 

  // ===== Send to Backend =====
  if(WiFi.status() == WL_CONNECTED){
    HTTPClient http;
    http.begin(serverName);
    http.addHeader("Content-Type", "application/json");
    int httpResponseCode = http.POST(jsonData);
    if(httpResponseCode>0){
      Serial.print("HTTP Response code: ");
      Serial.println(httpResponseCode);
    } else {
      Serial.print("Error sending POST: ");
      Serial.println(httpResponseCode);
    }
    http.end();
  } else {
    Serial.println("WiFi Disconnected!");
  }

  delay(50); // 
}