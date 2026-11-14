#!/usr/bin/env bash
# default-apps.sh - installs my everyday apps and sets them as defaults.
# Debian/Ubuntu-based distros. Run as a NORMAL user (not root).
# Apps: Brave, Tabby (+ my config, highlight plugin), Nomacs (+ my settings),
#       FileZilla, BleachBit, LocalSend, speedtest-cli, netdiscover
set -u

[ "$(id -u)" -eq 0 ] && { echo "Run this as your normal user, not root."; exit 1; }
command -v apt-get >/dev/null || { echo "This script needs a Debian/Ubuntu-based system."; exit 1; }

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  TABBY_ARCH=x64;   LS_ARCH=x86-64 ;;
  aarch64) TABBY_ARCH=arm64; LS_ARCH=arm-64 ;;
  *) TABBY_ARCH=x64; LS_ARCH=x86-64 ;;
esac

# latest .deb of a GitHub project: $1=owner/repo $2=file regex $3=file name template (%s = version)
gh_deb_url() {
  local url tag
  url=$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null | grep -o "https://[^\"]*$2" | head -1)
  if [ -z "$url" ]; then
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" 2>/dev/null | sed 's|.*/tag/||')
    [ -n "$tag" ] && url="https://github.com/$1/releases/download/$tag/$(printf "$3" "${tag#v}")"
  fi
  echo "$url"
}

install_deb() {  # $1=name  $2=dpkg package  $3=owner/repo  $4=regex  $5=template
  if dpkg -s "$2" >/dev/null 2>&1; then echo "  $1 already installed, skipping"; return; fi
  local url; url=$(gh_deb_url "$3" "$4" "$5")
  if [ -z "$url" ]; then echo "  $1: could not find the download, get it from https://github.com/$3/releases/latest"; return; fi
  curl -fL --retry 5 --retry-delay 3 -C - -o "/tmp/$2.deb" "$url" && sudo apt-get install -y "/tmp/$2.deb" \
    || echo "  $1 install failed, skipping"
  rm -f "/tmp/$2.deb"
}

# ---------------------------------------------------------------- install
install_all() {
  echo "== apt update =="
  sudo apt-get update
  local want="curl ca-certificates nomacs speedtest-cli filezilla bleachbit netdiscover" ok="" p
  for p in $want; do
    [ -n "$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/ && $2!="(none)"')" ] && ok="$ok $p" \
      || echo "  (skipping $p: not in repos)"
  done
  echo "== install apt packages =="
  sudo apt-get install -y $ok

  echo "== Brave Origin (nightly) =="
  if command -v brave-origin-nightly >/dev/null || command -v brave-browser >/dev/null; then
    echo "  Brave already installed, skipping"
  else
    curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin CHANNEL=nightly sh || echo "  Brave install failed, skipping"
  fi

  echo "== Tabby =="
  install_deb Tabby tabby-terminal Eugeny/tabby "tabby-[^\"/]*-linux-$TABBY_ARCH\\.deb" "tabby-%s-linux-$TABBY_ARCH.deb"
  echo "== LocalSend =="
  install_deb LocalSend localsend localsend/localsend "LocalSend-[^\"/]*-linux-$LS_ARCH\\.deb" "LocalSend-%s-linux-$LS_ARCH.deb"
}

# ---------------------------------------------------------------- settings
write_tabby() {
  echo "== Tabby config + highlight plugin =="
  local d="$HOME/.config/tabby"
  mkdir -p "$d/plugins/node_modules"
  if [ -f "$d/config.yaml" ] && [ ! -e "$d/config.yaml.bak-setup" ]; then cp -a "$d/config.yaml" "$d/config.yaml.bak-setup"; fi
  cat > "$d/config.yaml" <<'TABBY_CFG_EOF'
version: 8
profiles: []
groups: []
configSync:
  parts: {}
hotkeys:
  toggle-window:
    - Ctrl-Shift-Space
  copy-current-path: []
  debug-save-state:
    - Ctrl-Shift-Alt-1
  debug-load-state:
    - Ctrl-Shift-Alt-2
  debug-copy-state:
    - Ctrl-Shift-Alt-3
  debug-paste-state:
    - Ctrl-Shift-Alt-4
  debug-save-output:
    - Ctrl-Shift-Alt-5
  debug-load-output:
    - Ctrl-Shift-Alt-6
  debug-copy-output:
    - Ctrl-Shift-Alt-7
  debug-paste-output:
    - Ctrl-Shift-Alt-8
  ctrl-c:
    - Ctrl-C
  copy:
    - Ctrl-Shift-C
  paste:
    - Ctrl-Shift-V
    - Shift-Insert
  select-all:
    - Ctrl-Shift-A
  clear: []
  zoom-in:
    - Ctrl-=
    - Ctrl-Shift-=
  zoom-out:
    - Ctrl--
    - Ctrl-Shift--
  reset-zoom:
    - Ctrl-0
  home:
    - Home
  end:
    - End
  previous-word:
    - Ctrl-Left
  next-word:
    - Ctrl-Right
  delete-previous-word:
    - Ctrl-Backspace
  delete-line:
    - Ctrl-Shift-Backspace
  delete-next-word:
    - Ctrl-Delete
  search:
    - Ctrl-Shift-F
  pane-focus-all:
    - Ctrl-Shift-I
  focus-all-tabs:
    - Ctrl-Alt-Shift-I
  insert-new-line:
    - Alt-Shift-Enter
  scroll-to-top:
    - Ctrl-PageUp
  scroll-page-up:
    - Alt-PageUp
  scroll-up:
    - Ctrl-Shift-Up
  scroll-down:
    - Ctrl-Shift-Down
  scroll-page-down:
    - Alt-PageDown
  scroll-to-bottom:
    - Ctrl-PageDown
  restart-telnet-session: []
  restart-ssh-session: []
  launch-winscp: []
  open-sftp: []
  settings-tab: {}
  settings:
    - Ctrl-,
  serial:
    - Alt-K
  restart-serial-session: []
  new-tab:
    - Ctrl-T
  new-window:
    - Ctrl-Shift-N
  profile: {}
  profile-selectors: {}
  group-selectors: {}
  toggle-fullscreen:
    - F11
    - Alt-Enter
  close-tab:
    - Ctrl-Q
  reopen-tab:
    - Ctrl-Shift-Z
  toggle-last-tab: []
  rename-tab:
    - Ctrl-Shift-R
  next-tab:
    - Ctrl-Shift-Right
    - Ctrl-Tab
  previous-tab:
    - Ctrl-Shift-Left
    - Ctrl-Shift-Tab
  next-mru-tab: []
  previous-mru-tab: []
  move-tab-left:
    - Ctrl-Shift-PageUp
  move-tab-right:
    - Ctrl-Shift-PageDown
  rearrange-panes:
    - Ctrl-Shift
  duplicate-tab: []
  pin-tab: []
  restart-tab: []
  reconnect-tab: []
  disconnect-tab: []
  explode-tab:
    - Ctrl-Shift-.
  combine-tabs:
    - Ctrl-Shift-,
  tab-1:
    - Alt-1
  tab-2:
    - Alt-2
  tab-3:
    - Alt-3
  tab-4:
    - Alt-4
  tab-5:
    - Alt-5
  tab-6:
    - Alt-6
  tab-7:
    - Alt-7
  tab-8:
    - Alt-8
  tab-9:
    - Alt-9
  tab-10:
    - Alt-0
  tab-11: []
  tab-12: []
  tab-13: []
  tab-14: []
  tab-15: []
  tab-16: []
  tab-17: []
  tab-18: []
  tab-19: []
  tab-20: []
  split-right:
    - Ctrl-Shift-S
  split-bottom:
    - Ctrl-Shift-D
  split-left: []
  split-top: []
  pane-nav-right:
    - Ctrl-Alt-Right
  pane-nav-down:
    - Ctrl-Alt-Down
  pane-nav-up:
    - Ctrl-Alt-Up
  pane-nav-left:
    - Ctrl-Alt-Left
  pane-nav-previous:
    - Ctrl-Alt-[
  pane-nav-next:
    - Ctrl-Alt-]
  pane-nav-1: []
  pane-nav-2: []
  pane-nav-3: []
  pane-nav-4: []
  pane-nav-5: []
  pane-nav-6: []
  pane-nav-7: []
  pane-nav-8: []
  pane-nav-9: []
  pane-maximize:
    - Ctrl-Alt-Enter
  close-pane: []
  pane-increase-vertical: []
  pane-decrease-vertical: []
  pane-increase-horizontal: []
  pane-decrease-horizontal: []
  switch-profile:
    - Ctrl-Alt-T
  profile-selector:
    - Ctrl-Shift-E
  command-selector:
    - Ctrl-Shift-P
terminal:
  searchOptions: {}
  colorScheme:
    name: Tabby Default
    foreground: '#cacaca'
    background: '#171717'
    cursor: '#bbbbbb'
    colors:
      - '#000000'
      - '#ff615a'
      - '#b1e969'
      - '#ebd99c'
      - '#5da9f6'
      - '#e86aff'
      - '#82fff7'
      - '#dedacf'
      - '#313131'
      - '#f58c80'
      - '#ddf88f'
      - '#eee5b2'
      - '#a5c7ff'
      - '#ddaaff'
      - '#b7fff9'
      - '#ffffff'
  customColorSchemes: []
ssh: {}
clickableLinks: {}
accessibility: {}
appearance: {}
hacks: {}
providerBlacklist: []
commandBlacklist: []
profileBlacklist: []
enableAnalytics: false
language: en-US
enableWelcomeTab: false
pluginBlacklist: []
profileDefaults:
  ssh:
    disableDynamicTitle: true
highlightPlugin:
  advanced: {}
  highlightProfiles:
    - id: 71a1d903-ae45-44cd-a7ae-ed59c46a554a
      name: Junos MEGA v2
      keywords:
        - text: (?<=^|[\r\n])\s*\^\s*(?=[\r\n]|$)
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#f7768e'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:syntax error|unknown command|missing argument|invalid
            (?:value|interface|ip
            address|prefix|argument)|error|failed|failure|not found|access
            denied|permission denied|denied|refused|unreachable|no route to
            host|connection reset|timed out|access has been
            revoked|undefined|does not exist|is not valid|no such file or
            directory|commit failed|check-out failed)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#f7768e'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:[1-9]\d?(?:\.\d+)?|100)% packet loss
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#f7768e'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=^|[\r\n])\+[ \t][^\r\n]*
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#98c379'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=^|[\r\n])-[ \t][^\r\n]*
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#e06c75'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: '#{1,2} ?Warning:[^\r\n]*'
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#e0af68'
          bold: false
          italic: true
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:warning|deprecated|uncommitted|not committed|will be
            discarded|statement not found|automatically rolled back|rolled
            back|unless confirmed|amnesiac|configuration database locked|users
            currently editing|major alarm|minor alarm|pending
            activation|rollback in \d+ ?mins?|is protected|missing mandatory
            statement\(s\)|not supported|ignored|obsolete|reboot required|reboot
            is required)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#e0af68'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \[yes,no\]|---\(more[^)]*\)---
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#e0af68'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: '(?:!\s*)?\b(?:inactive|protect):'
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#e0af68'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:Init|2Way|ExStart|Exchange|Loading|Attempt|OpenSent|OpenConfirm|Connect)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#e0af68'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:Major|Critical|Fatal|Emergency)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#f7768e'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:Minor|Shutdown NOW!?|Rebooting|going down)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#e0af68'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:commit complete|configuration check succeeds|load
            complete|entering configuration mode|exiting configuration
            mode|successfully committed|commit (?:activated|prepared)|no
            changes)\b|\b0% packet loss
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#9ece6a'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=\d:\d{2} +)(?:Active|Connect|Idle)\b(?=\s*$)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#e0af68'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?<=^|[\r\n])[ \t]*(?:[A-Z][\w/%().#-]*(?:
            [A-Za-z][\w/%().#-]*){0,2}(?=([ \t]{2,}))\1){2,}[A-Z][\w/%().#-]*(?:
            [A-Za-z][\w/%().#-]*){0,2}(?=[ \t]*(?:[\r\n]|$))
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#8fa6d9'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:down|dn|disabled|offline|absent|idle|fail|blocking|discarding)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#f7768e'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:up|full|established|online|present|forwarding|ok|running|enabled|unblocked|active|established)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#9ece6a'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:FWD|Establ|Established|Operational|BOUND|Collecting
            distributing|Master|MASTER|Online|Valid|Connected|Synced|Installed|Primary)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#9ece6a'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:BLK|DIS|BKN|Blocked|Detached|Defaulted|Expired|Nonexistent|AdminDown|Empty|Failed|FAILED|Error|Errored|Invalid|Unreachable|Rejected|Missing|Unknown)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#f7768e'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:LRN|LRNG|Learning|Listening|Initializing|Testing|Check|Pending|SELECTING|REQUESTING|RENEWING|REBINDING|Waiting|Wait|Transition|Negotiating|Degraded|Standby|Syncing|Ready)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#e0af68'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:ROOT|DESG|ALT|BKUP|DISA|MSTR|Root|Desg|Alt|Bkup|DR|BDR|DRother|PtToPt|DROther|Backup|backup|master|init|IS-IS|L1|L2)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#89ddff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \*\s+\*\s+\*|!(?:H|N|P|X|F|S)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#f7768e'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: '\b\d+ degrees C(?: / \d+ degrees F)?\b'
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#e0af68'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=^|[\r\n])[\w.-]+@[\w.:~-]*\s?[>#%](?=\s|$)
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#61afef'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=^|[\r\n])\[edit[^\]\r\n]*\]
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#7aa2f7'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \{(?:master|backup|primary|secondary|linecard|local_node)[^}\r\n]*\}
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#7aa2f7'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?:(?<=[>#%] )|(?<=--
            ))(?:show|request|clear|monitor|ping|traceroute|mtrace|file|restart|configure|commit|set|delete|edit|load|rollback|run|start|test|op|help|quit|exit|up|top|save|copy|insert|rename|annotate|activate|deactivate|replace|wildcard|status|telnet|ssh|ftp|scp|compare)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#bb9af7'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?<=\b(?:show|clear|monitor|request|restart|file|test|ping|traceroute)
            )(?:[a-z][\w-]*)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#c099ff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \|\s*(?:match|except|count|last|display(?:
            (?:set|xml|json|inheritance|detail|omit|commit-scripts|changed|rfc5952))?|find|no-more|save|compare|trim|hold|resolve|refresh|request|append|tee)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#89ddff'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?<=\s)(?:detail|extensive|terse|brief|summary|statistics|descriptions|media|exact|protocol|table|neighbor|interface|instance|logical-system|member|all-members|local|no-forwarding|no-resolve|rapid|count|size|source|routing-instance)\b(?=[^\r\n]*$)(?<=(?:[>#%]
            |-- )[^\r\n]*)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#9aa0e6'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \*(?=\[)|>\s?(?=to |via )
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#9ece6a'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \[(?:Direct|Local|Static|OSPF3?|BGP|IS-IS|RIP(?:ng)?|Aggregate|Access(?:-internal)?|LDP|RSVP|PIM|MPLS|Generate|L2VPN|EVPN|Kernel|Bridge)/\d+(?:/-?\d+)?\]
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#ff9ecb'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:inet6?|mpls|iso|inetflow|l2circuit|bgp\.\w+|[\w-]+\.inet6?)\.\d+\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#7aa2f7'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#d19a66'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:rpd|mgd|dcd|chassisd|snmpd|ppmd|sshd|l2ald|l2cpd|eswd|dhcpd|jdhcpd|mib2d|kernel|cosd|dfwd|lacpd|lldpd|vrrpd|bfdd|ntpd|xntpd|inetd|eventd|mcsnoopd|pfed|alarmd|craftd|rmopd|cli|login)(?=\[\d+\]|:)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#bb9af7'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:fxp\d|em0|me\d|vme|re\d:mgmt-\d)(?:\.(?:\d+|\*))?(?![\w-])
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#ff9e64'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \bge-\d+/\d+/(?:\d+|\*|\[[^\]]*\])(?::\d+)?(?:\.(?:\d+|\*))?
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#7fb4ca'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \bxe-\d+/\d+/(?:\d+|\*|\[[^\]]*\])(?::\d+)?(?:\.(?:\d+|\*))?
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#82aaff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:et|mge)-\d+/\d+/(?:\d+|\*|\[[^\]]*\])(?::\d+)?(?:\.(?:\d+|\*))?
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#a9a1e1'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \bfe-\d+/\d+/(?:\d+|\*|\[[^\]]*\])(?::\d+)?(?:\.(?:\d+|\*))?
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#8fbcbb'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:ae|reth)\d+(?:\.(?:\d+|\*))?(?![\w-])
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#73daca'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \bvlan\.\d+\b|\b(?:irb|lo\d)(?:\.(?:\d+|\*))?(?![\w-])
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#b4f9f8'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:lc|pfe|pfh|sxe|gr|lt|ip|st|vcp|vt|pd|pe)-\d+/\d+/(?:\d+|\*|\[[^\]]*\])(?::\d+)?(?:\.(?:\d+|\*))?|\b(?:em[1-9]|cbp\d|demux\d|dsc|esi|fti\d|gre|ipip|jsrv|lsi|mif|mtun|pimd|pime|pip\d|pp\d|rbeb|tap|vtep|bme\d)(?:\.(?:\d+|\*))?(?![\w-])
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=interface-range )[\w-]+
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#7fb4ca'
          bold: false
          italic: true
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b[0-9a-fA-F]{2}(?:[:-][0-9a-fA-F]{2}){5}\b|\b[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\.[0-9a-fA-F]{4}\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#c8a97e'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?:\b[0-9a-fA-F]{1,4}:)(?:[0-9a-fA-F]{1,4}:)*:[0-9a-fA-F:]*(?:/\d{1,3})?|(?<![\w:])::(?:[0-9a-fA-F]{1,4}(?::[0-9a-fA-F]{1,4})*)?/\d{1,3}|\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}(?:/\d{1,3})?\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#ecc48d'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}(?:/\d{1,2})?\b|\b0/0\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#e5c890'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:EX|QFX|MX|SRX|PTX|ACX|NFX|vMX|vSRX|vQFX|vEX|VM-VMX|VM-VEX|vJunos(?:-router|-switch|Evolved)?|ex|qfx|mx|srx|vmx|vsrx)[-\w]*\d[\w-]*|\bvJunos(?:-router|-switch)?\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#a9b665'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:Routing Engine|Midplane|Power Supply|Fan
            Tray|PEM|PSU|FPC|PIC|MIC|Xcvr|SCB|SIB|FEB|CB|RE|PFE|Chassis|CPU|DIMM|Module|Uplink
            module|Virtual Chassis|VC|Fan)(?: \d+)?\b(?!:)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#a9b665'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:SFP\+?|SFP28|QSFP\+?|QSFP28|QSFP-DD|XFP|CFP\d?|DAC|AOC)(?:-[\w+-]+)?|\b(?:10|25|40|100|400)G?BASE-[A-Z0-9]+\b|\b1000BASE-[A-Z0-9]+\b|\b10GBASE-[A-Z0-9]+\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#a9b665'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b\d{3}-\d{6}\b|\bREV \d+\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=^|[\r\n])[-dlrwxs]{10}(?= )
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:In|Out)(?= IP6? )|\b(?:echo request|echo reply|Flags
            \[[^\]]*\])
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#89ddff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) +\d{1,2}\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b\d{4}-\d{2}-\d{2}\b|\b\d{1,2}:\d{2}:\d{2}(?:\.\d+)?\b|\b\d+w\d+d(?:
            \d+:\d{2}(?::\d{2})?)?\b|\b\d+d \d+:\d{2}(?::\d{2})?\b|\bago\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:[A-Z]{2}[DS]T|CEST|CET|UTC|GMT)\b|\b(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?<=^|[\r\n])(?:set|delete|deactivate|activate|insert|rename|replace|annotate|edit|protect|unprotect)(?=
            )
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#bb9af7'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:system|interfaces|protocols|routing-options|policy-options|firewall|vlans|chassis|security|snmp|class-of-service|routing-instances|groups|forwarding-options|services|event-options|apply-groups|version|multi-chassis|virtual-chassis|poe|ethernet-switching-options|switch-options|bridge-domains)\b(?:(?<=^\s*(?:set|delete|deactivate|activate|edit|insert|rename|annotate|protect|unprotect)
            [^\r\n]*)|(?=[^\r\n]*[;{]\s*$))
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#c099ff'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:ospf3?|bgp|isis|rip(?:ng)?|lldp(?:-med)?|rstp|stp|mstp|vstp|mpls|ldp|rsvp|pim|igmp(?:-snooping)?|mld|vrrp|bfd|lacp|dhcp(?:v6)?|dhcp-relay|arp|ndp|icmp6?|ntp|snmp|ssh|telnet|netconf|ftp|http|https|tftp|radius|tacplus|syslog|router-advertisement|evpn|vxlan|static)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#ff9ecb'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:super-user|operator|read-only|unauthorized)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#ff9e64'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:accept|permit|allow)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#9ece6a'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:reject|discard|deny|drop)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#f7768e'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:family|inet6?|ethernet-switching|unit|address|description|vlan-id|vlan-tagging|stacked-vlan-tagging|flexible-vlan-tagging|vlan|members|interface-mode|port-mode|trunk|access|native-vlan-id|l3-interface|interface|interface-range|member-range|member|area|passive|metric|route|next-hop|rib|host-name|root-authentication|login|user|class|authentication|plain-text-password|encrypted-password|web-management|name-server|server|boot-server|time-zone|file|any|notice|info|authorization|interactive-commands|messages|mtu|disable|speed|link-mode|filter|input|output|term|from|then|policy-statement|export|import|prefix-list|community|neighbor|peer-as|local-as|type|internal|external|gigether-options|ether-options|message|announcement|uid|root-login|allow|traceoptions|flag|level|size|commit|synchronize|factory-settings|auto-image-upgrade|management-instance|dhcp-service|processes|aging-timer|consistency-check|managed-configuration|all|to)\b(?:(?<=^\s*(?:set|delete|deactivate|activate|edit|insert|rename|annotate|protect|unprotect)
            [^\r\n]*)|(?=[^\r\n]*[;{]\s*$))
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#9aa0e6'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \$\d\$[^\s\";]+|## (?:SECRET-DATA|Last changed|Last
            commit)[^\r\n]*|/\*.*?\*/
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: true
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \"[^\"\r\n]*\"
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#c3e88d'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: '[{};]'
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:Hostname|Model|Junos|Family|Current time|Time Source|System
            booted|Protocols started|Last configured|Last
            flapped|Speed|MTU|Link-level type|Current address|Hardware
            address|Description|Flags|Input rate|Output
            rate|Destination|Broadcast|Encapsulation|Interface index|SNMP
            ifIndex|Device flags|Interface flags|Link type|Media
            type|Loopback|Source filtering|Flow control|Auto-negotiation|Remote
            fault|Input packets|Output packets|Protocol
            inet6?|Addresses|Physical interface|Logical
            interface|Enabled|Admin|Link|Proto|Local|Remote|State|Pri|Dead|ID|Tag|Interfaces|Interface|Address|Name|Routing
            instance|Vlan name|MAC address|MAC flags|Age|Local Interface|Parent
            Interface|Chassis Id|Port info|System Name|Logical
            system|Location|Output errors|Input errors)(?=:|\s{2,}|\s*$)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#8fa6d9'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:inet6?|eth-switch|vpls|tnp|mpls|iso|aenet|multiservice)\b(?=
            {2,}|\s*$)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#89ddff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b\d{2}\.\d[RSXDFBI]\d+(?:-S\d+(?:\.\d+)?)?(?:\.\d+)?\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#9ece6a'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b\d+(?:\.\d+)?\s?(?:[kKMGT]bps|[kmgt]b)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#89ddff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<=^|[\r\n])[ \t]*(?:[>+|] )?[a-z0-9][\w.:-]*(?= {2,}[A-Z(])
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#9aa0e6'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: '<\[Enter\]>|Possible completions:'
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#8fa6d9'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            (?:(?<=^[ \t]*)|(?<=, ))[A-Za-z][\w/().'#-]*(?: [\w/().'#-]+){0,4}
            ?:(?= |$)
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#8fa6d9'
          bold: true
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: </?[A-Za-z][\w:.-]*(?:\s[^>\r\n]*)?/?>
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#7f9cc9'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: (?<![\w.:/-])/(?:[A-Za-z_][\w.-]*)(?:/[\w.-]*)*
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#b5cea8'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b(?:None|none|n/a|Unspecified|Unlimited)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#6b7280'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: >-
            \b(?:tagged|untagged|access|trunk|Enabled|Disabled|Auto|Full-duplex|Half-duplex|Internal|External|Ethernet|Point-To-Point|SNMP-Traps|Keepalives)\b
          enabled: true
          isRegExp: true
          isCaseSensitive: true
          foreground: true
          foregroundColor: '#89ddff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
        - text: \b0x[0-9a-fA-F]+\b|\b\d+(?:\.\d+)?%?(?!\w)
          enabled: true
          isRegExp: true
          isCaseSensitive: false
          foreground: true
          foregroundColor: '#a6c8ff'
          bold: false
          italic: false
          underline: false
          underlineStyle: '1'
          dim: false
  replaceProfiles: []
  highlightEnabled: true
  highlightCurrentProfile: 71a1d903-ae45-44cd-a7ae-ed59c46a554a
TABBY_CFG_EOF
  # tabby-highlight plugin (from the npm registry, no npm needed)
  if [ ! -d "$d/plugins/node_modules/tabby-highlight" ]; then
    local tgz; tgz=$(curl -fsSL https://registry.npmjs.org/tabby-highlight/latest 2>/dev/null | grep -o '"tarball":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$tgz" ] && curl -fsSL -o /tmp/tabby-highlight.tgz "$tgz"; then
      mkdir -p "$d/plugins/node_modules/tabby-highlight"
      tar xzf /tmp/tabby-highlight.tgz -C "$d/plugins/node_modules/tabby-highlight" --strip-components=1
      rm -f /tmp/tabby-highlight.tgz
    else
      echo "  highlight plugin download failed (install it in Tabby: Settings > Plugins)"
    fi
  fi
}

write_nomacs() {
  echo "== Nomacs settings =="
  local d="$HOME/.config/nomacs" f="$HOME/.config/nomacs/Image Lounge.conf"
  mkdir -p "$d"
  if [ -f "$f" ] && [ ! -e "$f.bak-setup" ]; then cp -a "$f" "$f.bak-setup"; fi
  cat > "$f" <<'NOMACS_CFG_EOF'
[General]
firstTime=false

[AppSettings]
closeOnEsc=true
defaultJpgQuality=97
firstTime.nomacs.3=false
appMode=0
currentAppMode=0
showFilePreview=@Variant(\0\0\0\r\0\0\0\x6\x1)
showMetaData=@Variant(\0\0\0\r\0\0\0\x6\0)
showMenuBar=false
showEditDock=@Variant(\0\0\0\r\0\0\0\x6\0)

[DkDialog]
saveTabsDialog=false
saveTabsDialog-answer=16384
deleteFileDialog=false
deleteFileDialog-answer=16384
saveEditDialog=true
saveEditDialog-answer=65536

[DkFilePreview]
windowPosition=2

[DkMetaDataHUD]
numColumns=-1
windowPosition=3

[GlobalSettings]
sortMode=1

[zooming]
zoomLevels="0.0001,0.001,0.01,0.05,0.1,0.125,0.166,0.25,0.333,0.5,0.66,1,1.5,2,3,4,5,6,7,8,12,16,32,64,128"
useLevels=false

[DisplaySettings]
bgColorWidgetRGBA=2852126720
bgColorNoMacsRGBA=4281545523
highlightColorRGBA=4278216379
iconColorRGBA=4292730333
fontColorRGBA=4292730333
themeName312=Dark-Theme.css
fgColorNoMacsRGBA=4292730333
stylePlugin=Fusion

[SynchronizeSettings]
checkForUpdates=false
disableUpdateInteraction=true
NOMACS_CFG_EOF
}

# ---------------------------------------------------------------- defaults
find_desktop() {  # first .desktop file whose name matches $1
  ls /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications 2>/dev/null \
    | grep -i "$1" | grep '\.desktop$' | head -1
}

set_defaults() {
  echo "== default applications =="
  local d m
  d=$(find_desktop nomacs)
  if [ -n "$d" ]; then
    for m in image/png image/jpeg image/gif image/webp image/bmp image/tiff image/svg+xml image/avif image/heic image/x-icon image/vnd.microsoft.icon; do
      xdg-mime default "$d" "$m"
    done
    echo "  images -> Nomacs"
  fi
  d=$(find_desktop brave)
  if [ -n "$d" ]; then
    xdg-settings set default-web-browser "$d" 2>/dev/null
    for m in x-scheme-handler/http x-scheme-handler/https text/html; do xdg-mime default "$d" "$m"; done
    echo "  web -> Brave"
  fi
  d=$(find_desktop filezilla)
  if [ -n "$d" ]; then
    for m in x-scheme-handler/ftp x-scheme-handler/sftp; do xdg-mime default "$d" "$m"; done
    echo "  ftp/sftp links -> FileZilla"
  fi
}

install_all
write_tabby
write_nomacs
set_defaults
echo
echo "Done. Close Tabby fully and reopen it to load the new config."
