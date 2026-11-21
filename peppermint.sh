#!/usr/bin/env bash
# peppermint.sh - Peppermint OS 9 izgled na bilo kojoj Debian/Ubuntu XFCE distri (test grana)
#
#   curl -fsSL https://raw.githubusercontent.com/Badzolini/xfce4-theme/peppermint/peppermint.sh | bash
#   curl -fsSL .../peppermint.sh | COLOR=Blue-Mix bash      # druga boja
#
# Skida granu "peppermint" u ~/.local/share/xfce4-theme-peppermint i pokreće apply-profile.sh.
set -euo pipefail

BRANCH="${BRANCH:-peppermint}"
COLOR="${COLOR:-Red-Dark}"
DEST="$HOME/.local/share/xfce4-theme-peppermint"
URL="https://github.com/Badzolini/xfce4-theme/archive/refs/heads/$BRANCH.tar.gz"

[[ $EUID -eq 0 ]] && { echo "Pokreni kao običan korisnik, ne kao root."; exit 1; }
command -v curl >/dev/null || { sudo apt-get update && sudo apt-get install -y curl; }

echo "==> Skidam granu $BRANCH"
rm -rf "$DEST"; mkdir -p "$DEST"
curl -fsSL "$URL" | tar xz -C "$DEST" --strip-components=1

exec "$DEST/apply-profile.sh" peppermint --color "$COLOR"
