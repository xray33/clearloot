# <img src="assets/logo.png" width="48" height="48" align="absmiddle" alt="ClearLoot Logo" /> Clear Loot (`ClearLoot`)

**Clear Loot** is a lightweight, native-styled Quality-of-Life (QoL) World of Warcraft addon built for **World of Warcraft: Forever** and **WoW Classic Era / Anniversary**.

When contested loot drops in a dungeon or raid, Blizzard shows a standard `GroupLootFrame` popup with **Need**, **Greed**, and **Pass** buttons, but hides who has rolled or what they rolled inside the `/loot` history window or chat spam. **Clear Loot** places a clean, Classic-styled companion window right next to the active loot roll frame so you can see every group or raid member's decision and roll in real time.

---

## ✨ Features

- **Real-Time Roll Tracking:** Automatically updates as party or raid members select **Need**, **Greed**, **Disenchant**, or **Pass**, showing their exact roll (1–100) or pending status (`Rolling...`).
- **Provisional Winner Banner:** Highlights who is currently winning the item (`Need > Greed > Disenchant > Pass`) and automatically detects ties.
- **Anti-Screen-Flood Multi-Item Design:** When multiple items drop at once (e.g., boss kills or chests), ClearLoot never floods your screen with multiple windows. Instead, it uses a **single companion window** with **mini item-icon tabs** at the top and automatic focus switching when you hover over any of Blizzard's `GroupLootFrame1..4` popups.
- **Class & Role Awareness:** Displays player class icons, class-colored names, and role icons (Tank, Healer, DPS).
- **Native Player Context Menu:** Right-click any player row to open Blizzard's default unit/player dropdown menu (**Whisper**, **Inspect**, **Invite**, **Target**, **Copy Name**), or `Shift + Left-Click` to whisper immediately.
- **Per-Item Close (`[X]`):** Closing the window hides it only for that specific item roll; it automatically reopens when the next contested item drops.
- **Raid-Ready Scrolling & Filters:** Capped at 10 visible rows with a mouse-wheel scrollbar for 20/40-man raids, plus optional settings to hide players who clicked **Pass** or are still **Pending**.
- **Multi-Locale Support:** Out-of-the-box localization for English (`enUS`/`enGB`), Russian (`ruRU`), German (`deDE`), French (`frFR`), and Spanish (`esES`/`esMX`), backed by locale-agnostic `GlobalStrings` chat pattern matching.

---

## 🎮 Slash Commands & Solo Testing

ClearLoot includes a built-in simulator so you can test single drops, multi-item boss drops, and 40-man raid rolls solo in town without needing a live group:

| Command | Description |
| :--- | :--- |
| `/cl` or `/clearloot` | Print available slash commands in chat |
| `/cl test` | Simulate a 5-player party rolling on a single epic item |
| `/cl testmulti` | Simulate **4 items dropping simultaneously** (tests top item tabs) |
| `/cl testraid` | Simulate a **40-player raid** rolling on an item (tests scrolling & filters) |
| `/cl stop` | Stop and clear any active simulated rolls |
| `/cl show` | Reopen the tracker window if dismissed via `[X]` |
| `/cl config` | Open the ClearLoot settings panel (**Options -> AddOns -> ClearLoot**) |
| `/cl reset` | Reset the window anchor position to default (**Right of Group Loot**) |

---

## 🛠️ Development Setup

### Prerequisites
- **World of Warcraft Classic Era** (`_classic_era_`), **WoW Forever** (`_forever_`), or **WoW Anniversary** (`_anniversary_`) installed.

### 1. Clone & Link the Addon (macOS / Linux)
WoW requires the folder inside `Interface/AddOns/` to be named `ClearLoot` (matching `ClearLoot.toc`). Use the included helper script to create a symbolic link from your local WoW installation directly to this git repository:

```zsh
git clone <repo-url> clearloot
cd clearloot
./scripts/link_addon.sh
```

If your World of Warcraft installation is in a custom directory (other than `/Applications/World of Warcraft`), pass the path as an argument:

```zsh
./scripts/link_addon.sh "/Volumes/Games/World of Warcraft"
```

### 2. Live Edit & Reload Workflow
Because `Interface/AddOns/ClearLoot` is symlinked to your working tree:
1. Edit any `.lua` file in your editor.
2. In the running WoW client, type `/reload` in chat to reload the UI and test your changes immediately.
3. *(Note: If you add a new file to `ClearLoot.toc` or change `.toc` metadata, `/reload` picks up `.toc` changes in modern 1.15.x clients, or restart the client if needed).*

---

## 📂 Repository Architecture

```text
clearloot/
├── ClearLoot.toc              # Addon manifest (Interfaces: 16001 Forever, 11509 Classic Era, 20506 Anniversary, 50502 MoP)
├── Locales.lua                # Localization tables (enUS, ruRU, deDE, frFR, esES/esMX) + GlobalStrings
├── Core.lua                   # Namespace setup, SavedVariables (ClearLootDB), event bus, slash commands
├── RosterInspector.lua        # Party/raid scanner for class, class colors, roles, and unit tokens
├── DataTracker.lua            # C_LootHistory & CHAT_MSG_LOOT engine, sorting, provisional winner logic
├── UI/
│   ├── RollTrackerFrame.lua   # Main Classic-styled companion frame, item tabs, player rows, context menu
│   └── MultiItemManager.lua   # Safe hooking & anchoring to Blizzard's GroupLootFrame1..4
├── Config/
│   └── Settings.lua           # Options -> AddOns settings panel (Settings API + legacy fallback)
├── Test/
│   └── Simulator.lua          # Solo roll simulator (/cl test, /cl testmulti, /cl testraid)
├── assets/
│   └── logo.png               # Project logo / CurseForge icon
└── scripts/
    └── link_addon.sh          # Symlink installer for macOS WoW client directories
```

---

## ⚙️ Settings (`Options -> AddOns -> ClearLoot`)

- **Enable ClearLoot:** Master toggle to enable or disable the companion window.
- **Auto-Open on Contested Loot:** Automatically open the window when a new roll starts.
- **Show Player Role Icons:** Show Tank/Healer/DPS icons next to player names.
- **Switch Active Item on Hover:** Hovering over `GroupLootFrame1..4` switches the tracker to that item.
- **Keep Window Open After I Roll:** Keep tracking rolls until everyone finishes, even after your own `GroupLootFrame` closes.
- **Hide Passed Players / Hide Pending Players:** Filter out `Pass` or `Rolling...` rows to keep 20/40-man raid lists compact.
- **Window Anchor Position:** Anchor to the **Right** of `GroupLootFrame` (default), **Left** of `GroupLootFrame`, or **Free / Draggable** (`Shift + Left-Drag` anywhere on the header).
