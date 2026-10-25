local addonName, ns = ...

local locale = GetLocale and GetLocale() or "enUS"

-- Default (enUS / enGB) strings
-- Note: Standard WoW constants like NEED, GREED, PASS, ROLL_DISENCHANT, WHISPER, INSPECT, TARGET
-- are automatically localized by the WoW client in every language!
local L = {
    ADDON_TITLE = "Clear Loot",
    ADDON_SUBTITLE = "Real-time group & raid loot roll tracker alongside contested loot frames.",

    -- Roll Choices (use Blizzard GlobalStrings where available)
    ROLL_NEED = _G.NEED or "Need",
    ROLL_GREED = _G.GREED or "Greed",
    ROLL_DISENCHANT = _G.ROLL_DISENCHANT or "Disenchant",
    ROLL_PASS = _G.PASS or "Pass",
    ROLL_PENDING = "Rolling...",

    -- Table Headers
    HEADER_RANK = "#",
    HEADER_NAME = _G.NAME or "Name",
    HEADER_CHOICE = "Choice",
    HEADER_ROLL = "Roll",

    -- Provisional Winner Banner
    WINNER_LEADING = "Winning: %s (%s - %d)",
    WINNER_WON = "Winner: %s (%s - %d)",
    WINNER_TIE = "Tie (%s - %d): %s",
    WINNER_ALL_PASSED = "Everyone Passed",
    WINNER_WAITING = "Waiting for rolls...",

    -- Footer Summary
    FOOTER_SUMMARY = "Answered: %d/%d (%d pending)",
    FOOTER_COMPLETE = "Roll complete (%d/%d answered)",

    -- Tooltips & Interactions
    TOOLTIP_CLOSE_ITEM = "Hide tracker for this item",
    TOOLTIP_CLOSE_ITEM_DESC = "Will automatically reopen for the next contested item.",
    TOOLTIP_PLAYER_CLICK = "Right-Click: Player menu (Whisper, Inspect, Target)\nShift-Left-Click: Whisper player",
    TOOLTIP_TAB_SWITCH = "Click to view rolls for this item",

    -- Settings Panel (Options -> AddOns / Modifications)
    SETTINGS_ENABLE = "Enable ClearLoot",
    SETTINGS_ENABLE_DESC = "Show the real-time roll companion window when contested loot drops.",
    SETTINGS_AUTO_OPEN = "Auto-Open on Contested Loot",
    SETTINGS_AUTO_OPEN_DESC = "Automatically open the ClearLoot window when a new loot roll starts.",
    SETTINGS_SHOW_ROLE = "Show Player Role Icons",
    SETTINGS_SHOW_ROLE_DESC = "Display Tank, Healer, or DPS icons next to player names when available.",
    SETTINGS_AUTO_SWITCH = "Switch Active Item on Hover",
    SETTINGS_AUTO_SWITCH_DESC = "Automatically switch the displayed roll list when hovering over a Group Loot frame.",
    SETTINGS_KEEP_AFTER_ROLL = "Keep Window Open After I Roll",
    SETTINGS_KEEP_AFTER_ROLL_DESC = "Continue showing the roll window until all players finish rolling (even after your own roll frame closes).",
    SETTINGS_HIDE_PASS = "Hide Passed Players",
    SETTINGS_HIDE_PASS_DESC = "Do not display players who selected Pass in the roll list (ideal for 20/40-man raids).",
    SETTINGS_HIDE_PENDING = "Hide Pending Players",
    SETTINGS_HIDE_PENDING_DESC = "Do not display players who have not answered yet.",
    SETTINGS_ANCHOR_SIDE = "Window Anchor Position",
    SETTINGS_ANCHOR_RIGHT = "Right of Group Loot (Default)",
    SETTINGS_ANCHOR_LEFT = "Left of Group Loot",
    SETTINGS_ANCHOR_FREE = "Free / Draggable Window",
    SETTINGS_TEST_HEADER = "Solo Testing & Simulation",
    SETTINGS_TEST_SINGLE_BTN = "Test Single Item Roll",
    SETTINGS_TEST_MULTI_BTN = "Test 4-Item Boss Drop",
    SETTINGS_TEST_RAID_BTN = "Test 40-Man Raid Roll",
    SETTINGS_RESET_POS_BTN = "Reset Window Position",

    -- Chat & Slash Messages
    SLASH_HELP_HEADER = "|cff00ccffClearLoot|r commands:",
    SLASH_HELP_TEST = "  |cffffd100/cl test|r - Simulate a single contested item roll",
    SLASH_HELP_TESTMULTI = "  |cffffd100/cl testmulti|r - Simulate 4 simultaneous contested item rolls",
    SLASH_HELP_TESTRAID = "  |cffffd100/cl testraid|r - Simulate a 40-player raid item roll",
    SLASH_HELP_STOP = "  |cffffd100/cl stop|r - Clear active simulated rolls",
    SLASH_HELP_SHOW = "  |cffffd100/cl show|r - Show the tracker window",
    SLASH_HELP_CONFIG = "  |cffffd100/cl config|r - Open ClearLoot settings",
    MSG_SIM_STARTED = "Started simulated loot roll (%d item(s)).",
    MSG_SIM_STOPPED = "Cleared simulated loot rolls.",
    MSG_POS_RESET = "Window position reset to default.",
}

if locale == "ruRU" then
    L.ADDON_SUBTITLE = "Отслеживание бросков на добычу группы и рейда в реальном времени."
    L.ROLL_PENDING = "Раздумье..."
    L.HEADER_CHOICE = "Выбор"
    L.HEADER_ROLL = "Бросок"
    L.WINNER_LEADING = "Лидирует: %s (%s - %d)"
    L.WINNER_WON = "Победитель: %s (%s - %d)"
    L.WINNER_TIE = "Ничья (%s - %d): %s"
    L.WINNER_ALL_PASSED = "Все отказались"
    L.WINNER_WAITING = "Ожидание бросков..."
    L.FOOTER_SUMMARY = "Ответили: %d/%d (ожидается: %d)"
    L.FOOTER_COMPLETE = "Розыгрыш завершен (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Скрыть окно для этого предмета"
    L.TOOLTIP_CLOSE_ITEM_DESC = "Окно снова откроется при розыгрыше следующего предмета."
    L.TOOLTIP_PLAYER_CLICK = "ПКМ: Меню игрока (Шепот, Осмотр, Цель)\nShift+ЛКМ: Шепнуть игроку"
    L.TOOLTIP_TAB_SWITCH = "Нажмите, чтобы показать броски для этого предмета"
    L.SETTINGS_ENABLE = "Включить ClearLoot"
    L.SETTINGS_ENABLE_DESC = "Показывать окно отслеживания бросков при появлении спорной добычи."
    L.SETTINGS_AUTO_OPEN = "Авто-открытие при розыгрыше"
    L.SETTINGS_AUTO_OPEN_DESC = "Автоматически открывать окно ClearLoot при начале розыгрыша предмета."
    L.SETTINGS_SHOW_ROLE = "Показывать иконки ролей"
    L.SETTINGS_SHOW_ROLE_DESC = "Отображать иконку танка, лекаря или бойца рядом с именем игрока."
    L.SETTINGS_AUTO_SWITCH = "Переключать предмет при наведении"
    L.SETTINGS_AUTO_SWITCH_DESC = "Переключать список бросков при наведении курсора на окно добычи игры."
    L.SETTINGS_KEEP_AFTER_ROLL = "Не закрывать после моего выбора"
    L.SETTINGS_KEEP_AFTER_ROLL_DESC = "Оставлять окно открытым до окончания розыгрыша всеми участниками."
    L.SETTINGS_HIDE_PASS = "Скрывать отказавшихся (Пас)"
    L.SETTINGS_HIDE_PASS_DESC = "Не показывать в списке игроков, выбравших «Отказ» (удобно в рейдах на 20/40 чел.)."
    L.SETTINGS_HIDE_PENDING = "Скрывать еще не ответивших"
    L.SETTINGS_HIDE_PENDING_DESC = "Не показывать в списке игроков, которые еще раздумывают над выбором."
    L.SETTINGS_ANCHOR_SIDE = "Положение окна"
    L.SETTINGS_ANCHOR_RIGHT = "Справа от окна добычи (по умолчанию)"
    L.SETTINGS_ANCHOR_LEFT = "Слева от окна добычи"
    L.SETTINGS_ANCHOR_FREE = "Свободное (перемещаемое окно)"
    L.SETTINGS_TEST_HEADER = "Тестирование и симуляция"
    L.SETTINGS_TEST_SINGLE_BTN = "Тест: 1 предмет"
    L.SETTINGS_TEST_MULTI_BTN = "Тест: 4 предмета"
    L.SETTINGS_TEST_RAID_BTN = "Тест: Рейд 40 чел."
    L.SETTINGS_RESET_POS_BTN = "Сбросить позицию окна"
    L.MSG_SIM_STARTED = "Запущена симуляция розыгрыша (%d предм.)."
    L.MSG_SIM_STOPPED = "Симуляция розыгрыша остановлена."
    L.MSG_POS_RESET = "Позиция окна сброшена по умолчанию."

elseif locale == "deDE" then
    L.ADDON_SUBTITLE = "Echtzeit-Beutewurf-Tracker für Gruppen und Schlachtzüge."
    L.ROLL_PENDING = "Würfelt..."
    L.HEADER_CHOICE = "Auswahl"
    L.HEADER_ROLL = "Wurf"
    L.WINNER_LEADING = "Führend: %s (%s - %d)"
    L.WINNER_WON = "Gewinner: %s (%s - %d)"
    L.WINNER_TIE = "Gleichstand (%s - %d): %s"
    L.WINNER_ALL_PASSED = "Alle haben gepasst"
    L.WINNER_WAITING = "Warte auf Würfe..."
    L.FOOTER_SUMMARY = "Geantwortet: %d/%d (%d ausstehend)"
    L.FOOTER_COMPLETE = "Wurf abgeschlossen (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Tracker für diesen Gegenstand ausblenden"
    L.TOOLTIP_CLOSE_ITEM_DESC = "Öffnet sich automatisch wieder beim nächsten Gegenstand."
    L.TOOLTIP_PLAYER_CLICK = "Rechtsklick: Spielermenü (Flüstern, Betrachten, Ziel)\nShift-Linksklick: Spieler anflüstern"
    L.TOOLTIP_TAB_SWITCH = "Klicken, um Würfe für diesen Gegenstand anzuzeigen"
    L.SETTINGS_ENABLE = "ClearLoot aktivieren"
    L.SETTINGS_ENABLE_DESC = "Zeigt das Begleitfenster bei Beutewürfen an."
    L.SETTINGS_AUTO_OPEN = "Automatisch bei Beutewurf öffnen"
    L.SETTINGS_SHOW_ROLE = "Rollen-Symbole anzeigen"
    L.SETTINGS_AUTO_SWITCH = "Gegenstand bei Mouseover wechseln"
    L.SETTINGS_KEEP_AFTER_ROLL = "Nach eigenem Wurf geöffnet lassen"
    L.SETTINGS_ANCHOR_SIDE = "Fensterposition"
    L.SETTINGS_ANCHOR_RIGHT = "Rechts neben Beutefenster (Standard)"
    L.SETTINGS_ANCHOR_LEFT = "Links neben Beutefenster"
    L.SETTINGS_ANCHOR_FREE = "Frei beweglich"
    L.SETTINGS_TEST_HEADER = "Simulation & Test"
    L.SETTINGS_TEST_SINGLE_BTN = "Test: Einzelner Gegenstand"
    L.SETTINGS_TEST_MULTI_BTN = "Test: 4 Gegenstände"
    L.SETTINGS_RESET_POS_BTN = "Position zurücksetzen"

elseif locale == "frFR" then
    L.ADDON_SUBTITLE = "Suivi en temps réel des jets de butin de groupe et de raid."
    L.ROLL_PENDING = "En attente..."
    L.HEADER_CHOICE = "Choix"
    L.HEADER_ROLL = "Jet"
    L.WINNER_LEADING = "En tête : %s (%s - %d)"
    L.WINNER_WON = "Gagnant : %s (%s - %d)"
    L.WINNER_TIE = "Égalité (%s - %d) : %s"
    L.WINNER_ALL_PASSED = "Tout le monde a passé"
    L.WINNER_WAITING = "En attente des jets..."
    L.FOOTER_SUMMARY = "Répondu : %d/%d (%d en attente)"
    L.FOOTER_COMPLETE = "Jet terminé (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Masquer pour cet objet"
    L.TOOLTIP_CLOSE_ITEM_DESC = "S'ouvrira à nouveau pour le prochain objet."
    L.TOOLTIP_PLAYER_CLICK = "Clic droit : Menu joueur (Chuchoter, Inspecter, Cibler)\nMaj+Clic gauche : Chuchoter"
    L.TOOLTIP_TAB_SWITCH = "Cliquez pour voir les jets de cet objet"
    L.SETTINGS_ENABLE = "Activer ClearLoot"
    L.SETTINGS_AUTO_OPEN = "Ouvrir automatiquement"
    L.SETTINGS_SHOW_ROLE = "Afficher les icônes de rôle"
    L.SETTINGS_AUTO_SWITCH = "Changer d'objet au survol"
    L.SETTINGS_KEEP_AFTER_ROLL = "Garder ouvert après mon choix"
    L.SETTINGS_ANCHOR_SIDE = "Position de la fenêtre"
    L.SETTINGS_ANCHOR_RIGHT = "À droite du butin (Défaut)"
    L.SETTINGS_ANCHOR_LEFT = "À gauche du butin"
    L.SETTINGS_ANCHOR_FREE = "Fenêtre libre / déplaçable"
    L.SETTINGS_TEST_SINGLE_BTN = "Test : 1 objet"
    L.SETTINGS_TEST_MULTI_BTN = "Test : 4 objets"
    L.SETTINGS_RESET_POS_BTN = "Réinitialiser la position"

elseif locale == "esES" or locale == "esMX" then
    L.ADDON_SUBTITLE = "Seguimiento en tiempo real de tiradas de botín de grupo y banda."
    L.ROLL_PENDING = "Tirando..."
    L.HEADER_CHOICE = "Elección"
    L.HEADER_ROLL = "Tirada"
    L.WINNER_LEADING = "Ganando: %s (%s - %d)"
    L.WINNER_WON = "Ganador: %s (%s - %d)"
    L.WINNER_TIE = "Empate (%s - %d): %s"
    L.WINNER_ALL_PASSED = "Todos pasaron"
    L.WINNER_WAITING = "Esperando tiradas..."
    L.FOOTER_SUMMARY = "Respondido: %d/%d (%d pendientes)"
    L.FOOTER_COMPLETE = "Tirada completada (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Ocultar para este objeto"
    L.TOOLTIP_CLOSE_ITEM_DESC = "Se volverá a abrir con el siguiente objeto."
    L.TOOLTIP_PLAYER_CLICK = "Clic derecho: Menú de jugador (Susurrar, Inspeccionar, Objetivo)\nMayús+Clic izq.: Susurrar"
    L.SETTINGS_ENABLE = "Activar ClearLoot"
    L.SETTINGS_ANCHOR_RIGHT = "A la derecha del botín (Predeterminado)"
    L.SETTINGS_ANCHOR_LEFT = "A la izquierda del botín"
    L.SETTINGS_ANCHOR_FREE = "Ventana libre"
end

ns.L = L
