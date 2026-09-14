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

  checkForBootEnrollFrame(); // Âm thầm bắt khung Enroll nếu FPGA vừa reset
  checkPendingAndProcess();  // Xử lý Auth
  checkPendingEnroll();      // Gửi lên backend nếu đã có job + đã bắt được khung
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
//
// RTL không có bộ phân giải lệnh STX/CMD/LEN cho Enroll -- FPGA tự động
// phát ra đúng 1 khung Enroll response duy nhất ngay sau khi PUF->ECC->SHA
// chạy xong lúc mới boot/reset (không chờ ESP gửi yêu cầu). Vì vậy ESP
// không "hỏi rồi đợi" nữa, mà âm thầm lắng nghe khung này xuất hiện bất cứ
// lúc nào (thường là ngay sau khi người dùng bấm KEY0 reset board), cache
// lại, rồi khi backend báo có job Enroll đang chờ thì gửi cache đó lên.
//
// Khung nhận về (căn chỉnh 4-byte, khớp firmware Instruction_memory.v):
//   byte 0-3:   STX(0x02) CMD(0x81) LEN(0x2C) RESERVED
//   byte 4-15:  12 byte Helper Data
//   byte 16-47: 32 byte Key
//   byte 48-51: CRC ETX(0x03) RESERVED RESERVED

bool   enrollFrameCaptured = false;
String cachedHelperHex, cachedKeyHex;

void checkForBootEnrollFrame() {
  if (enrollFrameCaptured) return;   // đã bắt được rồi, không cần nghe nữa
  if (!Serial.available()) return;

  uint8_t stx = Serial.read();
  if (stx != STX) return;            // byte rác/không liên quan, bỏ qua

  // Còn 51 byte nữa sau STX (CMD,LEN,RESERVED + 44 payload + CRC,ETX,x2 RESERVED).
  // Nếu đúng là khung Enroll thật, cả 51 byte này tới gần như ngay lập tức
  // (52 byte @ 115200 baud ~ 4.5ms) -- timeout ngắn là đủ, không chặn Auth lâu.
  uint8_t rest[51];
  int received = 0;
  unsigned long startWait = millis();
  while (received < 51) {
    if (Serial.available()) {
      rest[received++] = Serial.read();
    }
    if (millis() - startWait > 200) {
      return; // STX rơi lẻ, không có gì theo sau -- không phải khung Enroll thật
    }
  }

  uint8_t cmd = rest[0];
  uint8_t len = rest[1];
  if (cmd != CMD_ENROLL_RESPONSE || len != 44) {
    return; // trùng STX ngẫu nhiên, không phải khung Enroll -- bỏ qua
  }

  uint8_t* payload      = rest + 3;   // 44 byte: rest[3..46]
  uint8_t  receivedCrc  = rest[47];
  uint8_t  receivedEtx  = rest[48];

  uint8_t calculatedCrc = 0;
  for (int i = 0; i < 44; ++i) calculatedCrc ^= payload[i];

  if (receivedEtx != ETX || receivedCrc != calculatedCrc) {
    Serial1.printf("[ENROLL] Bắt được khung nhưng CRC/ETX sai (crc nhận=0x%02X tính=0x%02X etx=0x%02X) -- bỏ qua\n",
                  receivedCrc, calculatedCrc, receivedEtx);
    return;
  }

  cachedHelperHex = bytesToHexString(payload, 12);
  cachedKeyHex    = bytesToHexString(payload + 12, 32);
  enrollFrameCaptured = true;

  Serial1.println("\n--- [ENROLL] Bắt được khung Enroll tự động từ FPGA:");
  Serial1.println("         Helper Data (12B): " + cachedHelperHex);
  Serial1.println("         Key (32B)        : " + cachedKeyHex);
}

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

  if (!enrollFrameCaptured) {
    Serial1.println("\n--- [ENROLL] Job " + jobId + " đang chờ, nhưng chưa bắt được khung Enroll từ FPGA.");
    Serial1.println("    Bấm KEY0 reset board FPGA -- nó sẽ tự phát khung Enroll, ESP sẽ tự bắt ở loop() kế tiếp.");
    return;
  }

  Serial1.println("\n--- [ENROLL] Gửi dữ liệu đã cache cho Job: " + jobId);
  postEnrollResponse(jobId, cachedHelperHex, cachedKeyHex);
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
