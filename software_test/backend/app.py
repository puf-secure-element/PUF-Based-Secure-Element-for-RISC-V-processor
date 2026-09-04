"""
python app.py -> http://localhost:5000
"""

import os
import secrets
import sqlite3

from flask import Flask, jsonify, request
from Crypto.Hash import CMAC
from Crypto.Cipher import AES

DB_PATH = "devices.db"
ESP32_SECRET = os.environ.get("ESP32_SECRET", "demo-secret-change-me")

app = Flask(__name__, static_folder="static", static_url_path="")

if not os.path.exists(DB_PATH):
    import db_init
    db_init.main()


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def compute_cmac(key: bytes, nonce: bytes) -> bytes:
    cobj = CMAC.new(key, ciphermod=AES)
    cobj.update(nonce)
    return cobj.digest()


@app.route("/")
def index():
    return app.send_static_file("index.html")


@app.route("/api/devices", methods=["GET"])
def list_devices():
    conn = get_db()
    rows = conn.execute("SELECT device_id, created_at FROM devices").fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


# MOCK: test không cần phần cứng 
@app.route("/api/auth/start_mock", methods=["POST"])
def auth_start_mock():
    from mock_board import simulate_board_response

    data = request.get_json(force=True)
    device_id = data.get("device_id")
    genuine = data.get("genuine", True)

    conn = get_db()
    device = conn.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,)).fetchone()
    if not device:
        conn.close()
        return jsonify({"error": f"device_id {device_id} chưa được enroll"}), 404

    nonce = secrets.token_bytes(16)
    cipher = simulate_board_response(nonce, genuine=genuine)
    key = bytes.fromhex(device["key_ref"])
    expected_cipher = compute_cmac(key, nonce)
    passed = cipher == expected_cipher
    conn.close()

    return jsonify({
        "status": "PASS" if passed else "FAIL",
        "nonce": nonce.hex(),
        "cipher_from_board": cipher.hex(),
        "cipher_expected_by_server": expected_cipher.hex(),
    })


#FPGA -- UART -- PC
@app.route("/api/auth/start_real", methods=["POST"])
def auth_start_real():
    from real_board import simulate_board_response

    data = request.get_json(force=True)
    device_id = data.get("device_id")
    if not device_id:
        return jsonify({"error": "thiếu device_id"}), 400

    conn = get_db()
    device = conn.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,)).fetchone()
    if not device:
        conn.close()
        return jsonify({"error": f"device_id {device_id} chưa được enroll"}), 404

    nonce = secrets.token_bytes(16)
    try:
        cipher = simulate_board_response(nonce)
    except (TimeoutError, ValueError) as e:
        conn.close()
        return jsonify({"error": f"Lỗi giao tiếp UART với FPGA: {e}"}), 504

    key = bytes.fromhex(device["key_ref"])
    expected_cipher = compute_cmac(key, nonce)
    passed = cipher == expected_cipher
    conn.close()

    return jsonify({
        "status": "PASS" if passed else "FAIL",
        "nonce": nonce.hex(),
        "cipher_from_board": cipher.hex(),
        "cipher_expected_by_server": expected_cipher.hex(),
    })


# FPGA -- UART -- ESP -- WiFi
@app.route("/api/auth/start", methods=["POST"])
def auth_start():
    data = request.get_json(force=True)
    device_id = data.get("device_id")
    if not device_id:
        return jsonify({"error": "thiếu device_id"}), 400

    conn = get_db()
    device = conn.execute("SELECT * FROM devices WHERE device_id = ?", (device_id,)).fetchone()
    if not device:
        conn.close()
        return jsonify({"error": f"device_id {device_id} chưa được enroll"}), 404

    nonce = secrets.token_bytes(16)
    session_id = secrets.token_hex(8)
    conn.execute(
        "INSERT INTO auth_sessions (session_id, device_id, nonce, status) VALUES (?, ?, ?, 'pending')",
        (session_id, device_id, nonce.hex()),
    )
    conn.commit()
    conn.close()

    return jsonify({"session_id": session_id, "status": "pending"})


@app.route("/api/auth/pending", methods=["GET"])
def auth_pending():
    """ESP poll endpoint này mỗi 1-2s để lấy Nonce cần gửi FPGA."""
    device_id = request.args.get("device_id")
    if not device_id:
        return jsonify({"error": "thiếu device_id"}), 400

    conn = get_db()
    row = conn.execute(
        "SELECT session_id, nonce FROM auth_sessions "
        "WHERE device_id = ? AND status = 'pending' ORDER BY created_at ASC LIMIT 1",
        (device_id,),
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
    """ESP gọi sau khi FPGA trả Cipher. Header X-Device-Secret bắt buộc."""
    if request.headers.get("X-Device-Secret") != ESP32_SECRET:
        return jsonify({"error": "unauthorized"}), 401

    data = request.get_json(force=True)
    session_id = data.get("session_id")
    cipher_hex = data.get("cipher")

    conn = get_db()
    session = conn.execute("SELECT * FROM auth_sessions WHERE session_id = ?", (session_id,)).fetchone()
    if not session:
        conn.close()
        return jsonify({"error": "session không tồn tại"}), 404

    device = conn.execute("SELECT * FROM devices WHERE device_id = ?", (session["device_id"],)).fetchone()
    key = bytes.fromhex(device["key_ref"])
    nonce = bytes.fromhex(session["nonce"])
    expected_cipher = compute_cmac(key, nonce)
    passed = bytes.fromhex(cipher_hex) == expected_cipher

    conn.execute("UPDATE auth_sessions SET status = ? WHERE session_id = ?",
                 ("passed" if passed else "failed", session_id))
    conn.commit()
    conn.close()
    return jsonify({"status": "passed" if passed else "failed"})


@app.route("/api/auth/result/<session_id>", methods=["GET"])
def auth_result(session_id):
    """Web App poll endpoint này mỗi 1s để lấy kết quả cuối."""
    conn = get_db()
    session = conn.execute("SELECT * FROM auth_sessions WHERE session_id = ?", (session_id,)).fetchone()
    conn.close()
    if not session:
        return jsonify({"error": "session không tồn tại"}), 404
    return jsonify({"status": session["status"], "nonce": session["nonce"]})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port, debug=False)