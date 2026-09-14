"""
db_init.py -- tạo database (không seed device mẫu nữa, vì Key thật
lấy qua Enroll). Chạy: python db_init.py
"""

import sqlite3

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

CREATE TABLE IF NOT EXISTS enroll_jobs (
    job_id      TEXT PRIMARY KEY,
    device_id   TEXT NOT NULL,
    status      TEXT DEFAULT 'pending',
    helper_data TEXT,
    key_hex     TEXT,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);
"""


def main():
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SCHEMA)
    conn.close()
    print(f"Database sẵn sàng tại: {DB_PATH}")
    print("Chưa có device nào -- dùng nút Enroll trên Web App để thêm device thật.")


if __name__ == "__main__":
    main()