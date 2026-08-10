#!/usr/bin/env bash
# Symlink tokenscope tools into ~/bin (or $TOKENSCOPE_BIN).
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin"
DEST="${TOKENSCOPE_BIN:-$HOME/bin}"
mkdir -p "$DEST"
for f in ctok ctok-status shot; do
  ln -sf "$SRC/$f" "$DEST/$f"
  echo "  linked $DEST/$f"
done
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo; echo "  note: $DEST is not on your PATH — add:"; echo "    export PATH=\"\$PATH:$DEST\"" ;;
esac
echo
echo "try:  ctok -c -b"
