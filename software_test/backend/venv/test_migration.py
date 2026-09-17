"""Kiem tra: database tao theo schema CU van chay duoc sau khi them cot."""
import os, sqlite3, sys, tempfile
d = tempfile.mkdtemp(); os.chdir(d)

# 1. Dung lai database theo schema CU (khong co cot nonce_source)
conn = sqlite3.connect("devices.db")
conn.executescript("""
CREATE TABLE devices (device_id TEXT PRIMARY KEY, helper_data TEXT NOT NULL,
                      key_ref TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE auth_sessions (session_id TEXT PRIMARY KEY, device_id TEXT NOT NULL,
                            nonce TEXT NOT NULL, status TEXT DEFAULT 'pending',
                            cipher TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE enroll_jobs (job_id TEXT PRIMARY KEY, device_id TEXT NOT NULL,
                          status TEXT DEFAULT 'pending', helper_data TEXT,
                          key_hex TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
""")
conn.execute("INSERT INTO devices VALUES ('0001','AABB','CCDD',CURRENT_TIMESTAMP)")
# mot phien cu, khong co nonce_source
conn.execute("INSERT INTO auth_sessions (session_id,device_id,nonce,status) "
             "VALUES ('cu001','0001','00112233445566778899aabbccddeeff','pending')")
conn.commit(); conn.close()
print("[1] Da dung database theo schema CU, co 1 phien cu")

# 2. Nap app -> chay init_db_if_not_exists() -> phai them cot em tham
sys.path.insert(0, "/home/user/PUF-Based-Secure-Element-for-RISC-V-processor/software_test/backend/venv")
import app as A
cols = [r[1] for r in sqlite3.connect("devices.db").execute("PRAGMA table_info(auth_sessions)")]
assert "nonce_source" in cols, cols
print(f"[2] Sau khi nap app, cot da co: {cols}")

# 3. Du lieu cu con nguyen
row = A.get_db().execute("SELECT * FROM auth_sessions WHERE session_id='cu001'").fetchone()
assert row["nonce"] == "00112233445566778899aabbccddeeff"
assert row["nonce_source"] is None, row["nonce_source"]
print("[3] Phien cu con nguyen, nonce_source = NULL (dung)")

# 4. Nap lai lan nua -> khong duoc no
A.init_db_if_not_exists(); A.init_db_if_not_exists()
print("[4] Goi init lai nhieu lan: khong loi")

# 5. Phien cu van xu ly duoc (khong vo vi thieu nonce_source)
A.app.config["TESTING"] = True
c = A.app.test_client(); H = {"X-Device-Secret": A.ESP32_SECRET}
r = c.post("/api/auth/board_response", headers=H,
           json={"session_id": "cu001", "cipher": "00"*16})
assert r.status_code == 200, (r.status_code, r.get_data(as_text=True))
print(f"[5] Xu ly phien CU: HTTP {r.status_code} -> {r.get_json()['status']}")

print("\nDI CHUYEN DATABASE AN TOAN")
