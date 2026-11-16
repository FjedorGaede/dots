#!/usr/bin/env python3
"""Insta360 Link / Link 2 control for Insta360Service (modules/insta360/README.md).

Standard UVC controls (pan, tilt, zoom, focus, image) go through v4l2-ctl.
The Insta360 features (AI modes, tracking framing, noise cancellation) live in
the camera's vendor extension unit 9 and are reached with UVCIOC_CTRL_QUERY.

Only the selectors in XU_WRITABLE are ever written. Selector 17 would switch
the USB personality (no webcam until replug), 12 holds the serial number.

    link.py status              JSON: device, controls, extension-unit state
    link.py set NAME=VALUE ...  standard controls (v4l2-ctl --set-ctrl)
    link.py mode NAME           normal | track | whiteboard | overhead | deskview
    link.py frame NAME          head | upper | full   (how tightly tracking frames)
    link.py noise on|off        microphone noise cancellation
    link.py gestures off        hand gestures off (on again only by replugging:
                                the firmware clears its gesture bindings)

Exit 2 = no camera connected.
"""
import ctypes
import fcntl
import glob
import json
import os
import re
import subprocess
import sys
import time

VENDOR = "2e1a"
XU_UNIT = 9

UVCIOC_CTRL_QUERY = 0xC0107521   # _IOWR('u', 0x21, struct uvc_xu_control_query)
UVC_SET_CUR = 0x01
UVC_GET_CUR = 0x81
UVC_GET_LEN = 0x85

SEL_MODE = 2          # firmware record; byte 0 = mode, byte 1 = its flag
SEL_GESTURES = 5      # 1 byte, bitmask of enabled gesture groups (0 = off)
SEL_NOISE = 7         # 1 byte
SEL_FRAME = 19        # 1 byte: 1 head, 2 upper body, 3 full body
XU_WRITABLE = {SEL_MODE, SEL_GESTURES, SEL_NOISE, SEL_FRAME}

MODES = {
    "normal": (0x00, 0x00),
    "track": (0x01, 0x00),
    "whiteboard": (0x04, 0x01),
    "overhead": (0x05, 0x03),
    "deskview": (0x06, 0x10),
}
FRAMES = {"head": 1, "upper": 2, "full": 3}

# Standard controls the menu may set (anything else is refused)
CONTROLS = {
    "pan_absolute", "tilt_absolute", "zoom_absolute", "focus_absolute",
    "focus_automatic_continuous", "brightness", "contrast", "saturation",
    "sharpness", "hue", "white_balance_automatic", "white_balance_temperature",
    "power_line_frequency",
}


class Query(ctypes.Structure):
    _fields_ = [("unit", ctypes.c_uint8), ("selector", ctypes.c_uint8),
                ("query", ctypes.c_uint8), ("size", ctypes.c_uint16),
                ("data", ctypes.c_void_p)]


def find_device():
    """Capture node (index 0) of the first Insta360 camera, or None."""
    for node in sorted(glob.glob("/sys/class/video4linux/video*"),
                       key=lambda p: int(re.sub(r"\D", "", p) or 0)):
        try:
            vendor = open(node + "/device/../idVendor").read().strip()
            index = open(node + "/index").read().strip()
            name = open(node + "/name").read().strip()
        except OSError:
            continue
        if vendor == VENDOR and index == "0":
            return "/dev/" + os.path.basename(node), name.split(":")[0]
    return None


def xu(fd, selector, query, size, payload=b""):
    buf = ctypes.create_string_buffer(payload, size) if payload else ctypes.create_string_buffer(size)
    fcntl.ioctl(fd, UVCIOC_CTRL_QUERY, Query(XU_UNIT, selector, query, size, ctypes.addressof(buf)))
    return buf.raw


def xu_len(fd, selector):
    return int.from_bytes(xu(fd, selector, UVC_GET_LEN, 2), "little")


def xu_read(fd, selector):
    return xu(fd, selector, UVC_GET_CUR, xu_len(fd, selector))


def xu_patch(fd, selector, changes):
    """Read-modify-write: change single bytes, keep the rest of the record."""
    if selector not in XU_WRITABLE:
        raise SystemExit(f"error: selector {selector} is not writable")
    data = bytearray(xu_read(fd, selector))
    for offset, value in changes.items():
        data[offset] = value & 0xFF
    xu(fd, selector, UVC_SET_CUR, len(data), bytes(data))


def write_mode(fd, mode, flag):
    """Mode record: zeroed, only bytes 52+ (firmware-owned) kept."""
    length = xu_len(fd, SEL_MODE)
    data = bytearray(length)
    if length > 52:
        data[52:] = xu_read(fd, SEL_MODE)[52:]
    data[0], data[1] = mode, flag
    xu(fd, SEL_MODE, UVC_SET_CUR, length, bytes(data))


def set_mode(fd, name):
    """The firmware only takes a mode while streaming, and not on the first
    write: reset to normal, wait, write, then re-assert until it reads back
    (handshake as in github.com/jweaver60/link-studio)."""
    mode, flag = MODES[name]
    if name == "normal":
        write_mode(fd, mode, flag)
        return
    write_mode(fd, 0, 0)
    time.sleep(0.6)
    write_mode(fd, mode, flag)
    stable, deadline, reassert = 0, time.monotonic() + 9, time.monotonic() + 2.5
    while time.monotonic() < deadline:
        time.sleep(0.4)
        stable = stable + 1 if xu_read(fd, SEL_MODE)[0] == mode else 0
        if stable >= 3:
            return
        if time.monotonic() >= reassert:
            write_mode(fd, mode, flag)
            reassert = time.monotonic() + 2.5
    raise SystemExit(f"error: camera did not switch to {name} (is it streaming?)")


def list_controls(dev):
    """v4l2-ctl --list-ctrls → {name: {value, min, max, step, default, inactive}}."""
    out = subprocess.run(["v4l2-ctl", "-d", dev, "--list-ctrls"],
                         capture_output=True, text=True, check=True).stdout
    controls = {}
    for line in out.splitlines():
        m = re.match(r"\s*(\w+) 0x[0-9a-f]+ \((\w+)\)\s*:(.*)", line)
        if not m:
            continue
        name, kind, rest = m.groups()
        fields = dict(re.findall(r"(\w+)=(-?\d+)", rest))
        controls[name] = {
            "type": kind,
            "value": int(fields.get("value", 0)),
            "min": int(fields.get("min", 0 if kind == "bool" else 0)),
            "max": int(fields.get("max", 1 if kind == "bool" else 0)),
            "step": int(fields.get("step", 1)),
            "default": int(fields.get("default", 0)),
            "inactive": "inactive" in rest,
        }
    return controls


def streaming(dev):
    """Another process has the camera open. The gimbal only moves then."""
    me = str(os.getpid())
    for fd in glob.glob("/proc/[0-9]*/fd/*"):
        if fd.split("/")[2] == me:
            continue
        try:
            if os.readlink(fd) == dev:
                return True
        except OSError:
            pass
    return False


def main(argv):
    found = find_device()
    if not found:
        print(json.dumps({"present": False}) if argv[:1] == ["status"] else "error: no Insta360 camera")
        return 2
    dev, name = found
    cmd, args = (argv[0], argv[1:]) if argv else ("status", [])

    if cmd == "set":
        pairs = []
        for arg in args:
            key, _, value = arg.partition("=")
            if key not in CONTROLS or not re.fullmatch(r"-?\d+", value):
                print(f"error: bad control {arg!r}", file=sys.stderr)
                return 1
            pairs.append(f"{key}={value}")
        if pairs:
            subprocess.run(["v4l2-ctl", "-d", dev, "--set-ctrl=" + ",".join(pairs)], check=True)
        return 0

    fd = os.open(dev, os.O_RDWR)
    try:
        if cmd == "status":
            print(json.dumps({
                "present": True,
                "device": dev,
                "name": name,
                "streaming": streaming(dev),
                "controls": list_controls(dev),
                "frame": next((k for k, v in FRAMES.items() if v == xu_read(fd, SEL_FRAME)[0]), ""),
                "noise": bool(xu_read(fd, SEL_NOISE)[0]),
                "gestures": bool(xu_read(fd, SEL_GESTURES)[0]),
                # 0xFF = "some mode, switching" → "" (keep the remembered one)
                "mode": next((k for k, v in MODES.items() if v[0] == xu_read(fd, SEL_MODE)[0]), ""),
            }))
        elif cmd == "mode" and args and args[0] in MODES:
            set_mode(fd, args[0])
        elif cmd == "frame" and args and args[0] in FRAMES:
            xu_patch(fd, SEL_FRAME, {0: FRAMES[args[0]]})
        elif cmd == "gestures" and args == ["off"]:
            xu_patch(fd, SEL_GESTURES, {0: 0})
        elif cmd == "noise" and args and args[0] in ("on", "off"):
            xu_patch(fd, SEL_NOISE, {0: 1 if args[0] == "on" else 0})
        else:
            print(__doc__.split("\n\n")[2], file=sys.stderr)
            return 1
    finally:
        os.close(fd)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
