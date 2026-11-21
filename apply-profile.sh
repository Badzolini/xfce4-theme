#!/usr/bin/env bash
# apply-profile.sh - primeni XFCE izgled iz profiles/<ime> na bilo koju Debian/Ubuntu distru
#
#   ./apply-profile.sh                          # peppermint, Red-Dark
#   ./apply-profile.sh peppermint --color Blue-Mix
#   ./apply-profile.sh --list                   # spisak profila i boja
#
# Radi na: Linux Mint XFCE, Xubuntu, Kali, Parrot (instalira XFCE ako ga nema).
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PROFILE="peppermint"
COLOR=""
FIRSTLOGIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --color) COLOR="$2"; shift 2 ;;
    --firstlogin) FIRSTLOGIN=1; shift ;;
    --list)
      for p in "$REPO"/profiles/*/; do
        echo "$(basename "$p"):"
        ls "$p/themes" 2>/dev/null | sed -n 's/^Peppermint-\(.*-\(Dark\|Light\|Mix\)\)$/  \1/p'
      done; exit 0 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) PROFILE="$1"; shift ;;
  esac
done

DIR="$REPO/profiles/$PROFILE"
[[ -f "$DIR/profile.conf" ]] || { echo "Nema profila: $PROFILE"; exit 1; }
# shellcheck source=/dev/null
source "$DIR/profile.conf"
COLOR="${COLOR:-$DEFAULT_COLOR}"
GTK_THEME="Peppermint-$COLOR"
[[ -d "$DIR/themes/$GTK_THEME" ]] || { echo "Nema boje $COLOR (vidi --list)"; exit 1; }

log(){ printf '\e[1;32m==>\e[0m %s\n' "$*"; }
XFCONF_DIR="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

# ---------- 1. Paketi (preskače se pri --firstlogin) ----------
if [[ $FIRSTLOGIN -eq 0 ]]; then
  if ! command -v xfce4-session >/dev/null; then
    log "XFCE nije instaliran - instaliram (Parrot/Kali bez XFCE)"
    sudo apt-get update
    sudo apt-get install -y xfce4 xfce4-goodies
  fi
  log "Paketi za profil"
  avail=()
  for p in $PACKAGES fonts-ubuntu; do
    apt-cache show "$p" >/dev/null 2>&1 && avail+=("$p") || echo "   (preskačem $p - nema u repou)"
  done
  sudo apt-get install -y "${avail[@]}"
fi

# ---------- 2. Teme, ikone ----------
log "Kopiram teme u ~/.themes"
mkdir -p ~/.themes ~/.icons
cp -r "$DIR"/themes/* ~/.themes/
[[ -d "$DIR/icons" ]] && cp -r "$DIR"/icons/* ~/.icons/

if [[ -d ~/.icons/$ICON_THEME || -d /usr/share/icons/$ICON_THEME ]]; then
  ICONS="$ICON_THEME"; MENU_ICON="peppermint"
else
  ICONS="$ICON_FALLBACK"; MENU_ICON="start-here"
fi
fc-list : family | grep -i "^Ubuntu" >/dev/null && FONT_USE="$FONT" || { FONT_USE="$FONT_FALLBACK"; TITLE_FONT="${FONT_FALLBACK% *} Bold 9"; }

# ---------- 3. Ako nismo u XFCE sesiji: završi pri sledećem loginu ----------
if [[ -z "${DISPLAY:-}" ]] || ! pgrep -u "$(id -u)" -x xfce4-session >/dev/null; then
  mkdir -p ~/.config/autostart
  cat > ~/.config/autostart/apply-xfce-profile.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Apply XFCE profile (one-shot)
Exec=sh -c '"$REPO/apply-profile.sh" "$PROFILE" --color "$COLOR" --firstlogin && rm -f ~/.config/autostart/apply-xfce-profile.desktop'
X-GNOME-Autostart-enabled=true
EOF
  log "Nisi u XFCE sesiji. Odjavi se, na login ekranu izaberi 'Xfce Session' - izgled se primenjuje automatski."
  exit 0
fi

# ---------- 4. Panel (mora dok xfconfd ne radi) ----------
log "Panel (backup: ~/.config/xfce4/panel.bak-*)"
TS=$(date +%s)
xfce4-panel --quit 2>/dev/null || true
pkill -x xfconfd 2>/dev/null || true; sleep 1
[[ -d ~/.config/xfce4/panel ]] && mv ~/.config/xfce4/panel ~/.config/xfce4/panel.bak-$TS
[[ -f $XFCONF_DIR/xfce4-panel.xml ]] && cp $XFCONF_DIR/xfce4-panel.xml ~/.config/xfce4/xfce4-panel.xml.bak-$TS
mkdir -p "$XFCONF_DIR" ~/.config/xfce4/panel
cp "$DIR/panel/xfce4-panel.xml" "$XFCONF_DIR/"
cp -r "$DIR"/panel/launcher-* ~/.config/xfce4/panel/
sed "s/^button-icon=.*/button-icon=$MENU_ICON/" "$DIR/panel/whiskermenu-1.rc" > ~/.config/xfce4/panel/whiskermenu-1.rc

# ---------- 5. Izgled preko xfconf ----------
log "Tema $GTK_THEME, ikone $ICONS, font $FONT_USE"
set_x(){ xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"; }
set_x xsettings /Net/ThemeName        string "$GTK_THEME"
set_x xsettings /Net/IconThemeName    string "$ICONS"
set_x xsettings /Gtk/CursorThemeName  string "$CURSOR_THEME"
set_x xsettings /Gtk/CursorThemeSize  int    "$CURSOR_SIZE"
set_x xsettings /Gtk/FontName         string "$FONT_USE"
set_x xsettings /Gtk/ButtonImages     bool   true
set_x xsettings /Gtk/MenuImages       bool   true
set_x xsettings /Xft/Antialias        int    1
set_x xsettings /Xft/Hinting          int    1
set_x xsettings /Xft/HintStyle        string hintfull
set_x xsettings /Xft/RGBA             string rgb

# xfwm4 - Peppermint vrednosti (transparencija + senke)
set_x xfwm4 /general/theme                string "$XFWM_THEME"
set_x xfwm4 /general/title_font           string "$TITLE_FONT"
set_x xfwm4 /general/button_layout        string "O|HMC"
set_x xfwm4 /general/title_alignment      string center
set_x xfwm4 /general/placement_mode       string center
set_x xfwm4 /general/use_compositing      bool   true
set_x xfwm4 /general/show_frame_shadow    bool   true
set_x xfwm4 /general/show_popup_shadow    bool   true
set_x xfwm4 /general/show_dock_shadow     bool   false
set_x xfwm4 /general/shadow_opacity       int    50
set_x xfwm4 /general/shadow_delta_y       int    -3
set_x xfwm4 /general/inactive_opacity     int    83
set_x xfwm4 /general/move_opacity         int    83
set_x xfwm4 /general/resize_opacity       int    83
set_x xfwm4 /general/borderless_maximize  bool   true
set_x xfwm4 /general/tile_on_move         bool   true
set_x xfwm4 /general/workspace_count      int    2

# GTK4/libadwaita ne prate GTK temu - bar im daj tamni/svetli režim
if command -v gsettings >/dev/null; then
  [[ $COLOR == *Dark ]] && scheme=prefer-dark || scheme=default
  gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null || true
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
fi

(setsid xfce4-panel >/dev/null 2>&1 &)
log "Gotovo: $PROFILE / $COLOR. Za drugu boju: $0 $PROFILE --color Blue-Mix"
