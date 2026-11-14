# xfce4-theme

One command turns a fresh Debian/Ubuntu-based install into a dark, Windows-style XFCE desktop. Made for CTF and cybersec practice.

```bash
curl -fsSL https://raw.githubusercontent.com/Badzolini/xfce4-theme/main/setup-xfce.sh | bash
```

Run it as a normal user (not root). It asks for `sudo` when needed and is safe to re-run.

## What you get

- **Desktop:** XFCE, goodies, Whisker menu, Docklike taskbar, [Xfce Theme Manager](https://github.com/KeithDHedger/Xfce-Theme-Manager)
- **Look:** Windows 10 Dark (GTK), Yaru-dark (window borders), HTB icons, DMZ-Black cursor, Cantarell font
- **Effects:** window transparency and shadows (inactive/moving/resizing windows at 83%)
- **Panel:** single bottom bar with tray, volume, power and clock
- **Shortcuts:** Linux Mint style, plus Windows-style `Super` + arrows for window snapping
- **Terminal:** xfce4-terminal in green, HTB colour scheme available, Parrot two-line bash prompt
- **Apps:** Brave Origin Nightly

## Downloads

Themes are fetched from the internet, only what is needed (about 80 MB):

| Item | Source |
|---|---|
| Windows 10 Dark | Parrot `parrot-themes` package (extracted from the .deb) |
| HTB icons (16 and 32 px) and terminal scheme | [botnetbuddies/hackthebox-themes](https://github.com/botnetbuddies/hackthebox-themes) |

If a theme can't be downloaded, the script falls back to Arc-Dark and Papirus-Dark.

## Options

```bash
SKIP_INSTALL=1 ./setup-xfce.sh      # apply settings only, skip package installs
USE_LOCAL_BUNDLE=1 ./setup-xfce.sh  # use ~/Documents/parrot-look.tar.gz instead of downloading
```

Your old config is backed up to `~/.config/xfce4.bak-setup` on the first run.

## Credits

[botnetbuddies](https://github.com/botnetbuddies/hackthebox-themes) (HTB themes, Unlicense) · [Parrot Security](https://www.parrotsec.org/) (Windows 10 Dark) · [KeithDHedger](https://github.com/KeithDHedger/Xfce-Theme-Manager) (Xfce Theme Manager)

## License

MIT for the script. Downloaded themes keep their own licenses.
