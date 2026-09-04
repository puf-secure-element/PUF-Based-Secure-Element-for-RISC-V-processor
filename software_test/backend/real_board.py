import serial

SERIAL_PORT = "COM3"
BAUD_RATE = 115200

STX = 0x02
ETX = 0x03
CMD_AUTH_CHALLENGE = 0x02
CMD_AUTH_RESPONSE = 0x82

_ser = None


def _get_serial():
    global _ser
    if _ser is None or not _ser.is_open:
        _ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=3)
    return _ser


def _build_frame(cmd: int, payload: bytes) -> bytes:
    crc = 0
    for b in payload:
        crc ^= b
    return bytes([STX, cmd, len(payload)]) + payload + bytes([crc, ETX])


def _read_frame(ser, expected_cmd: int, timeout_s: float = 3):
    ser.timeout = timeout_s
    header = ser.read(3)
    if len(header) < 3 or header[0] != STX:
        raise TimeoutError("Không nhận được frame hợp lệ từ FPGA")

    cmd, length = header[1], header[2]
    payload = ser.read(length)
    ser.read(2)  # CRC + ETX

    if cmd != expected_cmd:
        raise ValueError(f"Nhận sai loại frame: mong đợi 0x{expected_cmd:02X}, nhận 0x{cmd:02X}")
    if len(payload) < length:
        raise TimeoutError("Frame bị cắt ngắn")
    return payload


def simulate_board_response(nonce: bytes, genuine: bool = True) -> bytes:
    ser = _get_serial()
    ser.write(_build_frame(CMD_AUTH_CHALLENGE, nonce))
    return _read_frame(ser, expected_cmd=CMD_AUTH_RESPONSE)