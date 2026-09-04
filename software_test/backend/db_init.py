"""
db_init.py tạo database + seed device mẫu "0001".
python db_init.py (xóa devices.db trước nếu muốn reset sạch).
"""

import sqlite3
from mock_board import get_genuine_key_hex

DB_PATH = "devices.db"

SCHEMA = """
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
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(device_id)
);
"""


def main():
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)

    existing = conn.execute("SELECT device_id FROM devices WHERE device_id = ?", ("0001",)).fetchone()
    if existing:
        print("Device 0001 đã tồn tại, bỏ qua seed.")
    else:
        conn.execute(
            "INSERT INTO devices (device_id, helper_data, key_ref) VALUES (?, ?, ?)",
            ("0001", "000000000000000000000000", get_genuine_key_hex()),
        )
        conn.commit()
        print("Đã seed thiết bị mẫu: device_id=0001")

    conn.close()
    print(f"Database sẵn sàng tại: {DB_PATH}")


if __name__ == "__main__":
    main()