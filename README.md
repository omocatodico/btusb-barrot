# btusb-barrot

DKMS workaround that makes **Bluetooth LE** work on USB dongles with a
**Barrot** chip, such as the **UGREEN Bluetooth 5.4 adapter** (USB ID
`33fa:0010`). With it, LE devices like the **Xbox Wireless Controller** can
be paired and used on Linux.

It installs a patched copy of the kernel's `btusb` driver and rebuilds it
automatically on every kernel update.

## The problem

With the stock kernel (tested on 7.2.11), the dongle is detected and classic
Bluetooth works, but anything LE fails:

1. **Starting a scan crashes the dongle in a loop.** The chip claims to support
   LE extended scanning but stops answering when it is used; btusb resets it,
   it re-enumerates, and the same happens again every few seconds:

   ```
   Bluetooth: hci0: Opcode 0x2041 failed: -110
   Bluetooth: hci0: command 0x2041 tx timeout
   usb 9-7: USB disconnect, device number 13
   ```

2. **Legacy scanning is rejected.** Once extended scanning is avoided, the
   kernel still uses extended *advertising*, and the chip then rejects the
   legacy scan commands with *Command Disallowed*, as the Bluetooth spec
   requires when the two command sets are mixed:

   ```
   Bluetooth: hci0: Opcode 0x200b failed: -16
   ```

3. **LE connections are dropped right away.** Just after connecting, the chip
   answers *LE Read Remote Used Features* with *Controller Busy*, and the kernel
   tears the link down. Pairing fails with `AuthenticationFailed` /
   `le-connection-abort-by-local`.

## What this driver changes

All changes are in `btusb` and only apply to Barrot devices
(`33fa:0010`, `33fa:0012`):

1. Sets `HCI_QUIRK_BROKEN_EXT_SCAN` and `HCI_QUIRK_BROKEN_EXT_CREATE_CONN`, so
   the kernel uses the legacy LE scan/connect commands.
2. Hides the *LE Extended Advertising* feature bit in the controller's answer,
   so the kernel never sends extended commands.
3. When the controller answers *LE Read Remote Used Features* with
   *Controller Busy*, turns it into success and completes the procedure with
   no remote features, so the connection is kept.

The whole change is in [`barrot-legacy-le.patch`](barrot-legacy-le.patch).
It can be switched off at runtime with the module parameter
`barrot_legacy_le=0`.

Fixes 2 and 3 rewrite controller events inside the driver. That is fine
for an out-of-tree workaround, but it is not how the kernel should fix it:
see [Upstream status](#upstream-status).

## Requirements

- `dkms`
- the headers for your running kernel (`linux-headers-$(uname -r)`)
- the compiler your kernel was built with: `make` plus `gcc`, or
  `clang` and `lld` (the Makefile picks LLVM automatically when the kernel
  was built with clang, as the PikaOS kernel is)
- `curl` and `patch`

On Debian/Ubuntu/PikaOS:

```sh
sudo apt install dkms linux-headers-$(uname -r) build-essential clang lld curl patch
```

## Install

```sh
git clone https://github.com/omocatodico/btusb-barrot.git
cd btusb-barrot

# Optional: try it first, until the next reboot only
sudo ./install.sh --test

# Install permanently via DKMS
sudo ./install.sh
```

Check that it is active:

```sh
cat /sys/module/btusb/parameters/barrot_legacy_le   # Y
sudo dmesg | grep Barrot                             # "Barrot: hiding LE extended advertising"
```

The script reloads the Bluetooth stack, so connected devices drop for a moment.

Uninstall and go back to the kernel's own `btusb`:

```sh
sudo ./install.sh --remove
```

## Pairing an Xbox Wireless Controller

Use your desktop's Bluetooth settings, or `bluetoothctl` **interactively**
(running `bluetoothctl pair ...` as a one-shot command has no agent and fails
with *No agent available*):

```
$ bluetoothctl
[bluetoothctl]> scan on
    (hold the controller's pair button until the Xbox logo blinks fast)
[bluetoothctl]> pair XX:XX:XX:XX:XX:XX
[bluetoothctl]> trust XX:XX:XX:XX:XX:XX
[bluetoothctl]> connect XX:XX:XX:XX:XX:XX
```

The controller shows up as a gamepad (`hid-microsoft`). After that it
reconnects on its own when you press the Xbox button.

## Kernel updates

On every new kernel, DKMS runs `fetch-src.sh`. It downloads `btusb.c` for that
kernel version from kernel.org and applies the patch again. If the download
fails, or the patch no longer applies, it builds the copy bundled in `src/`
(taken from 7.2.11), which may not build on much newer kernels. If the DKMS
build fails, the kernel's own `btusb` is used, so Bluetooth keeps working but
LE does not.

With **Secure Boot** enabled, the module has to be signed with a key your
firmware trusts (DKMS can do this with a MOK key, see your distribution's
documentation). Without that, the patched module won't load.

## Upstream status

A proper fix has been sent to the Linux kernel (linux-bluetooth) as a
3-patch series, fixing the problems in the Bluetooth core instead of
rewriting events in the driver:

<https://lore.kernel.org/all/20261031-barrot-le-fixes-v1-v1-0-30e2089882bf@tambosi.tn.it/>

Once it is merged into a kernel you run, this DKMS package is no longer
needed: remove it with `sudo ./install.sh --remove`.

**Distribution maintainers:** rather than shipping this DKMS package, you can
apply that series to your kernel. It is what will end up upstream, and it
was tested on 7.2.11 with the same hardware. A ready-to-apply backport for
v7.2.x is in [`kernel-patches/v7.2/`](kernel-patches/v7.2/), see
[`kernel-patches/README.md`](kernel-patches/README.md).

## Tested with

- UGREEN Bluetooth 5.4 adapter, `33fa:0010`, bcdDevice 88.91
- PikaOS, kernel `7.2.11-pikaos` (clang/LTO)
- Xbox Wireless Controller over BLE: pairing, reconnect, input

`33fa:0012` (UGREEN BT 6.0) uses the same code path but has not been tested.
Reports are welcome.

## Notes

The diagnosis, the patch and this package were made with the help of an AI
coding assistant (Claude, Anthropic); all hardware testing was done by me.

## License

GPL-2.0-or-later, the same as the kernel's `btusb.c`. See [LICENSE](LICENSE).
