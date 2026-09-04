"""
Frame: [STX=0x02][CMD][LEN][PAYLOAD][CRC][ETX=0x03]
  CMD 0x02 = Auth Challenge (nhận), CMD 0x82 = Auth Response (gửi)
"""

import sys
import serial
from mock_board import GENUINE_KEY
from Crypto.Hash import CMAC
from Crypto.Cipher import AES

SERIAL_PORT = "COM9"
BAUD_RATE = 9600  # 9600 cho ESP8266 (SoftwareSerial), 115200 cho ESP32/UART thật

STX = 0x02
ETX = 0x03
CMD_AUTH_CHALLENGE = 0x02
CMD_AUTH_RESPONSE = 0x82


def compute_cipher(nonce: bytes) -> bytes:
    cobj = CMAC.new(GENUINE_KEY, ciphermod=AES)
    cobj.update(nonce)
    return cobj.digest()


def read_frame(ser):
    stx = ser.read(1)
    if len(stx) == 0:
        return None
    if stx[0] != STX:
        print(f"Byte lạ (bỏ qua): 0x{stx[0]:02X}")
        return None

    header = ser.read(2)
    if len(header) < 2:
        return None
    cmd, length = header[0], header[1]
    payload = ser.read(length)
    ser.read(2)  # CRC + ETX

    if cmd != CMD_AUTH_CHALLENGE:
        print(f"CMD không mong đợi: 0x{cmd:02X}")
        return None
    if len(payload) < length:
        print("Frame bị cắt ngắn")
        return None
    return payload


def send_response_frame(ser, cipher: bytes):
    crc = 0
    for b in cipher:
        crc ^= b
    ser.write(bytes([STX, CMD_AUTH_RESPONSE, len(cipher)]) + cipher + bytes([crc, ETX]))


def main():
    print(f"Đang mở cổng: {SERIAL_PORT} @ {BAUD_RATE} baud")
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=5)
    except serial.SerialException as e:
        print(f"LỖI: không mở được cổng {SERIAL_PORT}: {e}")
        sys.exit(1)

    print("Sẵn sàng, đang chờ Nonce... (Ctrl+C để dừng)")
    try:
        while True:
            nonce = read_frame(ser)
            if nonce is None:
                continue
            print(f"Nhận Nonce : {nonce.hex()}")
            cipher = compute_cipher(nonce)
            print(f"Trả Cipher : {cipher.hex()}")
            send_response_frame(ser, cipher)
    except KeyboardInterrupt:
        print("\nDừng fake_fpga.py")
    finally:
        ser.close()


if __name__ == "__main__":
    main()