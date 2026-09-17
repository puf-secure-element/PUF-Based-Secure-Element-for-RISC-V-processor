"""Tinh san cipher ma board PHAI tra ve, de doi chieu tay khi thu Auth.

Dung chung dung ham compute_expected_cipher() cua app.py, nen neu ket qua
lech thi loi nam o phan cung hoac o khoa da luu, khong phai o cach tinh.

Cach chay:
    python expected_cipher.py <key_hex>                  # bang cac nonce mau
    python expected_cipher.py <key_hex> <nonce_hex>      # mot nonce cu the

<key_hex> lay tu dong "Key (32B)" trong log ESP luc board phat khung Enroll.
Cho phep viet co cach, dau : hoac - cho de dan.
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# app.py mo/tao devices.db theo thu muc lam viec; chay o thu muc tam de lan
# chay nay khong dung toi database that.
os.chdir(tempfile.mkdtemp())

from app import compute_expected_cipher  # noqa: E402

MAU = [
    ("000102030405060708090a0b0c0d0e0f", "nonce mau"),
    ("000102030405060708090a0b0c0d0e0e", "chi khac 1 ky tu hex cuoi"),
    ("00000000000000000000000000000000", "toan 0"),
    ("ffffffffffffffffffffffffffffffff", "toan f"),
]


def clean(s: str) -> str:
    return s.replace(" ", "").replace(":", "").replace("-", "")


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    key = clean(sys.argv[1])
    if len(key) != 64:
        print(f"LOI: key phai la 64 ky tu hex (32 byte), nhan duoc {len(key)}")
        sys.exit(1)

    nonces = [(clean(sys.argv[2]), "")] if len(sys.argv) > 2 else MAU

    print(f"key: {key}\n")
    for nonce, ghichu in nonces:
        cipher, err = compute_expected_cipher(key, nonce)
        if err:
            print(f"  {nonce}  ->  LOI: {err}")
        else:
            print(f"  {nonce}  ->  {cipher}" + (f"   ({ghichu})" if ghichu else ""))


if __name__ == "__main__":
    main()
