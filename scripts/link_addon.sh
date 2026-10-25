#!/usr/bin/env zsh
# Links this repository as 'ClearLoot' inside your World of Warcraft AddOns directory on macOS.
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

linked_any=0

for flavor in "${FLAVORS[@]}"; do
  FLAVOR_DIR="${WOW_BASE}/${flavor}"
  if [[ -d "${FLAVOR_DIR}" ]]; then
    ADDONS_DIR="${FLAVOR_DIR}/Interface/AddOns"
    mkdir -p "${ADDONS_DIR}"
    TARGET_LINK="${ADDONS_DIR}/ClearLoot"

    if [[ -L "${TARGET_LINK}" || -d "${TARGET_LINK}" ]]; then
      rm -rf "${TARGET_LINK}"
    fi

    ln -s "${REPO_DIR}" "${TARGET_LINK}"
    echo "✓ Linked ClearLoot -> ${TARGET_LINK}"
    linked_any=1
  fi
done

if [[ "${linked_any}" -eq 0 ]]; then
  echo "No existing WoW flavor folders found under: ${WOW_BASE}"
  echo "Creating default _classic_era_ AddOns symlink at: ${WOW_BASE}/_classic_era_/Interface/AddOns/ClearLoot"
  mkdir -p "${WOW_BASE}/_classic_era_/Interface/AddOns"
  ln -sf "${REPO_DIR}" "${WOW_BASE}/_classic_era_/Interface/AddOns/ClearLoot"
  echo "✓ Linked ClearLoot -> ${WOW_BASE}/_classic_era_/Interface/AddOns/ClearLoot"
fi
