"""
simple_uart_listener.py -- Nghe UART thô tu FPGA.

Lam 3 viec:
  1. Mo cong serial, gom cac byte nhan duoc thanh tung "cum" (burst) --
     ranh giới cum la khoang lang > BURST_GAP giay -- roi in hex dump.
  2. Tu dong giai ma khung Enroll (STX 0x02 / CMD 0x81 / LEN 44) neu thay,
     in ra helper data, key, va TU KIEM TRA CRC.
  3. (Tuy chon) go chu + Enter de gui nguoc qua UART cho FPGA.

Cach chay:
    python simple_uart_listener.py                        # /dev/ttyUSB0 @ 115200
    python simple_uart_listener.py /dev/ttyUSB1
    python simple_uart_listener.py COM9 115200

LUU Y BAUD: FPGA phat 115200 (Instruction_memory.v ghi DLL=0x1B ->
50 MHz / (16 x 27) = 115740, lech 0.47% so voi 115200 -- trong nguong cho
phep). Nghe o baud khac se chi ra byte rac.
"""

import sys
import time
import threading

import serial

DEFAULT_PORT = "/dev/ttyUSB0"
DEFAULT_BAUD = 115200
BURST_GAP = 0.05          # giay im lang de coi la ket thuc mot cum

STX, ETX, CMD_ENROLL = 0x02, 0x03, 0x81
PAYLOAD_LEN = 44          # 12 byte helper + 32 byte key
FRAME_LEN = 52            # STX + CMD + LEN + reserved + 44 + CRC + ETX


def to_printable(data: bytes) -> str:
    return "".join(chr(b) if 32 <= b < 127 else "." for b in data)


def hex_dump(data: bytes) -> str:
    rows = []
    for off in range(0, len(data), 16):
        chunk = data[off:off + 16]
        rows.append(f"  {off:04x}  {chunk.hex(' '):<47}  {to_printable(chunk)}")
    return "\n".join(rows)


def try_decode_enroll(buf: bytes) -> None:
    """Tim va giai ma khung Enroll trong cum byte vua nhan."""
    for i in range(len(buf) - 3):
        if buf[i] == STX and buf[i + 1] == CMD_ENROLL and buf[i + 2] == PAYLOAD_LEN:
            break
    else:
        return

    frame = buf[i:i + FRAME_LEN]
    print(f"\n  >>> THAY KHUNG ENROLL tai offset {i} <<<")
    if len(frame) < FRAME_LEN:
        print(f"      NHUNG CHI CO {len(frame)}/{FRAME_LEN} byte -- khung bi cat cut.")
        return

    payload = frame[4:4 + PAYLOAD_LEN]
    crc_rx, etx = frame[4 + PAYLOAD_LEN], frame[5 + PAYLOAD_LEN]
    crc_calc = 0
    for b in payload:
        crc_calc ^= b

    print(f"      STX = 0x{frame[0]:02x}   CMD = 0x{frame[1]:02x}   LEN = {frame[2]}")
    print(f"      helper data (12 byte) : {payload[:12].hex()}")
    print(f"      key         (32 byte) : {payload[12:].hex()}")
    print(f"      CRC nhan = 0x{crc_rx:02x}   CRC tinh lai = 0x{crc_calc:02x}   "
          f"{'KHOP' if crc_rx == crc_calc else '!!! LECH !!!'}")
    print(f"      ETX = 0x{etx:02x}  {'OK' if etx == ETX else '!!! SAI, phai la 0x03 !!!'}")

    if crc_rx == crc_calc and etx == ETX:
        print("      => KHUNG HOP LE. Bo phan tich cua esp_new4.ino se chap nhan.")
        if not any(payload[:12]):
            print("      CANH BAO: helper data toan 0. Tren phan cung that no phai")
            print("      khac 0 -- dap ung PUF la mot phep do vat ly. Toan 0 nghia la")
            print("      ECC/PUF chua tao ra gi, xem lai khoi ro_puf_core/ecc_top.")
    else:
        print("      => KHUNG HONG.")


def listen_loop(ser: serial.Serial) -> None:
    print("Dang lang nghe... (Ctrl+C de dung)")
    print("-" * 70)
    buf = bytearray()
    last_rx = None
    while True:
        n = ser.in_waiting
        if n:
            buf += ser.read(n)
            last_rx = time.monotonic()
        elif buf and last_rx and (time.monotonic() - last_rx) > BURST_GAP:
            ts = time.strftime("%H:%M:%S")
            print(f"[{ts}]  cum {len(buf)} byte")
            print(hex_dump(bytes(buf)))
            try_decode_enroll(bytes(buf))
            print("-" * 70)
            buf.clear()
        else:
            time.sleep(0.005)


def send_loop(ser: serial.Serial) -> None:
    while True:
        try:
            text = input()
        except EOFError:
            break
        if text:
            ser.write(text.encode("utf-8"))
            print(f">>> Da gui: {text!r}")


def main() -> None:
    port = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PORT
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_BAUD

    print(f"Dang mo cong: {port} @ {baud} baud")
    if baud != 115200:
        print("CANH BAO: FPGA phat o 115200. Baud khac se chi ra byte rac.")
    try:
        ser = serial.Serial(port, baud, timeout=0)
    except serial.SerialException as e:
        print(f"LOI: khong mo duoc cong {port}: {e}")
        print("Kiem tra: dung ten cong chua? YP-05 da cam chua? "
              "Co chuong trinh khac dang chiem cong khong (Arduino IDE Serial Monitor)?")
        sys.exit(1)

    print("Go chu + Enter bat ky luc nao de gui qua UART cho FPGA (tuy chon).")
    threading.Thread(target=send_loop, args=(ser,), daemon=True).start()

    try:
        listen_loop(ser)
    except KeyboardInterrupt:
        print("\nDung chuong trinh.")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
