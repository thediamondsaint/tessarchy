#!/usr/bin/env python3
"""Guest-only virtual multitouch touchscreen for driving Tessa in a VM.

Creates a uinput device with INPUT_PROP_DIRECT and MT slots, so Hyprland and
apps receive real touch events rather than the QEMU tablet's absolute pointer.
It is not a hardware touchscreen test. W and H are the output's pixel size.

Usage (inside the guest): sudo ./scripts/guest-touch.py W H < commands
Commands, one per line: "tap X Y", "swipe X1 Y1 X2 Y2 MS [HOLD_MS]" (HOLD_MS
keeps the finger still at the end before lifting), "sleep SECONDS".
"""
import fcntl, os, struct, subprocess, sys, time

if len(sys.argv) != 3 or not all(a.isdigit() and 0 < int(a) <= 16384 for a in sys.argv[1:]):
    sys.exit("Usage: guest-touch.py WIDTH HEIGHT < commands")
virt = subprocess.run(["systemd-detect-virt", "--vm"], capture_output=True, text=True)
if virt.returncode != 0:
    sys.exit("Refusing to create an input device outside a virtual machine")

UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT, UI_SET_PROPBIT = 0x40045564, 0x40045565, 0x40045567, 0x4004556e
UI_DEV_CREATE, UI_DEV_SETUP, UI_ABS_SETUP = 0x5501, 0x405c5503, 0x401c5504
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
BTN_TOUCH = 0x14a
ABS_X, ABS_Y, ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0, 1, 0x2f, 0x35, 0x36, 0x39
INPUT_PROP_DIRECT = 1
W, H = int(sys.argv[1]), int(sys.argv[2])
fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
for ev in (EV_SYN, EV_KEY, EV_ABS):
    fcntl.ioctl(fd, UI_SET_EVBIT, ev)
fcntl.ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH)
fcntl.ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT)
for code, hi in ((ABS_X, W - 1), (ABS_Y, H - 1), (ABS_MT_SLOT, 4), (ABS_MT_POSITION_X, W - 1),
                 (ABS_MT_POSITION_Y, H - 1), (ABS_MT_TRACKING_ID, 65535)):
    fcntl.ioctl(fd, UI_SET_ABSBIT, code)
    # struct uinput_abs_setup { u16 code; input_absinfo {s32 value,min,max,fuzz,flat,resolution} }
    fcntl.ioctl(fd, UI_ABS_SETUP, struct.pack("HxxiiiiII", code, 0, 0, hi, 0, 0, 8))
fcntl.ioctl(fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 3, 0x1234, 0x5678, 1, b"tessarchy-test-touch", 0))
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(1)
tid = 0

def emit(t, c, v):
    s = time.time()
    os.write(fd, struct.pack("qqHHi", int(s), int((s % 1) * 1e6), t, c, v))

def syn():
    emit(EV_SYN, 0, 0)

def down(x, y):
    global tid
    tid += 1
    emit(EV_ABS, ABS_MT_SLOT, 0); emit(EV_ABS, ABS_MT_TRACKING_ID, tid)
    move(x, y, key=True)

def move(x, y, key=False):
    emit(EV_ABS, ABS_MT_POSITION_X, x); emit(EV_ABS, ABS_MT_POSITION_Y, y)
    if key:
        emit(EV_KEY, BTN_TOUCH, 1)
    emit(EV_ABS, ABS_X, x); emit(EV_ABS, ABS_Y, y); syn()

def up():
    emit(EV_ABS, ABS_MT_SLOT, 0); emit(EV_ABS, ABS_MT_TRACKING_ID, -1)
    emit(EV_KEY, BTN_TOUCH, 0); syn()

print("ready", flush=True)
for line in sys.stdin:
    p = line.split()
    if not p:
        continue
    if p[0] == "tap":
        down(int(p[1]), int(p[2])); time.sleep(0.06); up(); time.sleep(0.15)
    elif p[0] == "swipe":
        x1, y1, x2, y2, ms = map(int, p[1:6]); n = max(2, ms // 16)
        hold = int(p[6]) if len(p) > 6 else 0
        down(x1, y1)
        for i in range(1, n + 1):
            time.sleep(ms / n / 1000); move(x1 + (x2 - x1) * i // n, y1 + (y2 - y1) * i // n)
        time.sleep(hold / 1000); up(); time.sleep(0.15)
    elif p[0] == "sleep":
        time.sleep(float(p[1]))
    else:
        sys.exit(f"Unknown command: {line.strip()}")
    print("ok", line.strip(), flush=True)
