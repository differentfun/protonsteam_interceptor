#!/usr/bin/env bash
# Zenity helper to launch additional Windows executables inside an active Proton instance.
set -euo pipefail

if ! command -v zenity >/dev/null 2>&1; then
  echo "Error: zenity is not installed or not in PATH." >&2
  exit 1
fi

if ! command -v setsid >/dev/null 2>&1; then
  echo "Error: setsid is not available; install the util-linux package." >&2
  exit 1
fi

run_zenity() {
  local output status
  if output=$(zenity "$@" 2> >(grep -vE 'Gtk-WARNING|Adwaita-WARNING' >&2 || true)); then
    printf '%s' "$output"
    return 0
  else
    status=$?
    printf '%s' "$output"
    return "$status"
  fi
}

declare -A app_pid=()
declare -A app_prefix=()
declare -A app_proton=()
declare -A app_cmd=()
declare -A app_score=()

candidate_pids=()
while IFS= read -r pid; do
  candidate_pids+=("$pid")
done < <(pgrep -u "$UID" || true)

for pid in "${candidate_pids[@]}"; do
  [[ $pid =~ ^[0-9]+$ ]] || continue

  env_file="/proc/$pid/environ"
  [[ -r $env_file ]] || continue

  uid_file="/proc/$pid/status"
  if [[ -r $uid_file ]]; then
    proc_uid=$(awk '/^Uid:/ {print $2}' "$uid_file")
    [[ $proc_uid -eq $UID ]] || continue
  fi

  env_entries=()
  if ! mapfile -d '' -t env_entries < <(cat "$env_file" 2>/dev/null); then
    continue
  fi
  ((${#env_entries[@]})) || continue

  steam_app_id=""
  compat_path=""
  proton_path=""
  tool_paths=""
  proton_script=""

  for entry in "${env_entries[@]}"; do
    [[ -z $entry ]] && continue
    case $entry in
      SteamAppId=*|SteamGameId=*)
        [[ -z $steam_app_id ]] && steam_app_id=${entry#*=}
        ;;
      STEAM_COMPAT_DATA_PATH=*)
        compat_path=${entry#*=}
        ;;
      WINEPREFIX=*)
        [[ -z $compat_path ]] && compat_path=${entry#*=}
        ;;
      PROTON_DIST_PATH=*)
        proton_path=${entry#*=}
        ;;
      STEAM_COMPAT_TOOL_PATHS=*)
        tool_paths=${entry#*=}
        ;;
      PROTON_SCRIPT=*)
        proton_script=${entry#*=}
        ;;
    esac
  done

  [[ -n $steam_app_id ]] || continue
  [[ -n $compat_path ]] || continue

  if [[ -z $proton_path && -n $tool_paths ]]; then
    IFS=':' read -r -a tool_candidates <<< "$tool_paths"
    for tool in "${tool_candidates[@]}"; do
      [[ -n $tool ]] || continue
      if [[ -x "$tool/proton" ]]; then
        proton_path=$tool
        break
      fi
    done
  fi

  if [[ -z $proton_path && -n $proton_script ]]; then
    proton_path=$(dirname "$proton_script")
  fi

  process_cmd=""
  cmd_file="/proc/$pid/cmdline"
  if [[ -r $cmd_file ]]; then
    process_cmd=$(tr '\0' ' ' < "$cmd_file")
    process_cmd=${process_cmd%% }
  fi
  [[ -n $process_cmd ]] || process_cmd="[PID $pid]"

  score=0
  [[ -n $proton_path ]] && score=$((score + 2))
  if [[ $process_cmd == *waitforexitandrun* || $process_cmd == *"/proton "* || $process_cmd == *"proton.exe"* ]]; then
    score=$((score + 1))
  fi

  current_score=${app_score[$steam_app_id]:- -1}
  if (( score > current_score )); then
    app_pid[$steam_app_id]=$pid
    app_prefix[$steam_app_id]=$compat_path
    app_proton[$steam_app_id]=$proton_path
    app_cmd[$steam_app_id]=$process_cmd
    app_score[$steam_app_id]=$score
  fi
done

if ((${#app_pid[@]} == 0)); then
  printf -v no_sessions_text 'No Proton sessions are running for user %s.\nStart a Proton game from Steam and try again.' "$(whoami)"
  run_zenity --no-markup --warning --title="No Proton Sessions" \
    --text="$no_sessions_text" || true
  exit 0
fi

mapfile -t app_ids < <(printf '%s\n' "${!app_pid[@]}" | sort)

declare -a list_entries=()
for app_id in "${app_ids[@]}"; do
  pid=${app_pid[$app_id]}
  prefix=${app_prefix[$app_id]}
  cmd=${app_cmd[$app_id]}
  list_entries+=("$app_id" "$prefix" "$cmd" "$pid")
done

selected_app_id=$(run_zenity --list \
  --title="Active Proton Sessions" \
  --text="Select the Proton session that should launch the additional executable." \
  --column="AppID" --column="Prefix" --column="Executable" --column="PID" \
  --print-column=1 \
  "${list_entries[@]}" \
  --width=960 --height=420) || exit 0

[[ -n $selected_app_id ]] || exit 0

selected_pid=${app_pid[$selected_app_id]}
compat_path=${app_prefix[$selected_app_id]}
proton_hint=${app_proton[$selected_app_id]}

env_file="/proc/$selected_pid/environ"
if [[ ! -r $env_file ]]; then
  run_zenity --no-markup --error --title="Process Unavailable" \
    --text="The selected Proton process exited before it could be reused." || true
  exit 1
fi

if ! mapfile -d '' -t env_entries < "$env_file" 2>/dev/null; then
  run_zenity --no-markup --error --title="Process Unavailable" \
    --text="The selected Proton process exited before it could be reused." || true
  exit 1
fi

proton_dist=""
steam_client_path=""
proton_version=""
tool_paths=""
proton_script=""

for entry in "${env_entries[@]}"; do
  [[ -z $entry ]] && continue
  case $entry in
    PROTON_DIST_PATH=*)
      proton_dist=${entry#*=}
      ;;
    STEAM_COMPAT_DATA_PATH=*)
      compat_path=${entry#*=}
      ;;
    WINEPREFIX=*)
      [[ -z $compat_path ]] && compat_path=${entry#*=}
      ;;
    SteamAppId=*|SteamGameId=*)
      [[ -z $selected_app_id ]] && selected_app_id=${entry#*=}
      ;;
    STEAM_COMPAT_CLIENT_INSTALL_PATH=*)
      steam_client_path=${entry#*=}
      ;;
    STEAM_COMPAT_TOOL_PATHS=*)
      tool_paths=${entry#*=}
      ;;
    PROTON_SCRIPT=*)
      proton_script=${entry#*=}
      ;;
    PROTON_VERSION=*)
      proton_version=${entry#*=}
      ;;
  esac
done

if [[ -z $proton_dist && -n $tool_paths ]]; then
  IFS=':' read -r -a tool_candidates <<< "$tool_paths"
  for tool in "${tool_candidates[@]}"; do
    [[ -n $tool ]] || continue
    if [[ -x "$tool/proton" ]]; then
      proton_dist=$tool
      break
    fi
  done
fi

if [[ -z $proton_dist && -n $proton_script ]]; then
  proton_dist=$(dirname "$proton_script")
fi

if [[ -z $proton_dist && -n $proton_hint ]]; then
  proton_dist=$proton_hint
fi

if [[ -z $proton_dist && -n $steam_client_path && -n $proton_version ]]; then
  candidate_paths=(
    "$steam_client_path/steamapps/common/$proton_version"
    "$steam_client_path/steamapps/compatibilitytools.d/$proton_version"
  )
  for candidate in "${candidate_paths[@]}"; do
    if [[ -x "$candidate/proton" ]]; then
      proton_dist=$candidate
      break
    fi
  done
fi

if [[ -z $proton_dist || ! -x "$proton_dist/proton" ]]; then
  escaped_hint=${proton_dist:-"(empty)"}
  printf -v launcher_missing_text 'Unable to locate the proton script for this session.\nDetected path: %s' "$escaped_hint"
  run_zenity --no-markup --error --title="Proton Launcher Missing" \
    --text="$launcher_missing_text" || true
  exit 1
fi

if [[ -z $compat_path ]]; then
  run_zenity --no-markup --error --title="Prefix Missing" \
    --text="Could not determine the WINE prefix for the selected Proton session." || true
  exit 1
fi

default_dir="$compat_path/pfx/drive_c/"
[[ -d $default_dir ]] || default_dir="$HOME/"

selected_exe=$(run_zenity --file-selection \
  --title="Select Windows Executable" \
  --text="Pick the .exe you want to run inside the same Proton environment." \
  --filename="$default_dir") || exit 0

[[ -f $selected_exe ]] || {
  run_zenity --no-markup --error --title="Invalid File" \
    --text="The selected path is not a regular file." || true
  exit 1
}

launch() {
  (
    cd "$(dirname "$selected_exe")" || exit 1
    setsid env -i "${env_entries[@]}" "$proton_dist/proton" run "$selected_exe"
  )
}

launch >/dev/null 2>&1 &
child_pid=$!

sleep 1
if ! kill -0 "$child_pid" 2>/dev/null; then
  wait "$child_pid" || true
  run_zenity --no-markup --error --title="Launch Failed" \
    --text="The helper process exited immediately. Proton reported an error." || true
  exit 1
fi

disown "$child_pid" 2>/dev/null || true

run_zenity --no-markup --info --title="Launch Started" \
  --text="Executable launched successfully (PID $child_pid)." || true
