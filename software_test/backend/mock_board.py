

from Crypto.Hash import CMAC
from Crypto.Cipher import AES

GENUINE_KEY = bytes.fromhex("000102030405060708090a0b0c0d0e0f")
FAKE_KEY = bytes.fromhex("0f0e0d0c0b0a09080706050403020100")


def simulate_board_response(nonce: bytes, genuine: bool = True) -> bytes:
    key = GENUINE_KEY if genuine else FAKE_KEY
    cobj = CMAC.new(key, ciphermod=AES)
    cobj.update(nonce)
    return cobj.digest()


def get_genuine_key_hex() -> str:
    return GENUINE_KEY.hex()