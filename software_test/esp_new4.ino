/*
  esp8266_bridge.ino -- ESP8266 làm cầu nối WiFi <-> UART (FPGA)
  Chuẩn giao thức Khung: [STX][CMD][LEN][PAYLOAD][CRC][ETX]

  Đường FPGA dùng UART PHẦN CỨNG thật của ESP8266 (Serial, GPIO1/GPIO3) để
  tránh lỗi bit-bang của SoftwareSerial khi WiFi đang chạy song song ở baud
  cao (115200). Log debug chuyển sang Serial1 (chỉ truyền, GPIO2/D4).

  Nối dây:
    GPIO1 (TX0, chân "TX")  --> RX của mạch UART-TTL/FPGA
    GPIO3 (RX0, chân "RX")  <-- TX của mạch UART-TTL/FPGA
    GND                     --- GND chung

  Xem log debug (không dùng để nạp code lúc này vì GPIO1/3 đang bận với FPGA):
    Cắm 1 bộ USB-TTL khác vào GPIO2 (D4, TX1) + GND chung, mở terminal
    (vd simple_uart_listener.py hoặc `screen /dev/ttyUSBx 115200`) chỉ để xem,
    không gửi gì (Serial1 không có RX).
*/

#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <ESP8266HTTPClient.h>
#include <ArduinoJson.h>

const char* WIFI_SSID     = "Nhu Ngoc";
const char* WIFI_PASSWORD = "nn7677032022";
const char* BACKEND_URL = "http://192.168.1.52:5000";
//const char* WIFI_SSID     = "Hehe";
//const char* WIFI_PASSWORD = "123456789";
//const char* BACKEND_URL = "http://10.152.89.151:5000";
//const char* WIFI_SSID     = "Nhi";
//const char* WIFI_PASSWORD = "0909794900";
//const char* BACKEND_URL = "http://192.168.1.105:5000";
const char* DEVICE_ID     = "0001";
const char* ESP32_SECRET  = "demo-secret-change-me";


const unsigned long POLL_INTERVAL_MS = 1500;

// FPGA giờ nối qua UART phần cứng (Serial), không còn dùng SoftwareSerial.
const long FPGA_BAUD = 115200;

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
  Serial.begin(FPGA_BAUD);   // Serial (UART0, GPIO1/3) dành riêng cho FPGA
  Serial1.begin(115200);     // Serial1 (TX-only, GPIO2) dùng để log debug
  Serial1.println("\n[BOOT] Reset reason: " + ESP.getResetReason());

  // Force clean station mode before connecting. Without this, a stale
  // AP/AP+STA state left over from a crash or previous sketch can make
  // WiFi.begin() hang indefinitely instead of connecting.
  WiFi.disconnect(true);
  WiFi.mode(WIFI_STA);
  delay(100);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial1.print("Đang kết nối WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(400);
    Serial1.print(".");
  }
  Serial1.println("\nWiFi OK, IP: " + WiFi.localIP().toString());
  secureClient.setInsecure();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial1.println("Mất WiFi, thử kết nối lại...");
    WiFi.reconnect();
    delay(2000);
    return;
  }

  checkPendingAndProcess(); // Xử lý Auth
  // checkPendingEnroll();  // TẠM TẮT: RTL hiện chưa có command dispatcher
  // STX/CMD/LEN nào cho Enroll, gọi hàm này sẽ luôn timeout 30s mỗi 1.5s.
  // Bật lại khi phần cứng hỗ trợ Enroll thật.
  delay(POLL_INTERVAL_MS);
}

// ========================================================
// 1. TÁC VỤ AUTHENTICATION (XÁC THỰC CHALLENGE / RESPONSE)
// ========================================================

void checkPendingAndProcess() {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/auth/pending?device_id=" + DEVICE_ID;
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) {
    Serial1.println("[AUTH] Không mở được kết nối tới backend: " + url);
    return;
  }

  int code = http.GET();
  if (code < 0) Serial1.printf("[AUTH] HTTP lỗi: %s\n", http.errorToString(code).c_str());
  if (code == 204) { http.end(); return; }
  if (code != 200) { http.end(); return; }

  String body = http.getString();
  http.end();

  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, body)) return;

  String sessionId = doc["session_id"].as<String>();
  String nonceHex   = doc["nonce"].as<String>();
  Serial1.println("\n--- [AUTH] Phát hiện phiên mới: " + sessionId + " | Nonce: " + nonceHex);

  String cipherHex = sendNonceToBoardAndGetCipher(nonceHex);
  if (cipherHex.length() == 0) {
    Serial1.println("[AUTH] Lỗi: Không nhận được Cipher hợp lệ từ FPGA");
    return;
  }
  postBoardResponse(sessionId, cipherHex);
}

String sendNonceToBoardAndGetCipher(const String& nonceHex) {
  while (Serial.available()) Serial.read();

  uint8_t nonce[16];
  hexStringToBytes(nonceHex, nonce, 16);

  Serial.write(nonce, 16);
  Serial.flush();
  Serial1.println("[AUTH] -> Đã gửi 16 byte nonce thô sang FPGA");

  uint8_t cipher[16];
  int received = 0;
  unsigned long lastByte = millis();
  unsigned long lastReport = lastByte;

  while (received < 16) {
    if (Serial.available()) {
      cipher[received++] = Serial.read();
      lastByte = millis();
    }
    if (millis() - lastReport >= 1000) {
      Serial1.printf("[AUTH] Chờ cipher: %d/16 byte\n", received);
      lastReport = millis();
    }
    if (millis() - lastByte > 5000) {
      Serial1.printf("[AUTH] Timeout, chỉ nhận %d/16 byte\n", received);
      return "";
    }
    yield();
  }

  String cipherHex = bytesToHexString(cipher, 16);
  Serial1.println("[AUTH] <- Cipher: " + cipherHex);
  return cipherHex;
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
  Serial1.printf("[AUTH] Đã gửi ciphertext lên server (Code: %d)\n", code);
  http.end();
}

// ========================================================
// 2. TÁC VỤ ENROLL (ĐĂNG KÝ HELPER DATA & KHÓA)
// ========================================================

void checkPendingEnroll() {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/enroll/pending?device_id=" + DEVICE_ID;
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) {
    Serial1.println("[ENROLL] Không mở được kết nối tới backend: " + url);
    return;
  }

  int code = http.GET();
  if (code < 0) Serial1.printf("[ENROLL] HTTP lỗi: %s\n", http.errorToString(code).c_str());
  if (code == 204) { http.end(); return; }
  if (code != 200) {
    Serial1.printf("[ENROLL] Backend trả HTTP %d\n", code);
    http.end();
    return;
  }

  String body = http.getString();
  http.end();

  StaticJsonDocument<128> doc;
  if (deserializeJson(doc, body)) return;
  String jobId = doc["job_id"].as<String>();
  Serial1.println("\n--- [ENROLL] Phát hiện Job mới: " + jobId);

  String helperHex, keyHex;
  if (!sendEnrollRequestAndGetResult(helperHex, keyHex)) {
    Serial1.println("[ENROLL] Thất bại khi lấy dữ liệu từ FPGA");
    return;
  }
  postEnrollResponse(jobId, helperHex, keyHex);
}

bool sendEnrollRequestAndGetResult(String& helperHexOut, String& keyHexOut) {
  // Xóa sạch rác trong buffer nhận trước khi gửi yêu cầu mới
  while (Serial.available()) Serial.read();

  uint8_t crc = 0; // Payload rỗng -> CRC = 0

  // Gửi đúng khung yêu cầu: [STX][0x01][LEN=0][CRC=0][ETX]
  Serial.write(STX);
  Serial.write(CMD_ENROLL_REQUEST);
  Serial.write((uint8_t)0);
  Serial.write(crc);
  Serial.write(ETX);
  Serial.flush();
  Serial1.printf("[ENROLL] -> Đã gửi 5 byte: 02 01 00 00 03, FPGA baud=%ld\n", FPGA_BAUD);
  Serial1.printf("[ENROLL] RX buffer ngay sau gửi: %d byte\n", Serial.available());

  // PUF hardware measurement may take time, but report progress instead of
  // hiding whether the UART receives anything.
  unsigned long startWait = millis();
  unsigned long lastReport = startWait;
  while (Serial.available() < 3) {
    if (millis() - lastReport >= 1000) {
      Serial1.printf("[ENROLL] Đang chờ header: %lu ms, RX buffer=%d byte\n",
                    millis() - startWait, Serial.available());
      lastReport = millis();
    }
    if (millis() - startWait > 30000) {
      Serial1.printf("[ENROLL] Timeout chờ phản hồi (Chỉ nhận được %d byte trong đệm)\n", Serial.available());
      return false;
    }
    delay(10);
  }

  uint8_t stx = Serial.read();
  uint8_t cmd = Serial.read();
  uint8_t len = Serial.read();

  Serial1.printf("[ENROLL] Header nhận được: STX=0x%02X, CMD=0x%02X, LEN=%d\n", stx, cmd, len);

  if (stx != STX || cmd != CMD_ENROLL_RESPONSE || len != 44) {
    Serial1.println("[ENROLL] Lỗi: Frame phản hồi sai định dạng chuẩn!");
    return false;
  }

  // Đọc đủ 44 byte payload (12 byte Helper Data + 32 byte AES-256 key)
  uint8_t payload[44];
  int received = 0;
  startWait = millis();
  while (received < 44) {
    if (Serial.available()) {
      payload[received++] = Serial.read();
    }
    if (millis() - startWait > 5000) {
      Serial1.printf("[ENROLL] Lỗi: Bị nghẽn, chỉ nhận được %d/44 byte payload\n", received);
      return false;
    }
  }

  // Đọc nốt 2 byte cuối (CRC, ETX), with explicit diagnostics.
  startWait = millis();
  while (Serial.available() < 2) {
    if (millis() - startWait > 5000) {
      Serial1.printf("[ENROLL] Timeout CRC/ETX, còn %d byte trong đệm\n",
                    Serial.available());
      return false;
    }
    delay(2);
  }
  uint8_t receivedCrc = Serial.read();
  uint8_t receivedEtx = Serial.read();
  uint8_t calculatedCrc = 0;
  for (int i = 0; i < 44; ++i) calculatedCrc ^= payload[i];
  Serial1.printf("[ENROLL] CRC nhận=0x%02X tính=0x%02X ETX=0x%02X\n",
                receivedCrc, calculatedCrc, receivedEtx);
  if (receivedCrc != calculatedCrc || receivedEtx != ETX) {
    Serial1.println("[ENROLL] Lỗi CRC hoặc ETX");
    return false;
  }

  helperHexOut = bytesToHexString(payload, 12);
  keyHexOut    = bytesToHexString(payload + 12, 32);

  Serial1.println("[ENROLL] <- Nhận thành công dữ liệu từ FPGA:");
  Serial1.println("         Helper Data (12B): " + helperHexOut);
  Serial1.println("         Key (32B)        : " + keyHexOut);

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
  Serial1.printf("[ENROLL] Đã gửi kết quả Enroll lên server (Code: %d)\n", code);
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
