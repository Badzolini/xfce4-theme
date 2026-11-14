# xfce4-theme

One command turns a fresh Debian/Ubuntu-based install into a dark, Windows-style [XFCE](https://gitlab.xfce.org/xfce) desktop. A second one installs my everyday apps.

Run both as a normal user (not root). They ask for `sudo` when needed and are safe to re-run.

## Desktop

```bash
curl -fsSL https://raw.githubusercontent.com/Badzolini/xfce4-theme/main/setup-xfce.sh | bash
```

- **Look:** [Windows 10 Dark](https://www.parrotsec.org/) (GTK), [Yaru-dark](https://github.com/ubuntu/yaru) (window borders), [HTB icons](https://github.com/botnetbuddies/hackthebox-themes), [Cantarell](https://gitlab.gnome.org/GNOME/cantarell-fonts) font
- **Effects:** window transparency and shadows (inactive/moving/resizing windows at 83%)
- **Panel:** single bottom bar with tray, volume, power and clock
- **Shortcuts:** Linux Mint style, plus Windows-style `Super` + arrows for window snapping
- **Terminal:** xfce4-terminal in green, HTB colour scheme available, Parrot two-line bash prompt

Themes are downloaded on the fly, only what is needed (about 80 MB). If a download fails, the script falls back to Arc-Dark and Papirus-Dark.

```bash
SKIP_INSTALL=1 ./setup-xfce.sh   # apply settings only, skip package installs
```

Your old config is backed up to `~/.config/xfce4.bak-setup` on the first run.

## Apps

```bash
curl -fsSL https://raw.githubusercontent.com/Badzolini/xfce4-theme/main/default-apps.sh | bash
```

Installs the apps below (already installed ones are skipped), applies my Tabby and Nomacs settings, and sets Nomacs (images), Brave (web) and FileZilla (ftp/sftp links) as defaults.

| App | |
|---|---|
| [Brave](https://github.com/brave/brave-browser) | Browser (Origin Nightly) |
| [Tabby](https://github.com/Eugeny/tabby) | Terminal, with [tabby-highlight](https://github.com/moemoechu/tabby-highlight) plugin |
| [Nomacs](https://github.com/nomacs/nomacs) | Image viewer |
| [FileZilla](https://filezilla-project.org/) | FTP/SFTP client |
| [BleachBit](https://github.com/bleachbit/bleachbit) | System cleaner |
| [LocalSend](https://github.com/localsend/localsend) | Local file sharing |
| [speedtest-cli](https://github.com/sivel/speedtest-cli) | Speed test |
| [netdiscover](https://github.com/netdiscover-scanner/netdiscover) | Network scanner (run with `sudo`) |

## Credits

**Desktop**
- [XFCE](https://gitlab.xfce.org/xfce) and [Whisker Menu](https://gitlab.xfce.org/panel-plugins/xfce4-whiskermenu-plugin)
- [xfce4-docklike-plugin](https://gitlab.xfce.org/panel-plugins/xfce4-docklike-plugin) (taskbar)
- [Xfce Theme Manager](https://github.com/KeithDHedger/Xfce-Theme-Manager) by KeithDHedger

**Themes**
- [botnetbuddies/hackthebox-themes](https://github.com/botnetbuddies/hackthebox-themes) (HTB icons and terminal colours, Unlicense)
- [Parrot Security](https://www.parrotsec.org/) (Windows 10 Dark)
- [Yaru](https://github.com/ubuntu/yaru) (Ubuntu community)

**Apps**
- Brave, Tabby, Nomacs, FileZilla, BleachBit, LocalSend, speedtest-cli and netdiscover, linked in the table above

## License

MIT for the scripts. Downloaded themes and apps keep their own licenses.
