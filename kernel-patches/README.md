# Kernel patches

The proper fix, for distributions that build their own kernel. Unlike the
DKMS workaround in this repository, these patches fix the problems in the
Bluetooth core instead of rewriting controller events in the driver.

They are the series submitted to linux-bluetooth:
<https://lore.kernel.org/all/20261031-barrot-le-fixes-v1-v1-0-30e2089882bf@tambosi.tn.it/>

1. `Bluetooth: hci_core: Don't use extended advertising with broken ext scan`
2. `Bluetooth: hci_event: Don't drop LE link on busy remote features read`
3. `Bluetooth: btusb: Disable broken LE extended scan on Barrot controllers`

## v7.2/

Backport for Linux v7.2.x. It applies cleanly to v7.2.11 with `git am` or
`patch -p1`:

```sh
cd linux-7.2.11
git am /path/to/kernel-patches/v7.2/*.patch
# or
for p in /path/to/kernel-patches/v7.2/*.patch; do patch -p1 < "$p"; done
```

- Patch 1 is unchanged.
- Patch 2 has its context adjusted: `hci_cs_le_read_remote_features()` in
  v7.2.x lacks code that is already in bluetooth-next. The behaviour is the
  same.
- Patch 3 only differs in the file name (`btusb.c` instead of
  `btusb_main.c`).

The notes under the `---` line of each patch say the same.

Tested on `7.2.11-pikaos` with a UGREEN Bluetooth 5.4 adapter (`33fa:0010`)
and an Xbox Wireless Controller: scanning, LE Secure Connections pairing,
reconnect and HID input work.

Not tested: `33fa:0012`, and the other controllers that already use
`HCI_QUIRK_BROKEN_EXT_SCAN` (hci_bcm4377, Actions ATS2851, Realtek
`0bda:a728`), which with patch 1 fall back to legacy advertising.

If the upstream series changes during review, these patches will be
updated to match.
