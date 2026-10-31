#!/bin/sh
# Installa btusb patchato per le chiavette Barrot (33fa:0010 / 33fa:0012).
#
#   sudo ./install.sh            installa via DKMS (persistente, ricompila ad ogni kernel)
#   sudo ./install.sh --test     compila e carica il modulo solo fino al riavvio
#   sudo ./install.sh --remove   disinstalla e torna al btusb del kernel
set -e

NAME=btusb-barrot
VER=1.0
HERE=$(cd "$(dirname "$0")" && pwd)
USRC=/usr/src/$NAME-$VER

[ "$(id -u)" = 0 ] || { echo "Serve root: sudo $0 $*" >&2; exit 1; }

reload() {
	systemctl stop bluetooth || true
	modprobe -r btusb || true
	if [ -n "$1" ]; then
		modprobe -a btintel btbcm btrtl btmtk
		insmod "$1" || { echo "insmod fallito, ricarico btusb originale" >&2; modprobe btusb; }
	else
		modprobe btusb
	fi
	systemctl start bluetooth
	sleep 2
	echo "barrot_legacy_le = $(cat /sys/module/btusb/parameters/barrot_legacy_le 2>/dev/null || echo 'assente (btusb originale)')"
}

case "$1" in
--test)
	B=$(mktemp -d)
	cp "$HERE"/src/* "$HERE"/fetch-src.sh "$HERE"/barrot-legacy-le.patch "$B"/
	(cd "$B" && ./fetch-src.sh "$(uname -r)" . && make)
	reload "$B/btusb.ko"
	;;
--remove)
	dkms remove "$NAME/$VER" --all 2>/dev/null || true
	rm -rf "$USRC"
	depmod -a
	reload
	;;
*)
	dkms remove "$NAME/$VER" --all 2>/dev/null || true
	rm -rf "$USRC"
	mkdir -p "$USRC"
	cp "$HERE"/src/* "$HERE"/fetch-src.sh "$HERE"/barrot-legacy-le.patch "$USRC"/
	dkms add "$NAME/$VER"
	dkms install "$NAME/$VER" -k "$(uname -r)"
	reload
	;;
esac
