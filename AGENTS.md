# AGENTS.md — AI Agent Context & Engineering Guide for `ClearLoot`

## 1. Project Overview
**ClearLoot** (`Clear Loot`) is a World of Warcraft Quality-of-Life (QoL) addon targeting **World of Warcraft: Forever** (`16001` / `1.60.1`) and **WoW Classic Era / Anniversary** (`11509` / `20506`).

Its purpose is to display a real-time companion window alongside Blizzard's native contested loot roll frames (`GroupLootFrame1`–`GroupLootFrame4`). It shows which group/raid members have answered (`Need`, `Greed`, `Disenchant`, `Pass`, or `Rolling...`), their class and role icons, their roll numbers (`1–100`), and the **Provisional Winner** if the roll ended right now.

---

## 2. Target Client Environment & WoW API Quirks
When writing or modifying Lua code in this repository, always keep the **modern WoW Classic Era (1.15.x) / Forever** client architecture in mind:

1. **Modern Unified Client on Classic Rules:**
   - Classic Era `1.15.x` (`## Interface: 11509`) and Anniversary (`20506`) run on the modernized unified client engine.
   - **Settings API:** `InterfaceOptions_AddCategory` is deprecated/removed in 1.15.x; use `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory` (with `InterfaceOptions_AddCategory` only as a fallback).
   - **Checkbox Templates:** `InterfaceOptionsCheckButtonTemplate` may not exist unless legacy deprecated XML is loaded. Always check `DoesTemplateExist("InterfaceOptionsCheckButtonTemplate")` and fallback to `"UICheckButtonTemplate"`, creating `.Text` FontString if needed (see `Config/Settings.lua`).
   - **Backdrops:** Frames using `:SetBackdrop(...)` must inherit `"BackdropTemplate"` (`BackdropTemplateMixin and "BackdropTemplate" or nil`).

2. **Positioning & `GroupLootFrame1..4` Lifecycle:**
   - When the player logs in and no real loot roll has occurred yet, `GroupLootFrame1` exists in `_G` but is hidden and has **zero anchor points** (`GroupLootFrame1:GetNumPoints() == 0`) until `GroupLootContainer_Update` runs.
   - **CRITICAL:** Never anchor `ClearLootTrackerFrame` to `GroupLootFrame1..4` unless `targetGLF:IsShown() and targetGLF:GetNumPoints() > 0`. Otherwise, the ClearLoot frame will render off-screen during solo testing (`/cl test`). Fallback to `UIParent` (`CENTER`, `±220`, `-40`) when no `GroupLootFrame` is visible.

3. **Native Right-Click Player Context Menu (`UnitPopup_OpenMenu`):**
   - In 1.15.x, calling `FriendsFrame_ShowDropdown(name, 1)` without chat context or unit tokens causes Blizzard's menu generator to show only `"Copy Name"`.
   - To open the full default game menu:
     - First check `RosterInspector:FindUnitByName(name)` for a live unit token (`player`, `party1..4`, `raid1..40`) and call `UnitPopup_OpenMenu("SELF" | "PARTY" | "RAID_PLAYER", { unit = unit, name = ... })`.
     - If the player is simulated or not in the current unit list, call `UnitPopup_OpenMenu("FRIEND", { name = targetName, chatType = "PARTY", chatTarget = targetName, chatFrame = DEFAULT_CHAT_FRAME, lineID = 0 })` or `FriendsFrame_ShowDropdown(targetName, 1, 0, "PARTY", DEFAULT_CHAT_FRAME)`.

4. **Localization & Item Links:**
   - Never display raw `itemLink` strings in the window title if you want a clean header without `[` `]` brackets; extract `itemName` and color it via `GetItemQualityColor(itemQuality)`.
   - In `Test/Simulator.lua`, never rely solely on hardcoded English item strings. Always resolve item IDs through `GetItemInfo(itemID)` and `Item:CreateFromItemID(itemID):ContinueOnItemLoad(...)` so the client's localized item name is used.
   - All user-facing UI strings belong in `Locales.lua` (`ns.L`). Prefer Blizzard's built-in localized constants (`_G.NEED`, `_G.GREED`, `_G.PASS`, `_G.ROLL_DISENCHANT`, `_G.WHISPER`, `_G.INSPECT`, `_G.INVITE`, `_G.CANCEL`) whenever available.

---

## 3. Architecture & File Load Order
Files are loaded in the exact order specified in `ClearLoot.toc`. All modules share the addon table `ns` (`local addonName, ns = ...`) and expose `ClearLoot = ns` globally.

1. **`Locales.lua` (`ns.L`)**
   - Defines localized strings for `enUS` (default), `ruRU`, `deDE`, `frFR`, and `esES`/`esMX`.
2. **`Core.lua` (`ns`)**
   - Initializes `ClearLootDB` saved variables (`ns.db`), provides the event dispatcher (`ns:RegisterEvent`), initializes modules in `pcall` on `ADDON_LOADED`, and registers `/cl` and `/clearloot` slash commands.
3. **`RosterInspector.lua` (`ns.RosterInspector`)**
   - Scans `player`, `party1..4`, and `raid1..40` on `GROUP_ROSTER_UPDATE` / `PLAYER_ENTERING_WORLD`.
   - Provides class lookup, class-colored name formatting (`RAID_CLASS_COLORS`), role lookup (`UnitGroupRolesAssigned`), and unit token resolution (`FindUnitByName`).
4. **`DataTracker.lua` (`ns.DataTracker`)**
   - Manages active roll sessions (`rollsByID`, `activeRollOrder`), per-item dismissal state (`dismissedRolls[rollID]`), and `currentRollID`.
   - **Dual-source tracking:**
     1. Primary: `C_LootHistory` API (`START_LOOT_ROLL`, `CANCEL_LOOT_ROLL`, `LOOT_HISTORY_AUTO_SHOW`, `LOOT_HISTORY_ROLL_CHANGED`, `LOOT_HISTORY_ROLL_COMPLETE`, `LOOT_HISTORY_FULL_UPDATE`).
     2. Fallback: Locale-agnostic `CHAT_MSG_LOOT` parser built dynamically from `_G.LOOT_ROLL_*` format strings.
   - **`EvaluateSession(session)`:** Sorts players by roll priority (`Need (4) > Greed (3) > Disenchant (2) > Pass (1) > Pending (0)`) and descending score (`100..1`), and computes the **Provisional Winner** (`leaders`, tie detection, `allPassed`).
5. **`UI/RollTrackerFrame.lua` (`ns.RollTrackerFrame`)**
   - Builds `ClearLootTrackerFrame`, top mini item-icon tabs (`MAX_TABS = 6`), header with item tooltip, `[X]` per-item close button, Provisional Winner banner, and `FauxScrollFrameTemplate` row pool (`MIN_VISIBLE_ROWS = 5`, `MAX_VISIBLE_ROWS = 10`).
   - Applies `ns.db.hidePassed` and `ns.db.hidePending` filters during row rendering (`UpdatePlayerRows`) while preserving total counts in the footer summary.
6. **`UI/MultiItemManager.lua` (`ns.MultiItemManager`)**
   - Safely hooks `GroupLootFrame1..4` (`OnShow`, `OnHide`, `OnEnter`) via `HookScript` without tainting secure execution.
   - Positions `ClearLootTrackerFrame` on the `RIGHT`, `LEFT`, or `FREE` anchor position.
7. **`Config/Settings.lua` (`ns.Settings`)**
   - Builds the **Options -> AddOns -> ClearLoot** settings panel with checkboxes, anchor dropdown, and simulation buttons.
8. **`Test/Simulator.lua` (`ns.Simulator`)**
   - Implements `/cl test` (5-player single item), `/cl testmulti` (4 simultaneous items), `/cl testraid` (40-man raid roll), and `/cl stop`.

---

## 4. Development & Verification Workflow
- **Symlink Installation:** `./scripts/link_addon.sh` symlinks the repo root to `/Applications/World of Warcraft/_classic_era_/Interface/AddOns/ClearLoot` (and `_forever_` / `_anniversary_` if present).
- **In-Game Testing:**
  - After editing Lua files, run `/reload` in WoW Classic Era.
  - Test single-item UI and context menus with `/cl test`.
  - Test multi-item tabs with `/cl testmulti`.
  - Test 40-man raid scrolling and pass/pending filters with `/cl testraid`.
  - Test settings panel with `/cl config`.

---

## 5. Git, Pull Request, & Release Workflow
- **Protected `main` Branch:** Direct commits and pushes to `main` are strictly forbidden.
- **Branching Rule for AI Agents:**
  1. Before committing any changes, always check the current branch (`git branch --show-current`).
  2. If on `main`, create and switch to a descriptive feature or fix branch (`git checkout -b feat/<short-name>` or `git checkout -b fix/<short-name>`).
  3. Commit changes to the feature branch and push the branch (`git push -u origin <branch-name>`) to open a Pull Request against `main`.
- **CurseForge Release Packaging:**
  - CurseForge is configured to package **tagged commits** using `.pkgmeta` (`package-as: ClearLoot`) and `ClearLoot.toc` (`## X-Curse-Project-ID: 1765943`, `## Version: @project-version@`).
  - Releases are published by creating a semantic version tag (`v0.1.0`, `v0.1.1`, etc.) on `main` after a PR is merged (either via GitHub Releases UI or `git tag vX.Y.Z && git push origin vX.Y.Z`).
