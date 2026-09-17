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

// BACKEND_URL must match the host IP on whatever network is active -- check
// with `ip addr show` after every network switch, it is DHCP and moves.
const char* WIFI_SSID     = "Hehe";
const char* WIFI_PASSWORD = "123456789";
const char* BACKEND_URL = "http://10.238.250.137:5000";
//const char* WIFI_SSID     = "EELA2201";
//const char* WIFI_PASSWORD = "eela2201";
//const char* BACKEND_URL = "http://192.168.0.3:5000";
//const char* WIFI_SSID     = "Nhu Ngoc";
//const char* WIFI_PASSWORD = "nn7677032022";
//const char* BACKEND_URL = "http://192.168.1.52:5000";
//const char* WIFI_SSID     = "Nhi";
//const char* WIFI_PASSWORD = "0909794900";
//const char* BACKEND_URL = "http://192.168.1.105:5000";
// Bump this whenever the sketch changes so the boot log names the build.
#define BUILD_TAG "2026-09-17d-recon"

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
// Board phát khung này ngay sau reset để xin lại helper data của lần
// Enroll trước; có helper thì nó chạy ECC Reconstruction và dẫn xuất lại
// đúng khóa cũ thay vì sinh khóa mới.
const uint8_t CMD_HELPER_REQUEST  = 0x84;

WiFiClientSecure secureClient;
WiFiClient plainClient;

bool isHttps(const String& url) {
  return url.startsWith("https://");
}

void setup() {
  Serial.begin(FPGA_BAUD);   // Serial (UART0, GPIO1/3) dành riêng cho FPGA
  Serial1.begin(115200);     // Serial1 (TX-only, GPIO2) dùng để log debug
  Serial1.println("\n[BOOT] Reset reason: " + ESP.getResetReason());

  // Identify which build is actually on the chip. There are several stray
  // copies of this sketch around, and more than one debugging session has
  // been spent on a symptom whose real cause was the IDE compiling an older
  // one. These four lines make the running firmware say so itself, so the
  // boot log settles it instead of guesswork.
  Serial1.println("[BOOT] build   : " BUILD_TAG);
  Serial1.println("[BOOT] ssid    : " + String(WIFI_SSID));
  Serial1.println("[BOOT] backend : " + String(BACKEND_URL));
  Serial1.printf ("[BOOT] secret  : %d ky tu, bat dau bang '%c'\n",
                  strlen(ESP32_SECRET), ESP32_SECRET[0]);

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

  http.addHeader("X-Device-Secret", ESP32_SECRET);
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

// Đọc đúng n byte, bỏ cuộc sau timeoutMs. Khung thật tới liền mạch ở 115200
// (52 byte ~ 4.5 ms) nên timeout ngắn là đủ, không chặn tác vụ Auth lâu.
bool readExactly(uint8_t* buf, int n, unsigned long timeoutMs) {
  int got = 0;
  unsigned long t0 = millis();
  while (got < n) {
    if (Serial.available()) { buf[got++] = Serial.read(); t0 = millis(); }
    else if (millis() - t0 > timeoutMs) return false;
    yield();
  }
  return true;
}

// Board gửi 4x16 byte vì MANUAL_TX làm việc theo khối, nên sau phần khung có
// thật luôn còn byte đệm. Nuốt cho hết để chúng không bị báo là byte lạ.
void drainPadding(int frameLen) {
  int pad = (16 - (frameLen % 16)) % 16;
  unsigned long t0 = millis();
  int done = 0;
  while (done < pad && millis() - t0 < 50) {
    if (Serial.available()) { Serial.read(); done++; }
  }
}

String fetchHelperFromBackend() {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/helper?device_id=" + DEVICE_ID;
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) return "";
  http.addHeader("X-Device-Secret", ESP32_SECRET);
  int code = http.GET();
  if (code != 200) {
    if (code == 204) Serial1.println("    Backend chưa có helper cho thiết bị này.");
    else             Serial1.printf("    Backend trả HTTP %d khi xin helper\n", code);
    http.end();
    return "";
  }
  String body = http.getString();
  http.end();
  StaticJsonDocument<192> doc;
  if (deserializeJson(doc, body)) return "";
  return doc["helper_data"].as<String>();
}

// Board vừa reset và đang chờ helper. Nó chờ khoảng 5 giây rồi mới bỏ cuộc
// và tự chạy Enrollment, nên trả lời ngay trong vòng lặp này là kịp.
void handleHelperRequest() {
  Serial1.println("\n--- [RECON] Board xin helper data để chạy Reconstruction");
  String helperHex = fetchHelperFromBackend();
  if (helperHex.length() != 24) {
    Serial1.println("    Không có helper hợp lệ -- để board tự chạy Enroll và sinh khóa mới.");
    return;
  }
  uint8_t block[16];
  hexStringToBytes(helperHex, block, 12);
  // 4 byte magic để firmware phân biệt khối helper với nhiễu hoặc với nonce Auth
  block[12] = 0xA5; block[13] = 0x5A; block[14] = 0xC3; block[15] = 0x3C;
  Serial.write(block, 16);
  Serial.flush();
  Serial1.println("    Đã gửi helper xuống board: " + helperHex);
}

void checkForBootEnrollFrame() {
  // Deliberately keeps listening after the first capture, overwriting the
  // cache each time. The FPGA derives a fresh key on every KEY0 reset (ECC
  // runs in Enrollment mode, so the key is SHA over that boot's raw PUF
  // response), which means a cached frame goes stale the moment the board is
  // reset. Stopping after one capture made the ESP upload the key from an
  // earlier boot while the board was already using a different one -- an
  // Enroll that reported success and an Auth that then failed, with no sign
  // of which of the two was wrong.
  // Discard everything ahead of a frame start in one pass. Dropping a single
  // byte per loop() meant 1.5 s per byte: the 12 padding bytes that always
  // trail a frame took 18 s to clear, and resynchronising from the middle of
  // one took over a minute, during which a genuine frame could not be seen.
  int skipped = 0;
  while (Serial.available() && Serial.peek() != STX) {
    Serial.read();
    skipped++;
  }
  if (skipped) {
    Serial1.printf("[ENROLL-DEBUG] Bo qua %d byte trước khi tìm thấy STX\n", skipped);
  }
  if (!Serial.available()) return;
  Serial.read();   // nuốt chính byte STX

  Serial1.println("[ENROLL-DEBUG] Thấy STX (0x02) trên Serial -- đang đợi 51 byte còn lại...");

  // Đọc CMD, LEN, RESERVED rồi mới biết còn bao nhiêu byte nữa. Board phát
  // hai loại khung khác độ dài: CMD=0x81 (Enroll, LEN=44) và CMD=0x84 (xin
  // helper, LEN=0), nên không thể đọc cứng một con số như trước.
  uint8_t hdr[3];
  if (!readExactly(hdr, 3, 200)) {
    Serial1.println("[FRAME] Timeout khi đọc CMD/LEN sau STX -- không phải khung thật");
    return;
  }
  uint8_t cmd = hdr[0];
  uint8_t len = hdr[1];

  if (cmd == CMD_HELPER_REQUEST && len == 0) {
    uint8_t tail[2];                       // CRC + ETX
    if (!readExactly(tail, 2, 200)) return;
    if (tail[1] != ETX) return;
    drainPadding(6);                       // STX + 3 + CRC + ETX
    handleHelperRequest();
    return;
  }

  if (cmd != CMD_ENROLL_RESPONSE || len != 44) {
    Serial1.printf("[FRAME] Khung lạ: CMD=0x%02X LEN=%d -- bỏ qua\n", cmd, len);
    return;
  }

  uint8_t body[46];                        // 44 payload + CRC + ETX
  if (!readExactly(body, 46, 200)) {
    Serial1.println("[ENROLL-DEBUG] Timeout giữa chừng khung Enroll");
    return;
  }
  Serial1.printf("[ENROLL-DEBUG] Khung Enroll đủ byte. CMD=0x%02X LEN=%d\n", cmd, len);

  uint8_t* payload      = body;            // 44 byte
  uint8_t  receivedCrc  = body[44];
  uint8_t  receivedEtx  = body[45];

  uint8_t calculatedCrc = 0;
  for (int i = 0; i < 44; ++i) calculatedCrc ^= payload[i];

  if (receivedEtx != ETX || receivedCrc != calculatedCrc) {
    Serial1.printf("[ENROLL] Bắt được khung nhưng CRC/ETX sai (crc nhận=0x%02X tính=0x%02X etx=0x%02X) -- bỏ qua\n",
                  receivedCrc, calculatedCrc, receivedEtx);
    return;
  }

  bool refreshed = enrollFrameCaptured && (cachedKeyHex != bytesToHexString(payload + 12, 32));
  cachedHelperHex = bytesToHexString(payload, 12);
  cachedKeyHex    = bytesToHexString(payload + 12, 32);
  enrollFrameCaptured = true;

  if (refreshed) {
    Serial1.println("\n--- [ENROLL] Khung MOI -- khoa da doi so voi lan truoc (board vua reset).");
    Serial1.println("    Cache da duoc cap nhat; hay bam Enroll lai de backend luu khoa moi.");
  }
  Serial1.println("\n--- [ENROLL] Bắt được khung Enroll tự động từ FPGA:");
  Serial1.println("         Helper Data (12B): " + cachedHelperHex);
  Serial1.println("         Key (32B)        : " + cachedKeyHex);

  drainPadding(50);   // STX + 3 + 44 + CRC + ETX = 50, khung đệm lên 64
}

void checkPendingEnroll() {
  HTTPClient http;
  String url = String(BACKEND_URL) + "/api/enroll/pending?device_id=" + DEVICE_ID;
  bool ok = isHttps(url) ? http.begin(secureClient, url) : http.begin(plainClient, url);
  if (!ok) {
    Serial1.println("[ENROLL] Không mở được kết nối tới backend: " + url);
    return;
  }

  http.addHeader("X-Device-Secret", ESP32_SECRET);
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
