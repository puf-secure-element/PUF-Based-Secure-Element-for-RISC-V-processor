"""
app.py -- Backend Flask cho hệ thống PUF-based Security qua ESP8266 & FPGA
Chạy lệnh: python app.py
Truy cập:  http://localhost:5000 (hoặc http://IP_MAY_TINH:5000)
"""

import os
import secrets
import sqlite3
from flask import Flask, jsonify, request

try:
    from Crypto.Cipher import AES as _AES

    def _aes256_ecb_encrypt(key: bytes, block: bytes) -> bytes:
        return _AES.new(key, _AES.MODE_ECB).encrypt(block)
except ImportError:  # dự phòng nếu môi trường chỉ có 'cryptography'
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

    def _aes256_ecb_encrypt(key: bytes, block: bytes) -> bytes:
        enc = Cipher(algorithms.AES(key), modes.ECB()).encryptor()
        return enc.update(block) + enc.finalize()

DB_PATH = "devices.db"
# Khóa bí mật xác thực giữa ESP8266 và Backend (tránh thiết bị lạ gửi request giả)
ESP32_SECRET = os.environ.get("ESP32_SECRET", "demo-secret-change-me")

# Nonce chỉ có hiệu lực trong khoảng thời gian này. Hết hạn thì ESP không lấy
# được nữa và kết quả gửi lên muộn cũng bị từ chối -> chặn replay bằng nonce cũ.
NONCE_TTL_SECONDS = int(os.environ.get("NONCE_TTL_SECONDS", "60"))


def require_device_secret() -> bool:
    """Chỉ thiết bị (ESP8266) biết secret này. Web UI không được gọi các API
    dành cho thiết bị."""
    return request.headers.get("X-Device-Secret") == ESP32_SECRET


def fpga_key_to_aes_key(key_bytes: bytes) -> bytes:
    """Đổi 32 byte khóa theo thứ tự FPGA gửi lên -> thứ tự khóa AES chuẩn.

    Firmware gửi KEY_OUT_0 (= hash_out[31:0]) trước, KEY_OUT_7
    (= hash_out[255:224]) sau cùng; mỗi word 32-bit đi ra MSB trước.
    Nhưng aes.v nạp khóa theo w[0] = key_in[255:224] -> 4 byte ĐẦU của khóa
    AES chuẩn chính là nhóm CUỐI trong luồng gửi. Vì vậy chỉ cần đảo thứ tự
    8 nhóm 4-byte, giữ nguyên byte bên trong mỗi nhóm.
    """
    groups = [key_bytes[i:i + 4] for i in range(0, 32, 4)]
    return b"".join(reversed(groups))


def compute_expected_cipher(key_ref_hex, nonce_hex):
    """Tính ciphertext mà một thiết bị hợp lệ PHẢI trả về.

    Trả về (cipher_hex, loi). cipher_hex = None nếu không tính được.
    """
    try:
        key_raw = bytes.fromhex(key_ref_hex or "")
    except ValueError:
        return None, "key_ref không phải chuỗi hex (thiết bị chưa Enroll thật)"
    if len(key_raw) != 32:
        return None, f"key_ref dài {len(key_raw)} byte, cần đúng 32 (AES-256)"

    try:
        nonce = bytes.fromhex(nonce_hex or "")
    except ValueError:
        return None, "nonce không phải chuỗi hex"
    if len(nonce) != 16:
        return None, f"nonce dài {len(nonce)} byte, cần đúng 16"

    return _aes256_ecb_encrypt(fpga_key_to_aes_key(key_raw), nonce).hex(), None

app = Flask(__name__, static_folder="../static", static_url_path="")

# Tự động khởi tạo DB nếu chưa có
def init_db_if_not_exists():
    conn = sqlite3.connect(DB_PATH)
    conn.executescript("""
    CREATE TABLE IF NOT EXISTS devices (
        device_id   TEXT PRIMARY KEY,
        helper_data TEXT NOT NULL,
        key_ref     TEXT NOT NULL,
        created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS auth_sessions (
        session_id  TEXT PRIMARY KEY,
        device_id   TEXT NOT NULL,
        nonce       TEXT NOT NULL,
        status      TEXT DEFAULT 'pending',
        cipher      TEXT,
        created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (device_id) REFERENCES devices(device_id)
    );
    CREATE TABLE IF NOT EXISTS enroll_jobs (
        job_id      TEXT PRIMARY KEY,
        device_id   TEXT NOT NULL,
        status      TEXT DEFAULT 'pending',
        helper_data TEXT,
        key_hex     TEXT,
        created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    """)
    conn.close()

init_db_if_not_exists()

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

@app.route("/")
def index():
    return app.send_static_file("index.html")

@app.route("/api/devices", methods=["GET"])
def list_devices():
    conn = get_db()
    rows = conn.execute("SELECT device_id, created_at FROM devices").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])

# =========================================================================
# 1. API CHO TÁC VỤ ENROLLMENT (ĐĂNG KÝ THIẾT BỊ)
# =========================================================================

@app.route("/api/enroll/start", methods=["POST"])
def enroll_start():
    """Web App bấm 'Enroll' -> Tạo Job mới"""
    data = request.get_json(force=True)
    device_id = data.get("device_id")
    if not device_id:
        return jsonify({"error": "Thiếu device_id"}), 400

    job_id = secrets.token_hex(8)
    conn = get_db()
    conn.execute(
        "INSERT INTO enroll_jobs (job_id, device_id, status) VALUES (?, ?, 'pending')",
        (job_id, device_id),
    )
    conn.commit()
    conn.close()
    print(f"\n[ENROLL] Web yêu cầu tạo Job mới: {job_id} cho Device: {device_id}")
    return jsonify({"job_id": job_id, "status": "pending"})

@app.route("/api/enroll/pending", methods=["GET"])
def enroll_pending():
    """ESP8266 hỏi: 'Có Job Enroll nào cần làm không?'"""
    if not require_device_secret():
        return jsonify({"error": "Unauthorized"}), 401

    device_id = request.args.get("device_id")
    if not device_id:
        return jsonify({"error": "Thiếu device_id"}), 400

    conn = get_db()
    row = conn.execute(
        "SELECT job_id FROM enroll_jobs WHERE device_id = ? AND status = 'pending' ORDER BY created_at ASC LIMIT 1",
        (device_id,),
    ).fetchone()
    if not row:
        conn.close()
        return jsonify({}), 204  # Không có Job nào

    conn.execute("UPDATE enroll_jobs SET status = 'sent_to_board' WHERE job_id = ?", (row["job_id"],))
    conn.commit()
    conn.close()
    print(f"[ENROLL] Giao Job {row['job_id']} cho ESP8266 xử lý...")
    return jsonify({"job_id": row["job_id"]})

@app.route("/api/enroll/board_response", methods=["POST"])
def enroll_board_response():
    """ESP8266 báo cáo kết quả hoàn tất Enroll"""
    if request.headers.get("X-Device-Secret") != ESP32_SECRET:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(force=True)
    job_id = data.get("job_id")
    helper_data_hex = data.get("helper_data", "")
    key_hex = data.get("key", "")

    conn = get_db()
    job = conn.execute("SELECT * FROM enroll_jobs WHERE job_id = ?", (job_id,)).fetchone()
    if not job:
        conn.close()
        return jsonify({"error": "Job không tồn tại"}), 404

    # Lưu thiết bị vào danh sách hoạt động chính thức
    conn.execute(
        "INSERT OR REPLACE INTO devices (device_id, helper_data, key_ref) VALUES (?, ?, ?)",
        (job["device_id"], helper_data_hex, key_hex),
    )
    conn.execute(
        "UPDATE enroll_jobs SET status = 'done', helper_data = ?, key_hex = ? WHERE job_id = ?",
        (helper_data_hex, key_hex, job_id),
    )
    conn.commit()
    conn.close()
    print(f"[ENROLL] Hoàn tất đăng ký thành công cho Device: {job['device_id']}")
    return jsonify({"status": "done"})

@app.route("/api/enroll/result/<job_id>", methods=["GET"])
def enroll_result(job_id):
    """Web App polling để xem khi nào Enroll xong"""
    conn = get_db()
    job = conn.execute("SELECT * FROM enroll_jobs WHERE job_id = ?", (job_id,)).fetchone()
    conn.close()
    if not job:
        return jsonify({"error": "Job không tồn tại"}), 404
    return jsonify({"status": job["status"], "helper_data": job["helper_data"]})

# =========================================================================
# 2. API CHO TÁC VỤ AUTHENTICATION (XÁC THỰC CHALLENGE-RESPONSE)
# =========================================================================

@app.route("/api/auth/start", methods=["POST"])
def auth_start():
    """Web App bấm 'Authenticate' -> Sinh Nonce 16 bytes ngẫu nhiên"""
    data = request.get_json(force=True)
    device_id = data.get("device_id")
    if not device_id:
        return jsonify({"error": "Thiếu device_id"}), 400

    conn = get_db()
    device = conn.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,)).fetchone()
    if not device:
        conn.close()
        return jsonify({"error": f"Device {device_id} chưa được Enroll"}), 404

    # Sinh Nonce ngẫu nhiên đúng chuẩn 16 bytes (128 bits)
    nonce = secrets.token_bytes(16)
    session_id = secrets.token_hex(8)

    conn.execute(
        "INSERT INTO auth_sessions (session_id, device_id, nonce, status) VALUES (?, ?, ?, 'pending')",
        (session_id, device_id, nonce.hex()),
    )
    conn.commit()
    conn.close()

    print(f"\n[AUTH] Web tạo phiên xác thực mới: {session_id}")
    print(f"       Nonce (16-byte): {nonce.hex().upper()}")
    return jsonify({"session_id": session_id, "status": "pending"})

@app.route("/api/auth/pending", methods=["GET"])
def auth_pending():
    """ESP8266 hỏi: 'Có phiên Auth nào cần Nonce không?'"""
    if not require_device_secret():
        return jsonify({"error": "Unauthorized"}), 401

    device_id = request.args.get("device_id")
    if not device_id:
        return jsonify({"error": "Thiếu device_id"}), 400

    conn = get_db()
    row = conn.execute(
        "SELECT session_id, nonce FROM auth_sessions "
        "WHERE device_id = ? AND status = 'pending' "
        "  AND created_at > datetime('now', ?) "
        "ORDER BY created_at ASC LIMIT 1",
        (device_id, f"-{NONCE_TTL_SECONDS} seconds"),
    ).fetchone()
    if not row:
        conn.close()
        return jsonify({}), 204

    conn.execute("UPDATE auth_sessions SET status = 'sent_to_board' WHERE session_id = ?", (row["session_id"],))
    conn.commit()
    conn.close()
    return jsonify({"session_id": row["session_id"], "nonce": row["nonce"]})

@app.route("/api/auth/board_response", methods=["POST"])
def auth_board_response():
    """ESP8266 gửi Ciphertext 16 bytes thu được từ FPGA lên"""
    if request.headers.get("X-Device-Secret") != ESP32_SECRET:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(force=True)
    session_id = data.get("session_id")
    cipher_hex = data.get("cipher", "").strip().lower()

    conn = get_db()
    session = conn.execute(
        "SELECT * FROM auth_sessions WHERE session_id = ? "
        "  AND created_at > datetime('now', ?)",
        (session_id, f"-{NONCE_TTL_SECONDS} seconds"),
    ).fetchone()
    if not session:
        conn.close()
        return jsonify({"error": "Phiên xác thực không tồn tại hoặc đã hết hạn"}), 404

    device = conn.execute(
        "SELECT key_ref FROM devices WHERE device_id = ?", (session["device_id"],)
    ).fetchone()

    # TIÊU CHUẨN XÁC THỰC THẬT:
    # Backend tự tính AES-256(khóa đã lưu lúc Enroll, nonce của phiên này) rồi
    # so sánh với ciphertext thiết bị gửi lên. Chỉ thiết bị có đúng PUF mới
    # dẫn xuất ra đúng khóa đó -> mới mã hóa ra đúng kết quả.
    if not device:
        expected_hex, err = None, "thiết bị chưa được Enroll"
    else:
        expected_hex, err = compute_expected_cipher(device["key_ref"], session["nonce"])

    if expected_hex is None:
        passed, reason = False, err
    elif cipher_hex == expected_hex:
        passed, reason = True, "ciphertext khớp"
    else:
        passed, reason = False, "ciphertext KHÔNG khớp"

    new_status = "passed" if passed else "failed"

    conn.execute(
        "UPDATE auth_sessions SET status = ?, cipher = ? WHERE session_id = ?",
        (new_status, cipher_hex, session_id),
    )
    conn.commit()
    conn.close()

    print(f"[AUTH] Nhận kết quả từ Board cho Session: {session_id}")
    print(f"       Nonce:      {session['nonce']}")
    print(f"       Nhận được:  {cipher_hex}")
    if expected_hex is not None:
        print(f"       Kỳ vọng:    {expected_hex}")
        if not passed:
            # Gợi ý hiệu chỉnh: nếu bản KHÔNG đảo nhóm byte lại khớp, nghĩa là
            # fpga_key_to_aes_key() đang đảo thừa -> bỏ phép đảo đi.
            alt_hex, alt_err = None, None
            try:
                alt_hex = _aes256_ecb_encrypt(
                    bytes.fromhex(device["key_ref"]), bytes.fromhex(session["nonce"])
                ).hex()
            except Exception as e:  # noqa: BLE001 - chỉ để chẩn đoán
                alt_err = str(e)
            if alt_hex == cipher_hex:
                print("       >>> KHỚP nếu KHÔNG đảo nhóm byte khóa."
                      " Hãy bỏ phép đảo trong fpga_key_to_aes_key().")
            elif alt_err:
                print(f"       (không thử được phương án thứ tự byte khác: {alt_err})")
    print(f"       => KẾT QUẢ XÁC THỰC: "
          f"{'THÀNH CÔNG (PASSED)' if passed else 'THẤT BẠI (FAILED)'} — {reason}\n")

    return jsonify({"status": new_status, "reason": reason})

@app.route("/api/auth/result/<session_id>", methods=["GET"])
def auth_result(session_id):
    """Web App polling để hiển thị kết quả 'Đạt' hay 'Hỏng' lên giao diện"""
    conn = get_db()
    session = conn.execute("SELECT * FROM auth_sessions WHERE session_id = ?", (session_id,)).fetchone()
    conn.close()
    if not session:
        return jsonify({"error": "Phiên không tồn tại"}), 404
    # Chỉ trả trạng thái. Nonce và cipher là dữ liệu nhạy cảm: lộ ra thì bất kỳ
    # ai cũng thu thập được cặp (nonce, cipher) để phân tích khóa.
    return jsonify({"status": session["status"]})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    # debug=True bật Werkzeug debugger -> cho phép chạy code Python tùy ý qua
    # trình duyệt. Kết hợp host="0.0.0.0" là mở toang ra cả mạng LAN, nên mặc
    # định TẮT; bật lại bằng FLASK_DEBUG=1 khi cần dev một mình.
    debug = os.environ.get("FLASK_DEBUG") == "1"
    print(f"=== BACKEND ĐANG CHẠY TẠI PORT {port} (debug={debug}) ===")
    app.run(host="0.0.0.0", port=port, debug=debug)