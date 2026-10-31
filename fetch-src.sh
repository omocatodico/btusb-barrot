#!/bin/sh
# Scarica btusb.c e gli header per la versione di kernel indicata
# e applica barrot-legacy-le.patch. Usato da DKMS (PRE_BUILD) e a mano.
#
#   fetch-src.sh <kernelver> <srcdir>
#
# Se il download fallisce (offline, tag inesistente) lascia i sorgenti
# già presenti in <srcdir>, che vengono comunque compilati.
set -e

KVER=${1:-$(uname -r)}
DEST=${2:-$(dirname "$0")}
PATCH=$(dirname "$0")/barrot-legacy-le.patch

# 7.2.11-pikaos -> v7.2.11 ; 7.3.0-foo -> v7.3
BASE=${KVER%%-*}
TAG=v$(echo "$BASE" | sed 's/\.0$//')
URL=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/bluetooth

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for f in btusb.c btintel.h btbcm.h btrtl.h btmtk.h; do
	if ! curl -sfL --max-time 30 -o "$TMP/$f" "$URL/$f?h=$TAG"; then
		echo "btusb-barrot: download di $f per $TAG fallito, uso i sorgenti inclusi" >&2
		exit 0
	fi
done

if grep -q barrot_legacy_le "$TMP/btusb.c"; then
	:
elif ! grep -q BTUSB_BARROT "$TMP/btusb.c"; then
	echo "btusb-barrot: $TAG non conosce BTUSB_BARROT, uso i sorgenti inclusi" >&2
	exit 0
elif ! patch -s -d "$TMP" -p3 < "$PATCH"; then
	echo "btusb-barrot: patch non applicabile a $TAG, uso i sorgenti inclusi" >&2
	exit 0
fi

cp "$TMP"/btusb.c "$TMP"/*.h "$DEST"/
echo "btusb-barrot: sorgenti $TAG scaricati e patchati"
