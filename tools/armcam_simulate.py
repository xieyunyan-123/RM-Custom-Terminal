"""Simulate VT03 UART and player-end forwarding, then drive RM26_Client."""
import argparse
import struct
import subprocess
import threading
import time

import paho.mqtt.client as mqtt

from armcam_adapter import translate


def crc(data, value, polynomial):
    for byte in data:
        value ^= byte
        for _ in range(8):
            value = (value >> 1) ^ (polynomial if value & 1 else 0)
    return value


def uart_frame(fragment, seq, first):
    length = len(fragment)
    flags = int(first) | ((length >> 8) << 1)
    data = bytes((flags, seq, length & 255)) + fragment.ljust(297, b"\0")
    header = struct.pack("<BHB", 0xA5, len(data), seq)
    body = header + bytes([crc(header, 255, 0x8C)]) + b"\x10\x03" + data
    return body + struct.pack("<H", crc(body, 65535, 0x8408))


class PlayerEnd:
    """Receive UART as an arbitrary byte stream and yield validated payloads."""

    def __init__(self):
        self.buffer = bytearray()

    def feed(self, incoming):
        self.buffer.extend(incoming)
        while self.buffer:
            if self.buffer[0] != 0xA5:
                del self.buffer[0]
                continue
            if len(self.buffer) < 5:
                return
            length = int.from_bytes(self.buffer[1:3], "little")
            if length != 300 or crc(self.buffer[:4], 255, 0x8C) != self.buffer[4]:
                del self.buffer[0]
                continue
            if len(self.buffer) < length + 9:
                return
            frame = bytes(self.buffer[:length + 9])
            if crc(frame[:-2], 65535, 0x8408) != int.from_bytes(frame[-2:], "little"):
                del self.buffer[0]
                continue
            del self.buffer[:length + 9]
            if frame[5:7] == b"\x10\x03":
                yield frame[7:-2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--seconds", type=int, default=25)
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error("--seconds must be positive")
    video = subprocess.check_output([
        args.ffmpeg, "-hide_banner", "-loglevel", "error", "-f", "lavfi",
        "-i", "testsrc=size=300x300:rate=15", "-filter_threads", "1",
        "-t", "8", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset",
        "ultrafast", "-tune", "zerolatency", "-g", "15", "-b:v", "76k",
        "-maxrate", "88k", "-bufsize", "45k", "-x264-params", "repeat-headers=1",
        "-f", "h264", "pipe:1",
    ])
    if not video:
        raise RuntimeError("FFmpeg produced no video")

    ready = threading.Event()
    received = 0
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    raw_topic = "armcam/sim/raw"

    def on_connect(conn, _userdata, _flags, reason, _props):
        if not reason.is_failure:
            conn.subscribe(raw_topic, qos=1)

    def on_subscribe(_conn, _userdata, _mid, reasons, _props):
        if all(not reason.is_failure for reason in reasons):
            ready.set()

    def on_message(conn, _userdata, message):
        nonlocal received
        converted = translate(message.payload)
        if converted is not None:
            conn.publish("CustomByteBlock", converted, qos=0)
            received += 1

    client.on_connect = on_connect
    client.on_subscribe = on_subscribe
    client.on_message = on_message
    client.connect("127.0.0.1", 3333)
    client.loop_start()
    try:
        if not ready.wait(5):
            raise RuntimeError("MQTT subscription failed")
        receiver = PlayerEnd()
        sent = 0
        start = time.monotonic()
        offset = 0
        while time.monotonic() - start < args.seconds:
            packet_start = time.monotonic()
            fragment = video[offset:offset + 297]
            frame = uart_frame(fragment, sent % 256, offset == 0)
            # Model partial UART reads. One read need not contain a whole frame.
            for begin in range(0, len(frame), 83):
                for payload in receiver.feed(frame[begin:begin + 83]):
                    pending = client.publish(raw_topic, b"\x0a\xac\x02" + payload, qos=1)
                    pending.wait_for_publish(timeout=2)
                    if not pending.is_published():
                        raise RuntimeError("MQTT publish timed out")
                    sent += 1
            offset = (offset + len(fragment)) % len(video)
            # Preserve the 50 Hz ceiling even if a read or publish stalls.
            time.sleep(max(0.0, 0.020 - (time.monotonic() - packet_start)))
        deadline = time.monotonic() + 2
        while received < sent and time.monotonic() < deadline:
            time.sleep(0.01)
        print(f"UART frames: {sent}; converted MQTT messages: {received}")
        if not sent or sent != received:
            raise RuntimeError("Some simulated frames did not reach the converter")
    finally:
        client.disconnect()
        client.loop_stop()


if __name__ == "__main__":
    main()

