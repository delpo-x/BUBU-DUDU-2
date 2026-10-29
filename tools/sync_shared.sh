#!/bin/sh
# Copy the files shared with the first game (art, audio, pad input, UI theme) from a
# sibling checkout of BUBU-DUDU. Run from this repo's root: sh tools/sync_shared.sh [path]
set -e
SRC="${1:-../BUBU-DUDU}"
while read -r p; do
	[ -z "$p" ] && continue
	mkdir -p "$(dirname "$p")"
	rm -rf "$p"
	cp -r "$SRC/$p" "$p"
	[ -f "$SRC/$p.uid" ] && cp "$SRC/$p.uid" "$p.uid"
done < tools/shared.txt
echo "synced from $SRC"
