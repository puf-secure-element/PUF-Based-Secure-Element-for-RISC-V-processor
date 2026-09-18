import os, sys, tempfile
os.chdir(tempfile.mkdtemp())
sys.path.insert(0, "/home/user/PUF-Based-Secure-Element-for-RISC-V-processor/software_test/backend/venv")
import app as A
A.app.config["TESTING"] = True
c = A.app.test_client()
H = {"X-Device-Secret": A.ESP32_SECRET}
DEV, HELPER = "0001", "4CECF1C5DAA972A849C184D6"

print("--- chua Enroll bao gio -> 204 ---")
r = c.get(f"/api/helper?device_id={DEV}", headers=H)
assert r.status_code == 204, r.status_code
print("  204  [OK]")

job = c.post("/api/enroll/start", json={"device_id": DEV}).get_json()["job_id"]
c.get(f"/api/enroll/pending?device_id={DEV}", headers=H)
c.post("/api/enroll/board_response", headers=H,
       json={"job_id": job, "helper_data": HELPER, "key": "11"*32})

print("\n--- sau khi Enroll -> tra dung helper ---")
d = c.get(f"/api/helper?device_id={DEV}", headers=H).get_json()
assert d["helper_data"] == HELPER, d
assert len(d["helper_data"]) == 24, len(d["helper_data"])
print(f"  {d['helper_data']}  (12 byte)  [OK]")

print("\n--- thieu / sai secret -> 401 ---")
assert c.get(f"/api/helper?device_id={DEV}").status_code == 401
assert c.get(f"/api/helper?device_id={DEV}", headers={"X-Device-Secret": "sai"}).status_code == 401
print("  401  [OK]")

print("\n--- thieu device_id -> 400 ---")
assert c.get("/api/helper", headers=H).status_code == 400
print("  400  [OK]")

print("\n--- thiet bi khac -> 204 ---")
assert c.get("/api/helper?device_id=9999", headers=H).status_code == 204
print("  204  [OK]")
print("\nTAT CA PASS")
