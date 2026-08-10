#!/usr/bin/env bash
# Symlink cato tools into ~/bin (or $CATO_BIN).
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin"
DEST="${CATO_BIN:-$HOME/bin}"
mkdir -p "$DEST"
for f in cato cato-status imago; do
  ln -sf "$SRC/$f" "$DEST/$f"
  echo "  linked $DEST/$f"
done
case ":$PATH:" in
  *":$DEST:"*) ;;
  *) echo; echo "  note: $DEST is not on your PATH — add:"; echo "    export PATH=\"\$PATH:$DEST\"" ;;
esac
echo
echo "try:  cato -c -b"
