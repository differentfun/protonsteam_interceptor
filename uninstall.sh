#!/usr/bin/env bash
# Uninstaller for ProtonSteam Interceptor assets installed in the user environment.
set -euo pipefail

data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
bin_home="${XDG_BIN_HOME:-$HOME/.local/bin}"
app_dir="$data_home/protonsteam-interceptor"
desktop_dir="$data_home/applications"
installed_script="$app_dir/proton-steam-interceptor.sh"
launcher="$bin_home/proton-steam-interceptor"
desktop_file="$desktop_dir/protonsteam-interceptor.desktop"

echo "Uninstalling ProtonSteam Interceptor..."

removed_any=false
desktop_removed=false

if [[ -f "$installed_script" ]]; then
  rm -f "$installed_script"
  echo "Removed script: $installed_script"
  removed_any=true
fi

if [[ -L "$launcher" ]]; then
  if target=$(readlink -f "$launcher" 2>/dev/null); then
    if [[ $target == "$installed_script" ]]; then
      rm -f "$launcher"
      echo "Removed launcher symlink: $launcher"
      removed_any=true
    else
      echo "Skipped launcher (points to $target): $launcher"
    fi
  else
    rm -f "$launcher"
    echo "Removed dangling launcher symlink: $launcher"
    removed_any=true
  fi
elif [[ -f "$launcher" ]]; then
  if grep -q 'ProtonSteam Interceptor' "$launcher" 2>/dev/null; then
    rm -f "$launcher"
    echo "Removed launcher script: $launcher"
    removed_any=true
  else
    echo "Skipped launcher (unexpected contents): $launcher"
  fi
fi

if [[ -f "$desktop_file" ]]; then
  if grep -q '^Exec=proton-steam-interceptor' "$desktop_file"; then
    rm -f "$desktop_file"
    echo "Removed desktop entry: $desktop_file"
    removed_any=true
    desktop_removed=true
  else
    echo "Skipped desktop entry (unexpected contents): $desktop_file"
  fi
fi

if [[ -d "$app_dir" ]]; then
  if rmdir "$app_dir" 2>/dev/null; then
    echo "Removed empty directory: $app_dir"
  fi
fi

if $desktop_removed && command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
fi

if ! $removed_any; then
  echo "No ProtonSteam Interceptor assets were found to remove."
else
  echo "Uninstall complete."
fi
