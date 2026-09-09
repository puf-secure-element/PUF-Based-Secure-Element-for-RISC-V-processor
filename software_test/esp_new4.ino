/*
  esp8266_bridge.ino -- ESP8266 làm cầu nối WiFi <-> UART (FPGA)
  Chuẩn giao thức Khung: [STX][CMD][LEN][PAYLOAD][CRC][ETX]

  Nối dây:
    D5 (GPIO14) --> RX của mạch UART-TTL/FPGA
    D6 (GPIO12) <-- TX của mạch UART-TTL/FPGA
    GND         --- GND chung
*/

#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <ESP8266HTTPClient.h>
#include <SoftwareSerial.h>
#include <ArduinoJson.h>

const char* WIFI_SSID     = "Hehe";
const char* WIFI_PASSWORD = "123456789";
const char* BACKEND_URL   = "http://192.168.1.20:5000";
const char* DEVICE_ID     = "0001";
const char* ESP32_SECRET  = "demo-secret-change-me"; 

const unsigned long POLL_INTERVAL_MS = 1500;

SoftwareSerial fpgaSerial(D5, D6);  // RX, TX
const long FPGA_BAUD = 9600;

// Các định nghĩa Byte điều khiển và Mã lệnh
const uint8_t STX = 0x02;
const uint8_t ETX = 0x03;
const uint8_t CMD_ENROLL_REQUEST  = 0x01;
const uint8_t CMD_ENROLL_RESPONSE = 0x81;
const uint8_t CMD_AUTH_CHALLENGE  = 0x02;
const uint8_t CMD_AUTH_RESPONSE   = 0x82;

WiFiClientSecure secureClient;
WiFiClient plainClient;

bool isHttps(const String& url) {
  return url.startsWith("https://");
}

void setup() {
  Serial.begin(115200);
  fpgaSerial.begin(FPGA_BAUD);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Đang kết nối WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial.print(".");
  }
  Serial.println("\nWiFi OK, IP: " + WiFi.localIP().toString());
  secureClient.setInsecure();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Mất WiFi, thử kết nối lại...");
    WiFi.reconnect();
    delay(2000);
    return;
  }
  
  checkPendingAndProcess(); // Xử lý Auth
  checkPendingEnroll();     // Xử lý Enroll
  delay(POLL_INTERVAL_MS);
}

// ========================================================
// 1. TÁC VỤ AUTHENTICATION (XÁC THỰC CHALLENGE / RESPONSE)
// ========================================================

void checkPendingAndProcess() {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/auth/pending?device_id=" + DEVICE_ID;
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) return;

  int code = http.GET();
  if (code == 204) { http.end(); return; }
  if (code != 200) { http.end(); return; }

  String body = http.getString();
  http.end();

  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, body)) return;

  String sessionId = doc["session_id"].as<String>();
  String nonceHex   = doc["nonce"].as<String>();
  Serial.println("\n--- [AUTH] Phát hiện phiên mới: " + sessionId + " | Nonce: " + nonceHex);

  String cipherHex = sendNonceToBoardAndGetCipher(nonceHex);
  if (cipherHex.length() == 0) {
    Serial.println("[AUTH] Lỗi: Không nhận được Cipher hợp lệ từ FPGA");
    return;
  }
  postBoardResponse(sessionId, cipherHex);
}

String sendNonceToBoardAndGetCipher(const String& nonceHex) {
  // Xóa sạch rác trong buffer nhận trước khi gửi
  while (fpgaSerial.available()) fpgaSerial.read();

  uint8_t nonce[16];
  hexStringToBytes(nonceHex, nonce, 16);

  // Tính CRC cho 16 byte Payload
  uint8_t crc = 0;
  for (int i = 0; i < 16; i++) crc ^= nonce[i];

  // Gửi khung: [STX][CMD][LEN][PAYLOAD][CRC][ETX]
  fpgaSerial.write(STX);
  fpgaSerial.write(CMD_AUTH_CHALLENGE);
  fpgaSerial.write((uint8_t)16);
  fpgaSerial.write(nonce, 16);
  fpgaSerial.write(crc);
  fpgaSerial.write(ETX);
  Serial.println("[AUTH] -> Đã gửi Frame Challenge sang FPGA");

  // Chờ tối thiểu 3 byte Header (STX, CMD, LEN)
  unsigned long startWait = millis();
  while (fpgaSerial.available() < 3) {
    if (millis() - startWait > 5000) {
      Serial.println("[AUTH] Timeout chờ Header phản hồi từ FPGA");
      return "";
    }
    delay(5);
  }

  uint8_t stx = fpgaSerial.read();
  uint8_t cmd = fpgaSerial.read();
  uint8_t len = fpgaSerial.read();

  if (stx != STX || cmd != CMD_AUTH_RESPONSE) {
    Serial.printf("[AUTH] Frame sai header! STX: 0x%02X, CMD: 0x%02X\n", stx, cmd);
    return "";
  }

  // Đọc Payload (16 byte Cipher)
  uint8_t payload[64];
  int received = 0;
  startWait = millis();
  while (received < len) {
    if (fpgaSerial.available()) payload[received++] = fpgaSerial.read();
    if (millis() - startWait > 3000) return "";
  }

  // Đọc 2 byte cuối (CRC và ETX)
  startWait = millis();
  while (fpgaSerial.available() < 2) {
    if (millis() - startWait > 1000) break;
  }
  fpgaSerial.read(); // CRC
  fpgaSerial.read(); // ETX

  String cipher = bytesToHexString(payload, len);
  Serial.println("[AUTH] <- Nhận thành công Cipher: " + cipher);
  return cipher;
}

void postBoardResponse(const String& sessionId, const String& cipherHex) {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/auth/board_response";
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) return;

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Secret", ESP32_SECRET);

  StaticJsonDocument<256> doc;
  doc["session_id"] = sessionId;
  doc["cipher"] = cipherHex;
  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  Serial.printf("[AUTH] Đã gửi board_response lên server (Code: %d)\n", code);
  http.end();
}

// ========================================================
// 2. TÁC VỤ ENROLL (ĐĂNG KÝ HELPER DATA & KHÓA)
// ========================================================

void checkPendingEnroll() {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/enroll/pending?device_id=" + DEVICE_ID;
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) return;

  int code = http.GET();
  if (code == 204) { http.end(); return; }
  if (code != 200) { http.end(); return; }

  String body = http.getString();
  http.end();

  StaticJsonDocument<128> doc;
  if (deserializeJson(doc, body)) return;
  String jobId = doc["job_id"].as<String>();
  Serial.println("\n--- [ENROLL] Phát hiện Job mới: " + jobId);

  String helperHex, keyHex;
  if (!sendEnrollRequestAndGetResult(helperHex, keyHex)) {
    Serial.println("[ENROLL] Thất bại khi lấy dữ liệu từ FPGA");
    return;
  }
  postEnrollResponse(jobId, helperHex, keyHex);
}

bool sendEnrollRequestAndGetResult(String& helperHexOut, String& keyHexOut) {
  // Xóa sạch rác trong buffer nhận trước khi gửi yêu cầu mới
  while (fpgaSerial.available()) fpgaSerial.read();

  uint8_t crc = 0; // Payload rỗng -> CRC = 0

  // Gửi đúng khung yêu cầu: [STX][0x01][LEN=0][CRC=0][ETX]
  fpgaSerial.write(STX);
  fpgaSerial.write(CMD_ENROLL_REQUEST);
  fpgaSerial.write((uint8_t)0);
  fpgaSerial.write(crc);
  fpgaSerial.write(ETX);
  Serial.println("[ENROLL] -> Đã gửi Frame Enroll Request sang FPGA");

  // Chờ 3 byte Header (STX, CMD, LEN) - Timeout 10s vì PUF đo phần cứng mất thời gian
  unsigned long startWait = millis();
  while (fpgaSerial.available() < 3) {
    if (millis() - startWait > 10000) {
      Serial.printf("[ENROLL] Timeout chờ phản hồi (Chỉ nhận được %d byte trong đệm)\n", fpgaSerial.available());
      return false;
    }
    delay(10);
  }

  uint8_t stx = fpgaSerial.read();
  uint8_t cmd = fpgaSerial.read();
  uint8_t len = fpgaSerial.read();

  Serial.printf("[ENROLL] Header nhận được: STX=0x%02X, CMD=0x%02X, LEN=%d\n", stx, cmd, len);

  if (stx != STX || cmd != CMD_ENROLL_RESPONSE || len != 28) {
    Serial.println("[ENROLL] Lỗi: Frame phản hồi sai định dạng chuẩn!");
    return false;
  }

  // Đọc đủ 28 byte payload (12 byte Helper Data + 16 byte Key)
  uint8_t payload[28];
  int received = 0;
  startWait = millis();
  while (received < 28) {
    if (fpgaSerial.available()) {
      payload[received++] = fpgaSerial.read();
    }
    if (millis() - startWait > 5000) {
      Serial.printf("[ENROLL] Lỗi: Bị nghẽn, chỉ nhận được %d/28 byte payload\n", received);
      return false;
    }
  }

  // Đọc nốt 2 byte cuối (CRC, ETX)
  startWait = millis();
  while (fpgaSerial.available() < 2) {
    if (millis() - startWait > 1000) break;
  }
  fpgaSerial.read(); // CRC
  fpgaSerial.read(); // ETX

  helperHexOut = bytesToHexString(payload, 12);
  keyHexOut    = bytesToHexString(payload + 12, 16);

  Serial.println("[ENROLL] <- Nhận thành công dữ liệu từ FPGA:");
  Serial.println("         Helper Data (12B): " + helperHexOut);
  Serial.println("         Key (16B)        : " + keyHexOut);

  return true;
}

void postEnrollResponse(const String& jobId, const String& helperHex, const String& keyHex) {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/enroll/board_response";
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) return;

  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Secret", ESP32_SECRET);

  StaticJsonDocument<256> doc;
  doc["job_id"] = jobId;
  doc["helper_data"] = helperHex;
  doc["key"] = keyHex;
  String body;
  serializeJson(doc, body);

  int code = http.POST(body);
  Serial.printf("[ENROLL] Đã gửi kết quả Enroll lên server (Code: %d)\n", code);
  http.end();
}

// ========================================================
// 3. CÁC HÀM TIỆN ÍCH BIẾN ĐỔI DỮ LIỆU
// ========================================================

void hexStringToBytes(const String& hex, uint8_t* out, int outLen) {
  for (int i = 0; i < outLen; i++) {
    out[i] = strtoul(hex.substring(i * 2, i * 2 + 2).c_str(), nullptr, 16);
  }
}

String bytesToHexString(const uint8_t* data, int len) {
  String result = "";
  for (int i = 0; i < len; i++) {
    if (data[i] < 0x10) result += "0";
    result += String(data[i], HEX);
  }
  result.toUpperCase();
  return result;
}