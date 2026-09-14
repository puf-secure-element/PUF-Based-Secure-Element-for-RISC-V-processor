"""
simple_uart_listener.py -- Test UART thô, KHÔNG giả định frame/protocol gì cả.

Chỉ làm 2 việc:
  1. Mở cổng COM, LẮNG NGHE liên tục -- in ra MỌI byte nhận được
     (dạng hex + ký tự ASCII nếu đọc được), kèm thời điểm nhận.
  2. (Tùy chọn) gõ chữ trong terminal rồi Enter -- gửi thẳng chuỗi đó
     qua UART cho FPGA, để test cả chiều gửi.

Dùng để xác nhận: dây nối đúng chưa, baud rate đúng chưa, FPGA có tự
gửi được gì ra UART không -- TRƯỚC KHI quan tâm tới bất kỳ giao thức
STX/CMD/LEN hay Enroll/Auth nào.

Cách chạy:
    python simple_uart_listener.py
"""

import sys
import time
import threading
import serial

SERIAL_PORT = "COM9"   # sửa đúng cổng COM của YP-05
BAUD_RATE = 9600    # thử 115200 trước, nếu không thấy gì thử 9600


def to_printable(data: bytes) -> str:
    """Hiện ký tự đọc được, thay byte không in được bằng dấu chấm."""
    return "".join(chr(b) if 32 <= b < 127 else "." for b in data)


def listen_loop(ser: serial.Serial):
    print("Đang lắng nghe... (Ctrl+C để dừng)")
    print("-" * 60)
    while True:
        n = ser.in_waiting
        if n > 0:
            data = ser.read(n)
            ts = time.strftime("%H:%M:%S")
            hex_str = data.hex(" ")
            ascii_str = to_printable(data)
            print(f"[{ts}] ({len(data)} byte)")
            print(f"  HEX  : {hex_str}")
            print(f"  ASCII: {ascii_str}")
            print("-" * 60)
        else:
            time.sleep(0.05)


def send_loop(ser: serial.Serial):
    """Chạy trên thread riêng -- gõ chữ + Enter để gửi qua UART."""
    while True:
        try:
            text = input()
        except EOFError:
            break
        if text:
            ser.write(text.encode("utf-8"))
            print(f">>> Đã gửi: {text!r}")


def main():
    print(f"Đang mở cổng: {SERIAL_PORT} @ {BAUD_RATE} baud")
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0)
    except serial.SerialException as e:
        print(f"LỖI: không mở được cổng {SERIAL_PORT}: {e}")
        print("Kiểm tra: đúng tên cổng chưa? YP-05 đã cắm chưa? Có chương trình khác đang chiếm cổng không?")
        sys.exit(1)

    print("Gõ chữ + Enter bất kỳ lúc nào để gửi qua UART cho FPGA (tùy chọn).")

    sender = threading.Thread(target=send_loop, args=(ser,), daemon=True)
    sender.start()

    try:
        listen_loop(ser)
    except KeyboardInterrupt:
        print("\nDừng chương trình.")
    finally:
        ser.close()


if __name__ == "__main__":
    main()