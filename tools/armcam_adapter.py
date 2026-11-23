"""Translate Hik bridge lab MQTT messages for the RM26_Client industrial view."""
import argparse
import logging


def read_varint(data, offset):
    value = 0
    for shift in range(0, 35, 7):
        if offset >= len(data):
            break
        byte = data[offset]
        offset += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, offset
    raise ValueError("invalid protobuf length")


def translate(message):
    # The lab emulator serializes a single protobuf bytes field, field 1.
    if message[:1] != b"\x0a":
        raise ValueError("expected CustomByteBlock.data")
    size, start = read_varint(message, 1)
    if size != 300 or len(message) != start + size:
        raise ValueError("expected one 300-byte Hik chunk")
    flags, seq, low = message[start:start + 3]
    length = low | ((flags & 2) << 7)
    if flags & 0xfc or length > 297:
        raise ValueError("invalid Hik fragment header")
    if length == 0:
        return None
    output = message[start + 3:start + 3 + length] + bytes([seq])
    n = len(output)
    encoded_length = bytes([n]) if n < 128 else bytes([(n & 127) | 128, n >> 7])
    return b"\x0a" + encoded_length + output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=3333)
    parser.add_argument("--input-topic", default="armcam/raw")
    parser.add_argument("--output-topic", default="CustomByteBlock")
    args = parser.parse_args()
    topics = (args.input_topic, args.output_topic)
    if topics[0] == topics[1] or any(not t or "+" in t or "#" in t for t in topics):
        parser.error("use two distinct, concrete MQTT topics")

    import paho.mqtt.client as mqtt

    logging.basicConfig(level=logging.INFO)
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)

    def on_connect(conn, _userdata, _flags, reason, _properties):
        if reason.is_failure:
            logging.error("MQTT connection rejected: %s", reason)
            return
        conn.subscribe(args.input_topic)
        logging.info("Forwarding %s to %s", *topics)

    dropped = 0

    def on_message(conn, _userdata, msg):
        nonlocal dropped
        if msg.retain:
            return
        try:
            payload = translate(msg.payload)
        except ValueError as exc:
            dropped += 1
            if dropped == 1 or dropped % 100 == 0:
                logging.warning("Invalid packets dropped: %d (%s)", dropped, exc)
            return
        if payload is not None:
            conn.publish(args.output_topic, payload, qos=0, retain=False)

    client.on_connect = on_connect
    client.on_message = on_message
    try:
        client.connect(args.host, args.port)
        client.loop_forever()
    except KeyboardInterrupt:
        pass
    finally:
        client.disconnect()


if __name__ == "__main__":
    main()

