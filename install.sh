#!/usr/bin/env bash
# Installer for ProtonSteam Interceptor into the current user's environment.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_script="$repo_dir/proton-steam-interceptor.sh"

if [[ ! -f "$source_script" ]]; then
  echo "Error: proton-steam-interceptor.sh not found next to install script." >&2
  exit 1
fi

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
bin_home="${XDG_BIN_HOME:-$HOME/.local/bin}"
app_dir="$data_home/protonsteam-interceptor"
desktop_dir="$data_home/applications"
desktop_file="$desktop_dir/protonsteam-interceptor.desktop"
installed_script="$app_dir/proton-steam-interceptor.sh"
launcher="$bin_home/proton-steam-interceptor"

echo "Installing ProtonSteam Interceptor into:"
echo "  Script directory: $app_dir"
echo "  Launcher: $launcher"
echo "  Desktop entry: $desktop_file"

install -d "$app_dir" "$bin_home" "$desktop_dir"
install -m 0755 "$source_script" "$installed_script"

ln -sf "$installed_script" "$launcher"

cat >"$desktop_file" <<EOF
[Desktop Entry]
Name=ProtonSteam Interceptor
Comment=Launch Windows tools inside an existing Proton session
TryExec=$installed_script
Exec=$installed_script
Icon=steam
Terminal=false
Type=Application
Categories=Game;Utility;
Keywords=Proton;Steam;Wine;
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
fi

echo "Done. You can now launch 'ProtonSteam Interceptor' from your application menu."
