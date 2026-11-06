#!/usr/bin/env zsh
# Links ClearLoot addon files (.toc and .lua) into your World of Warcraft AddOns directories on macOS.
# Uses real directories with per-file symlinks so:
#   1. Editing any file in the repo takes effect immediately on /reload in all clients.
#   2. External addon managers (like the CurseForge app) cannot traverse a directory symlink
#      and accidentally delete real source files inside your Git repository.
#
# Usage:
#   ./scripts/link_addon.sh
#   ./scripts/link_addon.sh "/Custom/Path/To/World of Warcraft"

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WOW_BASE="${1:-/Applications/World of Warcraft}"

FLAVORS=(
  "_classic_era_"
  "_forever_"
  "_anniversary_"
  "_classic_"
)

ADDON_FILES=(
  "ClearLoot.toc"
  "Locales.lua"
  "Core.lua"
  "RosterInspector.lua"
  "DataTracker.lua"
  "UI/RollTrackerFrame.lua"
  "UI/MultiItemManager.lua"
  "Config/Settings.lua"
  "Test/Simulator.lua"
)

link_into_target() {
  local target_dir="$1"

  # Remove old directory symlink or existing folder
  if [[ -L "${target_dir}" || -d "${target_dir}" ]]; then
    rm -rf "${target_dir}"
  fi

  mkdir -p "${target_dir}/UI" "${target_dir}/Config" "${target_dir}/Test"

  for rel_path in "${ADDON_FILES[@]}"; do
    ln -sf "${REPO_DIR}/${rel_path}" "${target_dir}/${rel_path}"
  done

  echo "✓ Linked ClearLoot files -> ${target_dir}"
}

linked_any=0

for flavor in "${FLAVORS[@]}"; do
  FLAVOR_DIR="${WOW_BASE}/${flavor}"
  if [[ -d "${FLAVOR_DIR}" ]]; then
    ADDONS_DIR="${FLAVOR_DIR}/Interface/AddOns"
    mkdir -p "${ADDONS_DIR}"
    link_into_target "${ADDONS_DIR}/ClearLoot"
    linked_any=1
  fi
done

if [[ "${linked_any}" -eq 0 ]]; then
  echo "No existing WoW flavor folders found under: ${WOW_BASE}"
  mkdir -p "${WOW_BASE}/_classic_era_/Interface/AddOns"
  link_into_target "${WOW_BASE}/_classic_era_/Interface/AddOns/ClearLoot"
fi
