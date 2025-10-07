# ProtonSteam Interceptor

ProtonSteam Interceptor is a Zenity-based helper that lets you spawn additional Windows executables inside the exact same Proton environment used by a running Steam game. Typical use cases include trainers, debuggers, or Cheat Engine instances that must share the original game prefix, Proton build, and runtime context.

> ⚠️ Use this script responsibly. Injecting third-party tools into games may violate a game's Terms of Service, trigger anti-cheat countermeasures, or lead to account penalties. You are solely responsible for how you use it.

The author is not affiliated with Steam or Valve in any capacity.

## What It Does
- Lists your active Proton game sessions and lets you pick one via a GUI dialog.
- Launches another `.exe` through the very same Proton runtime so both processes share the `WINEPREFIX` and Steam environment variables.
- Keeps the helper detached by running the new process inside a separate session (`setsid`), while reporting its PID so you can track or terminate it.

## How It Works
- Scans `/proc` for processes owned by your UID, re-creating the environment of Proton helper processes (`SteamAppId`, `STEAM_COMPAT_DATA_PATH`, `PROTON_DIST_PATH`, etc.).
- Scores candidate processes to choose the one that actually controls the Proton session (e.g., the `waitforexitandrun` helper or the runtime slash `proton` wrapper).
- Resolves the Proton launcher path through several heuristics: `PROTON_DIST_PATH`, compatibility tool directories, `PROTON_SCRIPT`, or Steam install hints.
- Captures the exact environment block from `/proc/<pid>/environ` and reuses it unchanged when calling `proton run`, guaranteeing the injected executable behaves like it was started by Steam.
- Wraps all Zenity calls so GTK warnings (e.g., Adwaita dark-theme notices) are suppressed, keeping the UI clean even with custom GTK settings.

## Requirements
- Linux with Steam + Proton already running your target game.
- `zenity` (GTK dialog helper) and `setsid` (from `util-linux`).
- Access to `pgrep`, `env`, and standard GNU coreutils (present on most distributions).

## Installation
1. Clone or download this repository.
2. Make the script executable:
   ```bash
   chmod +x ProtonSteam_Interceptor/proton-steam-interceptor.sh
   ```
3. (Optional) Add the directory to your `PATH`, create a desktop launcher, or register it as a Steam external tool.

## Usage
1. Start your Proton game from Steam.
2. Run the helper script as your regular user:
   ```bash
   ~/ProtonSteam_Interceptor/proton-steam-interceptor.sh
   ```
3. Select the Proton session presented in the dialog (each entry shows AppID, prefix path, original command, and PID).
4. Choose the Windows executable you want to spawn; the dialog defaults to the prefix `drive_c` directory.
5. A confirmation dialog displays the new process PID so you can follow it with tools like `htop` or `ps`.

## Troubleshooting
- **No Proton instances listed**: Ensure the target game is running with Proton and that the script is executed as the same user. Steam Flatpak builds may require invoking the script from inside the sandbox.
- **“Proton Launcher Missing” dialog**: The script could not find the `proton` wrapper. Check whether you are using a nonstandard Proton path and adjust the heuristics accordingly.
- **Launch fails immediately**: Run the script from a terminal to inspect Proton's output. Some tools require `winecfg` tweaks, DLL overrides, or elevated privileges (which may not be possible inside Proton).
- **Anticheat blocks the tool**: Many games detect trainers or debuggers regardless of the launch method; no workaround is provided.

## Known Limitations
- Only scans processes owned by the invoking user; running the script as `root` will not discover regular user Proton sessions.
- Does not continuously monitor for new Proton launches—rerun the script each time you start a game.
- Assumes a conventional Proton layout (`proton` script inside the dist path). Custom packs with unusual structures may need manual adjustments.

## License
This project is distributed under the GNU General Public License v3.0. Refer to `LICENSE` for the complete terms.
