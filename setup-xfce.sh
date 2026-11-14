#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# setup-xfce.sh - installs XFCE + your apps and applies your exact desktop
# settings (panel, whisker menu, Docklike, theme, window buttons, shortcuts).
# Works on Debian/Ubuntu-based distros (tested layout: Parrot 7 / Debian 13).
# Run as your NORMAL user (not root).   Usage:  bash setup-xfce.sh
#   SKIP_INSTALL=1 bash setup-xfce.sh   -> only apply the settings
# ---------------------------------------------------------------------------
set -u

[ "$(id -u)" -eq 0 ] && { echo "Run this as your normal user, not root."; exit 1; }
command -v apt-get >/dev/null || { echo "This script needs a Debian/Ubuntu-based system."; exit 1; }

MA=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo x86_64-linux-gnu)

# Where the Parrot theme bundle (Windows 10 Dark, htb icons, Parrot logo) is downloaded from
# when it is not already next to the script. Edit YOUR_GITHUB_USER once, after you upload the release.
BUNDLE_URL="${BUNDLE_URL:-https://github.com/YOUR_GITHUB_USER/xfce-setup/releases/latest/download/parrot-look.tar.gz}"

# Edit these lists freely. Packages that do not exist on a distro are skipped.
CORE="xfce4 xfce4-goodies xfce4-whiskermenu-plugin xfce4-docklike-plugin xfce4-pulseaudio-plugin xfce4-notifyd xfce4-power-manager-plugins xapp pavucontrol"
LOOK="arc-theme greybird-gtk-theme numix-gtk-theme numix-icon-theme papirus-icon-theme yaru-theme-gtk dmz-cursor-theme fonts-cantarell"
APPS=""   # extra tools: add package names here if you want any (e.g. APPS="htop git")

# the binary name differs between versions, so also check for the menu entry
have_tm() { command -v xfce4-theme-manager >/dev/null || command -v xfce-theme-manager >/dev/null \
  || ls /usr/share/applications /usr/local/share/applications 2>/dev/null | grep -qi 'theme-manager'; }

put() { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# ----------------------------------------------------------------- install
install_all() {
  echo "== apt update =="
  sudo apt-get update

  # keep only packages this distro actually has, then install in ONE apt run
  local want="$CORE $LOOK $APPS" ok="" p
  systemd-detect-virt -q 2>/dev/null && want="$want qemu-guest-agent spice-vdagent"
  for p in $want; do apt-cache show "$p" >/dev/null 2>&1 && ok="$ok $p" || echo "  (skipping $p: not in repos)"; done
  echo "== install packages =="
  sudo apt-get install -y $ok

  echo "== Docklike plugin =="
  if ! ls /usr/lib/$MA/xfce4/panel/plugins 2>/dev/null | grep -qi docklike; then
    sudo apt-get update
    sudo apt-get install -y git build-essential autoconf automake libtool xfce4-dev-tools \
      libxfce4panel-2.0-dev libxfce4ui-2-dev libgtk-3-dev libwnck-3-dev libx11-dev libcairo2-dev
    rm -rf /tmp/docklike-plugin
    git clone https://github.com/nsz32/docklike-plugin /tmp/docklike-plugin \
      && ( cd /tmp/docklike-plugin && ./autogen.sh --prefix=/usr --libdir=/usr/lib/$MA && make -j"$(nproc)" && sudo make install )
  fi
  ls /usr/lib/$MA/xfce4/panel/plugins 2>/dev/null | grep -qi docklike || echo "WARNING: Docklike plugin is missing"

  echo "== Xfce Theme Manager =="
  if ! have_tm; then
    sudo apt-get update
    sudo apt-get install -y git unzip build-essential libglib2.0-dev libgtk2.0-dev libgtk-3-dev libxfce4ui-2-dev libcairo2-dev
    rm -rf /tmp/Xfce-Theme-Manager
    git clone https://github.com/KeithDHedger/Xfce-Theme-Manager /tmp/Xfce-Theme-Manager \
      && ( cd /tmp/Xfce-Theme-Manager && (./autogen.sh || true) && make -j"$(nproc)" && sudo make install PREFIX=/usr )
  fi
  have_tm || echo "WARNING: Xfce Theme Manager failed to build"

  echo "== Brave Origin (nightly) =="
  command -v brave-origin-nightly >/dev/null || { command -v curl >/dev/null || sudo apt-get install -y curl; curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin CHANNEL=nightly sh \
    || echo "  Brave install failed, skipping"; }
}

# ------------------------------------------------- themes (downloaded, minimal)
get_win10dark() {
  [ -d "/usr/share/themes/Windows 10 Dark" ] && return 0
  echo "== downloading 'Windows 10 Dark' theme (~9 MB .deb from Parrot) =="
  local base="https://deb.parrot.sh/parrot/pool/main/p/parrot-themes/" deb tmp
  tmp=$(mktemp -d)
  deb=$(curl -fsSL --retry 3 "$base" | grep -o 'parrot-themes_[0-9][^"<>]*_all\.deb' | sort -uV | tail -1)
  [ -n "$deb" ] || deb="parrot-themes_7.1_all.deb"
  if curl -fL --retry 5 --retry-delay 3 -C - -o "$tmp/t.deb" "$base$deb"; then
    dpkg-deb -x "$tmp/t.deb" "$tmp/x" && sudo cp -a "$tmp/x/usr/share/themes/Windows 10 Dark" /usr/share/themes/
  else
    echo "  download failed -> fallback theme"
  fi
  rm -rf "$tmp"
}

get_htb_icons() {
  { [ -d /usr/share/icons/htb-icon-theme ] || [ -d /usr/share/icons/Hack-The-Box-Icons ]; } && return 0
  echo "== downloading HTB icons (only 16px + 32px, ~60 MB) =="
  command -v git >/dev/null || sudo apt-get install -y git
  local tmp d s c; tmp=$(mktemp -d)
  local paths=""
  for s in 16x16 32x32; do for c in apps places mimetypes devices categories status; do
    paths="$paths usr/share/icons/Hack-The-Box-Icons/$s/$c"; done; done
  if git clone -q --depth 1 --filter=blob:none --sparse https://github.com/botnetbuddies/hackthebox-themes "$tmp/r" \
     && git -C "$tmp/r" sparse-checkout set $paths; then
    sudo cp -a "$tmp/r/usr/share/icons/Hack-The-Box-Icons" /usr/share/icons/
    sudo gtk-update-icon-cache -f /usr/share/icons/Hack-The-Box-Icons 2>/dev/null || true
  else
    echo "  HTB icons download failed -> fallback icons"
  fi
  rm -rf "$tmp"
}

extract_look() {
  local here f
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  for f in "$here/parrot-look.tar.gz" "$HOME/parrot-look.tar.gz" "$HOME/Documents/parrot-look.tar.gz" "$HOME/Downloads/parrot-look.tar.gz"; do
    if [ -f "$f" ]; then
      echo "== unpacking themes from $f =="
      sudo tar xzf "$f" -C / && sudo gtk-update-icon-cache -f /usr/share/icons/htb-icon-theme 2>/dev/null
      return
    fi
  done
  get_win10dark
  get_htb_icons
}

# ---------------------------------------------------------------- settings
write_settings() {
  echo "== writing your settings =="
  if [ -d "$HOME/.config/xfce4" ] && [ ! -e "$HOME/.config/xfce4.bak-setup" ]; then
    cp -a "$HOME/.config/xfce4" "$HOME/.config/xfce4.bak-setup"
  fi

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" <<'XFCE_EOF'
<?xml version="1.1" encoding="UTF-8"?>

<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Windows 10 Dark"/>
    <property name="IconThemeName" type="string" value="htb-icon-theme"/>
    <property name="DoubleClickTime" type="int" value="250"/>
    <property name="DoubleClickDistance" type="int" value="5"/>
    <property name="DndDragThreshold" type="int" value="8"/>
    <property name="CursorBlink" type="bool" value="true"/>
    <property name="CursorBlinkTime" type="int" value="1200"/>
    <property name="SoundThemeName" type="string" value="default"/>
    <property name="EnableEventSounds" type="bool" value="true"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="true"/>
  </property>
  <property name="Xft" type="empty">
    <property name="DPI" type="empty"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="0"/>
    <property name="HintStyle" type="string" value="hintnone"/>
    <property name="RGBA" type="string" value="none"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CanChangeAccels" type="bool" value="true"/>
    <property name="ColorPalette" type="string" value="black:white:gray50:red:purple:blue:light blue:green:yellow:orange:lavender:brown:goldenrod4:dodger blue:pink:light green:gray10:gray30:gray75:gray90"/>
    <property name="FontName" type="string" value="Cantarell 11"/>
    <property name="MonospaceFontName" type="string" value="Monospace 11"/>
    <property name="IconSizes" type="string" value=""/>
    <property name="KeyThemeName" type="string" value=""/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuBarAccel" type="string" value="F10"/>
    <property name="CursorThemeName" type="string" value="DMZ-Black"/>
    <property name="CursorThemeSize" type="int" value="0"/>
    <property name="DecorationLayout" type="string" value="icon,menu:minimize,maximize,close"/>
    <property name="DialogsUseHeader" type="empty"/>
    <property name="TitlebarMiddleClick" type="empty"/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ToolbarIconSize" type="int" value="3"/>
    <property name="IMPreeditStyle" type="string" value=""/>
    <property name="IMStatusStyle" type="string" value=""/>
    <property name="IMModule" type="string" value=""/>
  </property>
  <property name="Gdk" type="empty">
    <property name="WindowScalingFactor" type="empty"/>
  </property>
</channel>
XFCE_EOF

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'XFCE_EOF'
<?xml version="1.1" encoding="UTF-8"?>

<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="activate_action" type="string" value="bring"/>
    <property name="borderless_maximize" type="bool" value="true"/>
    <property name="box_move" type="bool" value="false"/>
    <property name="box_resize" type="bool" value="false"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="button_offset" type="int" value="0"/>
    <property name="button_spacing" type="int" value="0"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="focus_delay" type="int" value="250"/>
    <property name="cycle_apps_only" type="bool" value="false"/>
    <property name="cycle_draw_frame" type="bool" value="true"/>
    <property name="cycle_hidden" type="bool" value="true"/>
    <property name="cycle_minimum" type="bool" value="true"/>
    <property name="cycle_workspaces" type="bool" value="true"/>
    <property name="double_click_time" type="int" value="250"/>
    <property name="double_click_distance" type="int" value="5"/>
    <property name="double_click_action" type="string" value="maximize"/>
    <property name="easy_click" type="string" value="None"/>
    <property name="focus_hint" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="frame_opacity" type="int" value="100"/>
    <property name="full_width_title" type="bool" value="true"/>
    <property name="inactive_opacity" type="int" value="78"/>
    <property name="maximized_offset" type="int" value="0"/>
    <property name="move_opacity" type="int" value="68"/>
    <property name="placement_ratio" type="int" value="20"/>
    <property name="placement_mode" type="string" value="center"/>
    <property name="popup_opacity" type="int" value="93"/>
    <property name="mousewheel_rollup" type="bool" value="false"/>
    <property name="prevent_focus_stealing" type="bool" value="false"/>
    <property name="raise_delay" type="int" value="250"/>
    <property name="raise_on_click" type="bool" value="true"/>
    <property name="raise_on_focus" type="bool" value="false"/>
    <property name="raise_with_any_button" type="bool" value="false"/>
    <property name="repeat_urgent_blink" type="bool" value="false"/>
    <property name="resize_opacity" type="int" value="70"/>
    <property name="restore_on_move" type="bool" value="true"/>
    <property name="scroll_workspaces" type="bool" value="false"/>
    <property name="shadow_delta_height" type="int" value="0"/>
    <property name="shadow_delta_width" type="int" value="0"/>
    <property name="shadow_delta_x" type="int" value="0"/>
    <property name="shadow_delta_y" type="int" value="-3"/>
    <property name="shadow_opacity" type="int" value="50"/>
    <property name="show_app_icon" type="bool" value="false"/>
    <property name="show_dock_shadow" type="bool" value="true"/>
    <property name="show_frame_shadow" type="bool" value="true"/>
    <property name="show_popup_shadow" type="bool" value="true"/>
    <property name="snap_resist" type="bool" value="false"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
    <property name="snap_width" type="int" value="10"/>
    <property name="theme" type="string" value="Yaru-dark"/>
    <property name="title_alignment" type="string" value="left"/>
    <property name="title_font" type="string" value="Sans Bold 9"/>
    <property name="title_horizontal_offset" type="int" value="0"/>
    <property name="title_shadow_active" type="string" value="false"/>
    <property name="title_shadow_inactive" type="string" value="false"/>
    <property name="title_vertical_offset_active" type="int" value="0"/>
    <property name="title_vertical_offset_inactive" type="int" value="0"/>
    <property name="toggle_workspaces" type="bool" value="false"/>
    <property name="unredirect_overlays" type="bool" value="true"/>
    <property name="urgent_blink" type="bool" value="false"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="wrap_cycle" type="bool" value="true"/>
    <property name="wrap_layout" type="bool" value="true"/>
    <property name="wrap_resistance" type="int" value="10"/>
    <property name="wrap_windows" type="bool" value="false"/>
    <property name="wrap_workspaces" type="bool" value="false"/>
    <property name="workspace_names" type="array">
      <value type="string" value="Workspace 1"/>
      <value type="string" value="Workspace 2"/>
      <value type="string" value="Workspace 3"/>
      <value type="string" value="Workspace 4"/>
      <value type="string" value="Workspace 5"/>
    </property>
    <property name="cycle_raise" type="bool" value="false"/>
    <property name="cycle_preview" type="bool" value="true"/>
    <property name="cycle_tabwin_mode" type="int" value="0"/>
    <property name="frame_border_top" type="int" value="0"/>
    <property name="horiz_scroll_opacity" type="bool" value="false"/>
    <property name="vblank_mode" type="string" value="auto"/>
    <property name="tile_on_move" type="bool" value="true"/>
    <property name="titleless_maximize" type="bool" value="false"/>
    <property name="zoom_desktop" type="bool" value="true"/>
    <property name="cycle_minimized" type="bool" value="false"/>
    <property name="zoom_pointer" type="bool" value="true"/>
  </property>
</channel>
XFCE_EOF

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" <<'XFCE_EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Alt&gt;&lt;Super&gt;s" type="string" value="orca"/>
      <property name="&lt;Alt&gt;F1" type="string" value="xfce4-popup-applicationsmenu"/>
      <property name="&lt;Alt&gt;F2" type="string" value="xfce4-appfinder --collapsed">
        <property name="startup-notify" type="bool" value="true"/>
      </property>
      <property name="&lt;Alt&gt;F3" type="string" value="xfce4-appfinder">
        <property name="startup-notify" type="bool" value="true"/>
      </property>
      <property name="&lt;Alt&gt;Print" type="string" value="xfce4-screenshooter -w"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Delete" type="string" value="xflock4"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Escape" type="string" value="xkill"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;f" type="string" value="thunar"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;l" type="string" value="xflock4"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;t" type="string" value="exo-open --launch TerminalEmulator"/>
      <property name="&lt;Primary&gt;&lt;Shift&gt;Escape" type="string" value="xfce4-taskmanager"/>
      <property name="&lt;Primary&gt;Escape" type="string" value="xfdesktop --menu"/>
      <property name="&lt;Shift&gt;Print" type="string" value="xfce4-screenshooter -r"/>
      <property name="&lt;Super&gt;e" type="string" value="thunar"/>
      <property name="&lt;Super&gt;l" type="string" value="xflock4"/>
      <property name="&lt;Super&gt;p" type="string" value="xfce4-display-settings --minimal"/>
      <property name="&lt;Super&gt;r" type="string" value="xfce4-appfinder -c">
        <property name="startup-notify" type="bool" value="true"/>
      </property>
      <property name="HomePage" type="string" value="exo-open --launch WebBrowser"/>
      <property name="Print" type="string" value="xfce4-screenshooter"/>
      <property name="Super_L" type="string" value="xfce4-popup-whiskermenu"/>
      <property name="XF86Display" type="string" value="xfce4-display-settings --minimal"/>
      <property name="XF86Mail" type="string" value="exo-open --launch MailReader"/>
      <property name="XF86WWW" type="string" value="exo-open --launch WebBrowser"/>
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
  <property name="xfwm4" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Alt&gt;&lt;Control&gt;End" type="string" value="move_window_next_workspace_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;Home" type="string" value="move_window_prev_workspace_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_1" type="string" value="move_window_workspace_1_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_2" type="string" value="move_window_workspace_2_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_3" type="string" value="move_window_workspace_3_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_4" type="string" value="move_window_workspace_4_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_5" type="string" value="move_window_workspace_5_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_6" type="string" value="move_window_workspace_6_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_7" type="string" value="move_window_workspace_7_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_8" type="string" value="move_window_workspace_8_key"/>
      <property name="&lt;Alt&gt;&lt;Control&gt;KP_9" type="string" value="move_window_workspace_9_key"/>
      <property name="&lt;Alt&gt;&lt;Shift&gt;Tab" type="string" value="cycle_reverse_windows_key"/>
      <property name="&lt;Alt&gt;Delete" type="string" value="del_workspace_key"/>
      <property name="&lt;Alt&gt;F10" type="string" value="maximize_window_key"/>
      <property name="&lt;Alt&gt;F11" type="string" value="fullscreen_key"/>
      <property name="&lt;Alt&gt;F12" type="string" value="above_key"/>
      <property name="&lt;Alt&gt;F4" type="string" value="close_window_key"/>
      <property name="&lt;Alt&gt;F6" type="string" value="stick_window_key"/>
      <property name="&lt;Alt&gt;F7" type="string" value="move_window_key"/>
      <property name="&lt;Alt&gt;F8" type="string" value="resize_window_key"/>
      <property name="&lt;Alt&gt;F9" type="string" value="hide_window_key"/>
      <property name="&lt;Alt&gt;Insert" type="string" value="add_workspace_key"/>
      <property name="&lt;Alt&gt;Tab" type="string" value="cycle_windows_key"/>
      <property name="&lt;Alt&gt;space" type="string" value="popup_menu_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Down" type="string" value="down_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Left" type="string" value="left_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Right" type="string" value="right_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;Up" type="string" value="up_workspace_key"/>
      <property name="&lt;Control&gt;&lt;Alt&gt;d" type="string" value="show_desktop_key"/>
      <property name="&lt;Control&gt;&lt;Shift&gt;&lt;Alt&gt;Left" type="string" value="move_window_left_key"/>
      <property name="&lt;Control&gt;&lt;Shift&gt;&lt;Alt&gt;Right" type="string" value="move_window_right_key"/>
      <property name="&lt;Control&gt;&lt;Shift&gt;&lt;Alt&gt;Up" type="string" value="move_window_up_key"/>
      <property name="&lt;Control&gt;F1" type="string" value="workspace_1_key"/>
      <property name="&lt;Control&gt;F10" type="string" value="workspace_10_key"/>
      <property name="&lt;Control&gt;F11" type="string" value="workspace_11_key"/>
      <property name="&lt;Control&gt;F12" type="string" value="workspace_12_key"/>
      <property name="&lt;Control&gt;F2" type="string" value="workspace_2_key"/>
      <property name="&lt;Control&gt;F3" type="string" value="workspace_3_key"/>
      <property name="&lt;Control&gt;F4" type="string" value="workspace_4_key"/>
      <property name="&lt;Control&gt;F5" type="string" value="workspace_5_key"/>
      <property name="&lt;Control&gt;F6" type="string" value="workspace_6_key"/>
      <property name="&lt;Control&gt;F7" type="string" value="workspace_7_key"/>
      <property name="&lt;Control&gt;F8" type="string" value="workspace_8_key"/>
      <property name="&lt;Control&gt;F9" type="string" value="workspace_9_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;1" type="string" value="workspace_1_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;2" type="string" value="workspace_2_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;3" type="string" value="workspace_3_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;4" type="string" value="workspace_4_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;5" type="string" value="workspace_5_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;6" type="string" value="workspace_6_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;7" type="string" value="workspace_7_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;8" type="string" value="workspace_8_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;9" type="string" value="workspace_9_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Down" type="string" value="down_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;End" type="string" value="move_window_next_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Home" type="string" value="move_window_prev_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_1" type="string" value="move_window_workspace_1_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_2" type="string" value="move_window_workspace_2_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_3" type="string" value="move_window_workspace_3_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_4" type="string" value="move_window_workspace_4_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_5" type="string" value="move_window_workspace_5_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_6" type="string" value="move_window_workspace_6_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_7" type="string" value="move_window_workspace_7_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_8" type="string" value="move_window_workspace_8_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;KP_9" type="string" value="move_window_workspace_9_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Left" type="string" value="left_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Right" type="string" value="right_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;Up" type="string" value="up_workspace_key"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;d" type="string" value="show_desktop_key"/>
      <property name="&lt;Primary&gt;&lt;Shift&gt;&lt;Alt&gt;Left" type="string" value="move_window_left_key"/>
      <property name="&lt;Primary&gt;&lt;Shift&gt;&lt;Alt&gt;Right" type="string" value="move_window_right_key"/>
      <property name="&lt;Primary&gt;&lt;Shift&gt;&lt;Alt&gt;Up" type="string" value="move_window_up_key"/>
      <property name="&lt;Primary&gt;&lt;Super&gt;Down" type="string" value="tile_down_key"/>
      <property name="&lt;Primary&gt;&lt;Super&gt;Left" type="string" value="tile_left_key"/>
      <property name="&lt;Primary&gt;&lt;Super&gt;Right" type="string" value="tile_right_key"/>
      <property name="&lt;Primary&gt;&lt;Super&gt;Up" type="string" value="tile_up_key"/>
      <property name="&lt;Primary&gt;F1" type="string" value="workspace_1_key"/>
      <property name="&lt;Primary&gt;F10" type="string" value="workspace_10_key"/>
      <property name="&lt;Primary&gt;F11" type="string" value="workspace_11_key"/>
      <property name="&lt;Primary&gt;F12" type="string" value="workspace_12_key"/>
      <property name="&lt;Primary&gt;F2" type="string" value="workspace_2_key"/>
      <property name="&lt;Primary&gt;F3" type="string" value="workspace_3_key"/>
      <property name="&lt;Primary&gt;F4" type="string" value="workspace_4_key"/>
      <property name="&lt;Primary&gt;F5" type="string" value="workspace_5_key"/>
      <property name="&lt;Primary&gt;F6" type="string" value="workspace_6_key"/>
      <property name="&lt;Primary&gt;F7" type="string" value="workspace_7_key"/>
      <property name="&lt;Primary&gt;F8" type="string" value="workspace_8_key"/>
      <property name="&lt;Primary&gt;F9" type="string" value="workspace_9_key"/>
      <property name="&lt;Shift&gt;&lt;Alt&gt;Page_Down" type="string" value="lower_window_key"/>
      <property name="&lt;Shift&gt;&lt;Alt&gt;Page_Up" type="string" value="raise_window_key"/>
      <property name="&lt;Super&gt;Down" type="string" value="hide_window_key"/>
      <property name="&lt;Super&gt;KP_Down" type="string" value="tile_down_key"/>
      <property name="&lt;Super&gt;KP_End" type="string" value="tile_down_left_key"/>
      <property name="&lt;Super&gt;KP_Home" type="string" value="tile_up_left_key"/>
      <property name="&lt;Super&gt;KP_Left" type="string" value="tile_left_key"/>
      <property name="&lt;Super&gt;KP_Next" type="string" value="tile_down_right_key"/>
      <property name="&lt;Super&gt;KP_Page_Up" type="string" value="tile_up_right_key"/>
      <property name="&lt;Super&gt;KP_Right" type="string" value="tile_right_key"/>
      <property name="&lt;Super&gt;KP_Up" type="string" value="tile_up_key"/>
      <property name="&lt;Super&gt;Left" type="string" value="tile_left_key"/>
      <property name="&lt;Super&gt;Right" type="string" value="tile_right_key"/>
      <property name="&lt;Super&gt;Tab" type="string" value="switch_window_key"/>
      <property name="&lt;Super&gt;Up" type="string" value="maximize_window_key"/>
      <property name="&lt;Super&gt;d" type="string" value="show_desktop_key"/>
      <property name="Down" type="string" value="down_key"/>
      <property name="Escape" type="string" value="cancel_key"/>
      <property name="Left" type="string" value="left_key"/>
      <property name="Right" type="string" value="right_key"/>
      <property name="Up" type="string" value="up_key"/>
      <property name="override" type="bool" value="true"/>
    </property>
  </property>
  <property name="providers" type="empty"/>
</channel>
XFCE_EOF

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-terminal.xml" <<'XFCE_EOF'
<?xml version="1.1" encoding="UTF-8"?>

<channel name="xfce4-terminal" version="1.0">
  <property name="background-darkness" type="double" value="0.90000000000000002"/>
  <property name="color-foreground" type="string" value="#0000ffff0000"/>
  <property name="misc-always-show-tabs" type="bool" value="false"/>
  <property name="misc-bell" type="bool" value="false"/>
  <property name="misc-bell-urgent" type="bool" value="false"/>
  <property name="misc-borders-default" type="bool" value="true"/>
  <property name="misc-cursor-blinks" type="bool" value="false"/>
  <property name="misc-cursor-shape" type="string" value="TERMINAL_CURSOR_SHAPE_UNDERLINE"/>
  <property name="misc-default-geometry" type="string" value="80x24"/>
  <property name="misc-inherit-geometry" type="bool" value="false"/>
  <property name="misc-menubar-default" type="bool" value="false"/>
  <property name="misc-mouse-autohide" type="bool" value="false"/>
  <property name="misc-mouse-wheel-zoom" type="bool" value="true"/>
  <property name="misc-toolbar-default" type="bool" value="false"/>
  <property name="misc-confirm-close" type="bool" value="true"/>
  <property name="misc-cycle-tabs" type="bool" value="true"/>
  <property name="misc-tab-close-buttons" type="bool" value="true"/>
  <property name="misc-tab-close-middle-click" type="bool" value="false"/>
  <property name="misc-tab-position" type="string" value="GTK_POS_TOP"/>
  <property name="misc-highlight-urls" type="bool" value="true"/>
  <property name="misc-middle-click-opens-uri" type="bool" value="false"/>
  <property name="misc-copy-on-select" type="bool" value="false"/>
  <property name="misc-show-relaunch-dialog" type="bool" value="true"/>
  <property name="misc-rewrap-on-resize" type="bool" value="true"/>
  <property name="misc-slim-tabs" type="bool" value="false"/>
  <property name="misc-new-tab-adjacent" type="bool" value="false"/>
  <property name="misc-search-dialog-opacity" type="uint" value="100"/>
  <property name="misc-show-unsafe-paste-dialog" type="bool" value="false"/>
  <property name="scrolling-unlimited" type="bool" value="true"/>
  <property name="title-mode" type="string" value="TERMINAL_TITLE_REPLACE"/>
</channel>
XFCE_EOF

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/keyboards.xml" <<'XFCE_EOF'
<?xml version="1.1" encoding="UTF-8"?>

<channel name="keyboards" version="1.0">
  <property name="Default" type="empty">
    <property name="Numlock" type="bool" value="true"/>
  </property>
</channel>
XFCE_EOF

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" <<'XFCE_EOF'
<?xml version="1.1" encoding="UTF-8"?>

<channel name="thunar" version="1.0">
  <property name="last-view" type="string" value="ThunarIconView"/>
  <property name="last-icon-view-zoom-level" type="string" value="THUNAR_ZOOM_LEVEL_100_PERCENT"/>
  <property name="last-window-width" type="int" value="1150"/>
  <property name="last-window-height" type="int" value="621"/>
  <property name="last-window-maximized" type="bool" value="false"/>
  <property name="last-separator-position" type="int" value="170"/>
</channel>
XFCE_EOF

put "$HOME/.config/xfce4/terminal/terminalrc" <<'XFCE_EOF'
[Configuration]
BackgroundDarkness=0.900000
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBellUrgent=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_UNDERLINE
MiscDefaultGeometry=80x24
MiscInheritGeometry=FALSE
MiscMenubarDefault=FALSE
MiscMouseAutohide=FALSE
MiscMouseWheelZoom=TRUE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=FALSE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscMiddleClickOpensUri=FALSE
MiscCopyOnSelect=FALSE
MiscShowRelaunchDialog=TRUE
MiscRewrapOnResize=TRUE
MiscUseShiftArrowsToScroll=FALSE
MiscSlimTabs=FALSE
MiscNewTabAdjacent=FALSE
MiscSearchDialogOpacity=100
MiscShowUnsafePasteDialog=FALSE
ColorForeground=#0000ffff0000
ScrollingUnlimited=TRUE
TitleMode=TERMINAL_TITLE_REPLACE

XFCE_EOF

put "$HOME/.config/Thunar/uca.xml" <<'XFCE_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
	<icon>utilities-terminal</icon>
	<name>Open Terminal Here</name>
	<submenu></submenu>
	<unique-id>1794566355091254-1</unique-id>
	<command>exo-open --working-directory %f --launch TerminalEmulator</command>
	<description>Example for a custom action</description>
	<range></range>
	<patterns>*</patterns>
	<startup-notify/>
	<directories/>
</action>
</actions>
XFCE_EOF

put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/thunar-volman.xml" <<'XFCE_EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="thunar-volman" version="1.0">
  <property name="automount-drives" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="automount-media" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="autobrowse" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="autoopen" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
XFCE_EOF

  # ---- panel: your left side + the Mint right side (tray, bell, xapp, power, volume, clock)
  has_plugin() { [ -e "/usr/share/xfce4/panel/plugins/$1.desktop" ]; }
  local ids="1 2 3 6" extra="" id idxml=""
  has_plugin notification-plugin  && { ids="$ids 9";  extra="$extra
    <property name=\"plugin-9\" type=\"string\" value=\"notification-plugin\"/>"; }
  has_plugin xapp-status-plugin   && { ids="$ids 10"; extra="$extra
    <property name=\"plugin-10\" type=\"string\" value=\"xapp-status-plugin\"/>"; }
  has_plugin power-manager-plugin && { ids="$ids 11"; extra="$extra
    <property name=\"plugin-11\" type=\"string\" value=\"power-manager-plugin\"/>"; }
  has_plugin pulseaudio           && { ids="$ids 12"; extra="$extra
    <property name=\"plugin-12\" type=\"string\" value=\"pulseaudio\">
      <property name=\"enable-keyboard-shortcuts\" type=\"bool\" value=\"true\"/>
      <property name=\"enable-mpris\" type=\"bool\" value=\"true\"/>
      <property name=\"mixer-command\" type=\"string\" value=\"pavucontrol\"/>
      <property name=\"show-notifications\" type=\"bool\" value=\"false\"/>
    </property>"; }
  ids="$ids 13"
  for id in $ids; do idxml="$idxml
        <value type=\"int\" value=\"$id\"/>"; done
  put "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" <<PANEL_EOF
<?xml version="1.1" encoding="UTF-8"?>

<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="true"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=960;y=1066"/>
      <property name="length" type="double" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="icon-size" type="uint" value="32"/>
      <property name="size" type="uint" value="35"/>
      <property name="plugin-ids" type="array">$idxml
      </property>
      <property name="mode" type="uint" value="0"/>
      <property name="background-style" type="uint" value="2"/>
      <property name="background-image" type="string" value=""/>
      <property name="background-alpha" type="int" value="100"/>
      <property name="background-color" type="array">
        <value type="uint" value="56540"/>
        <value type="uint" value="56026"/>
        <value type="uint" value="54741"/>
        <value type="uint" value="65535"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu">
      <property name="button-single-row" type="bool" value="true"/>
      <property name="recent-items-max" type="int" value="10"/>
      <property name="launcher-icon-size" type="int" value="2"/>
      <property name="category-icon-size" type="int" value="2"/>
      <property name="button-icon" type="string" value="emblem-parrot"/>
      <property name="recent" type="array">
        <value type="string" value="brave-origin-nightly.desktop"/>
        <value type="string" value="xfce4-taskmanager.desktop"/>
        <value type="string" value="xfce-backdrop-settings.desktop"/>
        <value type="string" value="Xfce-Theme-Manager.desktop"/>
        <value type="string" value="xfce4-terminal-emulator.desktop"/>
        <value type="string" value="firefox-selector.desktop"/>
      </property>
    </property>
    <property name="plugin-2" type="string" value="docklike"/>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-6" type="string" value="systray">
      <property name="icon-size" type="int" value="0"/>
      <property name="show-frame" type="bool" value="false"/>
      <property name="square-icons" type="bool" value="false"/>
    </property>$extra
    <property name="plugin-13" type="string" value="clock">
      <property name="mode" type="uint" value="2"/>
      <property name="digital-layout" type="uint" value="1"/>
      <property name="digital-time-format" type="string" value="%H:%M"/>
      <property name="digital-time-font" type="string" value="Sans Bold 8"/>
      <property name="digital-date-font" type="string" value="Sans 8"/>
    </property>
  </property>
</channel>
PANEL_EOF

  # ---- helpers.rc: default apps
  { echo "FileManager=Thunar"; echo "TerminalEmulator=xfce4-terminal"
    command -v brave-origin-nightly >/dev/null && echo "WebBrowser=brave-origin-nightly"; } > "$HOME/.config/xfce4/helpers.rc"

  # ---- Docklike pins (panel plugin id 2): terminal, Brave if present, else Firefox
  local pins="xfce4-terminal;"
  if command -v brave-origin-nightly >/dev/null; then pins="${pins}com.brave.Origin.nightly;"
  elif [ -f /usr/share/applications/firefox-esr.desktop ]; then pins="${pins}firefox-esr;"
  elif [ -f /usr/share/applications/firefox.desktop ]; then pins="${pins}firefox;"; fi
  put "$HOME/.config/xfce4/panel/docklike-2.rc" <<EOF
[user]
pinned=$pins
forceIconSize=true
iconSize=32
EOF

  # ---- fall back gracefully when a theme from your Parrot setup is missing
  local X="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
  has_theme()  { [ -d "/usr/share/themes/$1" ] || [ -d "$HOME/.themes/$1" ] || [ -d "$HOME/.local/share/themes/$1" ]; }
  has_icons()  { [ -d "/usr/share/icons/$1" ]  || [ -d "$HOME/.icons/$1" ]  || [ -d "$HOME/.local/share/icons/$1" ]; }
  has_xfwm()   { [ -d "/usr/share/themes/$1/xfwm4" ] || [ -d "$HOME/.themes/$1/xfwm4" ] || [ -d "$HOME/.local/share/themes/$1/xfwm4" ]; }
  setval()     { sed -i "s|\(name=\"$2\" type=\"string\" value=\"\)[^\"]*|\1$3|" "$X/$1"; }

  has_theme "Windows 10 Dark" || { echo "  theme 'Windows 10 Dark' not found -> Arc-Dark"; setval xsettings.xml ThemeName Arc-Dark; }
  if ! has_icons "htb-icon-theme"; then
    if has_icons "Hack-The-Box-Icons"; then setval xsettings.xml IconThemeName Hack-The-Box-Icons
    else echo "  HTB icons not found -> Papirus-Dark"; setval xsettings.xml IconThemeName Papirus-Dark; fi
  fi
  has_icons "DMZ-Black"       || setval xsettings.xml CursorThemeName Adwaita
  if ! has_xfwm "Yaru-dark"; then
    if has_xfwm "Arc-Dark"; then setval xfwm4.xml theme Arc-Dark; else setval xfwm4.xml theme Default; fi
  fi
  # window snapping behaviour copied from Mint
  setbool()    { sed -i "s|\(name=\"$2\" type=\"bool\" value=\"\)[^\"]*|\1$3|" "$X/$1"; }
  setbool xfwm4.xml snap_to_border true
  setbool xfwm4.xml snap_to_windows true
  setbool xfwm4.xml tile_on_move true
  setbool xfwm4.xml snap_resist false
  # Peppermint-style transparency + shadows
  setint()     { sed -i "s|\(name=\"$2\" type=\"int\" value=\"\)[^\"]*|\1$3|" "$X/$1"; }
  setbool xfwm4.xml use_compositing true
  setbool xfwm4.xml unredirect_overlays true
  setbool xfwm4.xml show_dock_shadow false
  setbool xfwm4.xml show_frame_shadow true
  setbool xfwm4.xml show_popup_shadow true
  setbool xfwm4.xml zoom_desktop true
  setint xfwm4.xml frame_opacity 100
  setint xfwm4.xml inactive_opacity 83
  setint xfwm4.xml move_opacity 83
  setint xfwm4.xml resize_opacity 83
  setint xfwm4.xml popup_opacity 100
  setint xfwm4.xml shadow_opacity 50
  setint xfwm4.xml shadow_delta_y -3
  # whisker menu button icon: Parrot logo only if that icon exists
  local logo
  logo=$(find /usr/share/icons/desktop-base /usr/share/pixmaps "$HOME/.icons" -name 'emblem-parrot*.png' 2>/dev/null | sort -t/ -k1,1 | grep -m1 '64x64' || true)
  [ -z "$logo" ] && logo=$(find /usr/share/icons /usr/share/pixmaps "$HOME/.icons" -name 'emblem-parrot*' -print -quit 2>/dev/null)
  if [ -n "$logo" ]; then
    sed -i "s|value=\"emblem-parrot\"|value=\"$logo\"|" "$X/xfce4-panel.xml"
  else
    sed -i 's|value="emblem-parrot"|value="start-here"|' "$X/xfce4-panel.xml"
  fi
}

# ------------------------------------------------------------- apply live
apply_live() {
  if [ "$LIVE" = "1" ]; then
    echo "== restarting panel/window manager =="
    setsid xfce4-panel >/dev/null 2>&1 &
    setsid xfwm4 --replace >/dev/null 2>&1 &
    pkill -x xfsettingsd 2>/dev/null; setsid xfsettingsd >/dev/null 2>&1 &
    xfdesktop --reload >/dev/null 2>&1 || true
    # make sure the Windows-style snap keys are active right now, not only after the next login
    sleep 2
    if command -v xfconf-query >/dev/null; then
      for kv in "Left:tile_left_key" "Right:tile_right_key" "Up:maximize_window_key" "Down:hide_window_key"; do
        xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>${kv%%:*}" -n -t string -s "${kv#*:}" 2>/dev/null
      done
    fi
  fi
}

# ------------------------------------------------------------ bash prompt
setup_prompt() {
  local rc="$HOME/.bashrc"
  [ -f "$rc" ] || touch "$rc"
  # remove an older copy of this block, then append the current one (safe to re-run)
  sed -i '/^# >>> parrot-prompt >>>$/,/^# <<< parrot-prompt <<<$/d' "$rc"
  cat >> "$rc" <<'PROMPT_EOF'
# >>> parrot-prompt >>>
case "$TERM" in
xterm*|rxvt*|screen*|tmux*)
    PS1="\[\033[0;31m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;37m\]\342\234\227\[\033[0;31m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[01;31m\]root\[\033[01;33m\]@\[\033[01;96m\]\h'; else echo '\[\033[0;39m\]\u\[\033[01;33m\]@\[\033[01;96m\]\h'; fi)\[\033[0;31m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;31m\]]\n\[\033[0;31m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]\[\e[01;33m\]\\$\[\e[0m\]"
    ;;
esac
# <<< parrot-prompt <<<
PROMPT_EOF
  echo "== bash prompt added to ~/.bashrc (open a new terminal to see it) =="
}

# --------------------------------------------------------------------- run
[ "${SKIP_INSTALL:-0}" = "1" ] || install_all

# stop the panel and settings daemon BEFORE writing, so they cannot overwrite our files
LIVE=0
if [ -n "${DISPLAY:-}" ] && pgrep -x xfce4-panel >/dev/null; then
  LIVE=1; xfce4-panel --quit 2>/dev/null; pkill -x xfconfd 2>/dev/null; sleep 1
fi
extract_look
write_settings
setup_prompt
apply_live

echo
echo "Done. Log out and back in (or reboot) once so the theme and shortcuts load fully."
