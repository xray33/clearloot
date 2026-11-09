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
    ROLL_PENDING = "",

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
    SETTINGS_CHOICE_DISPLAY = "Choice Column Display",
    SETTINGS_CHOICE_ICONS = "Icons Only (Default)",
    SETTINGS_CHOICE_TEXT = "Text Only",
    SETTINGS_CHOICE_BOTH = "Icons & Text",
    SETTINGS_ANCHOR_SIDE = "Window Anchor Position",
    SETTINGS_ANCHOR_RIGHT = "Right of Group Loot (Default)",
    SETTINGS_ANCHOR_LEFT = "Left of Group Loot",
    SETTINGS_ANCHOR_FREE = "Free / Custom Position",
    SETTINGS_OPACITY = "Window Opacity",
    SETTINGS_OPACITY_DESC = "Adjust the opacity/transparency of the ClearLoot window (100% = fully opaque).",
    SETTINGS_SCALE = "Window Scale",
    SETTINGS_SCALE_DESC = "Adjust the size of the ClearLoot window (100% = normal size).",
    SETTINGS_TEST_HEADER = "Solo Testing & Simulation",
    SETTINGS_TEST_SINGLE_BTN = "Test Single Item Roll",
    SETTINGS_TEST_MULTI_BTN = "Test 4-Item Boss Drop",
    SETTINGS_TEST_RAID_BTN = "Test 40-Man Raid Roll",
    SETTINGS_MOVE_BTN = "Move Window",
    SETTINGS_RESET_POS_BTN = "Reset Position",
    EDIT_MODE_LABEL = "Clear Loot\nDrag to Move",
    EDIT_MODE_LOCK_BTN = "Lock Window",

    -- Chat & Slash Messages
    SLASH_HELP_HEADER = "|cff00ccffClearLoot|r commands:",
    SLASH_HELP_TEST = "  |cffffd100/cl test|r - Simulate a single contested item roll",
    SLASH_HELP_TESTMULTI = "  |cffffd100/cl testmulti|r - Simulate 4 simultaneous contested item rolls",
    SLASH_HELP_TESTRAID = "  |cffffd100/cl testraid|r - Simulate a 40-player raid item roll",
    SLASH_HELP_STOP = "  |cffffd100/cl stop|r - Clear active simulated rolls",
    SLASH_HELP_SHOW = "  |cffffd100/cl show|r - Show the tracker window",
    SLASH_HELP_MOVE = "  |cffffd100/cl move|r - Unlock/lock window for positioning",
    SLASH_HELP_CONFIG = "  |cffffd100/cl config|r - Open ClearLoot settings",
    MSG_SIM_STARTED = "Started simulated loot roll (%d item(s)).",
    MSG_SIM_STOPPED = "Cleared simulated loot rolls.",
    MSG_POS_RESET = "Window position reset to default.",
}

if locale == "ruRU" then
    L.ADDON_SUBTITLE = "Отслеживание бросков на добычу группы и рейда в реальном времени."
    L.ROLL_PENDING = ""
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
    L.SETTINGS_CHOICE_DISPLAY = "Отображение колонки «Выбор»"
    L.SETTINGS_CHOICE_ICONS = "Только иконки (по умолчанию)"
    L.SETTINGS_CHOICE_TEXT = "Только текст"
    L.SETTINGS_CHOICE_BOTH = "Иконки и текст"
    L.SETTINGS_ANCHOR_SIDE = "Положение окна"
    L.SETTINGS_ANCHOR_RIGHT = "Справа от окна добычи (по умолчанию)"
    L.SETTINGS_ANCHOR_LEFT = "Слева от окна добычи"
    L.SETTINGS_ANCHOR_FREE = "Свободное (своя позиция)"
    L.SETTINGS_OPACITY = "Непрозрачность окна"
    L.SETTINGS_OPACITY_DESC = "Настройка прозрачности окна ClearLoot (100% — полностью непрозрачное)."
    L.SETTINGS_SCALE = "Масштаб окна"
    L.SETTINGS_SCALE_DESC = "Настройка размера окна ClearLoot (100% — стандартный размер)."
    L.SETTINGS_TEST_HEADER = "Тестирование и симуляция"
    L.SETTINGS_TEST_SINGLE_BTN = "Тест: 1 предмет"
    L.SETTINGS_TEST_MULTI_BTN = "Тест: 4 предмета"
    L.SETTINGS_TEST_RAID_BTN = "Тест: Рейд 40 чел."
    L.SETTINGS_MOVE_BTN = "Переместить окно"
    L.SETTINGS_RESET_POS_BTN = "Сбросить позицию"
    L.EDIT_MODE_LABEL = "Clear Loot\nПеретащите окно"
    L.EDIT_MODE_LOCK_BTN = "Закрепить"
    L.SLASH_HELP_HEADER = "Команды |cff00ccffClearLoot|r:"
    L.SLASH_HELP_TEST = "  |cffffd100/cl test|r - Тест розыгрыша 1 предмета"
    L.SLASH_HELP_TESTMULTI = "  |cffffd100/cl testmulti|r - Тест розыгрыша 4 предметов"
    L.SLASH_HELP_TESTRAID = "  |cffffd100/cl testraid|r - Тест рейдового розыгрыша (40 чел.)"
    L.SLASH_HELP_STOP = "  |cffffd100/cl stop|r - Остановить симуляцию"
    L.SLASH_HELP_SHOW = "  |cffffd100/cl show|r - Показать окно"
    L.SLASH_HELP_MOVE = "  |cffffd100/cl move|r - Режим перемещения окна"
    L.SLASH_HELP_CONFIG = "  |cffffd100/cl config|r - Открыть настройки"
    L.MSG_SIM_STARTED = "Запущена симуляция розыгрыша (%d предм.)."
    L.MSG_SIM_STOPPED = "Симуляция розыгрыша остановлена."
    L.MSG_POS_RESET = "Позиция окна сброшена по умолчанию."

elseif locale == "deDE" then
    L.ADDON_SUBTITLE = "Echtzeit-Beutewurf-Tracker für Gruppen und Schlachtzüge."
    L.ROLL_PENDING = ""
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
    L.SETTINGS_ENABLE_DESC = "Zeigt das Begleitfenster bei Beutewürfen in Echtzeit an."
    L.SETTINGS_AUTO_OPEN = "Automatisch bei Beutewurf öffnen"
    L.SETTINGS_AUTO_OPEN_DESC = "Öffnet das ClearLoot-Fenster automatisch, sobald ein neuer Beutewurf beginnt."
    L.SETTINGS_SHOW_ROLE = "Rollen-Symbole anzeigen"
    L.SETTINGS_SHOW_ROLE_DESC = "Zeigt Tank-, Heiler- oder DPS-Symbole neben den Spielernamen an."
    L.SETTINGS_AUTO_SWITCH = "Gegenstand bei Mouseover wechseln"
    L.SETTINGS_AUTO_SWITCH_DESC = "Wechselt automatisch die angezeigte Wurfliste beim Überfahren eines Beutefensters."
    L.SETTINGS_KEEP_AFTER_ROLL = "Nach eigenem Wurf geöffnet lassen"
    L.SETTINGS_KEEP_AFTER_ROLL_DESC = "Lässt das Fenster geöffnet, bis alle Spieler gewürfelt haben."
    L.SETTINGS_HIDE_PASS = "Passende Spieler ausblenden"
    L.SETTINGS_HIDE_PASS_DESC = "Blendet Spieler aus, die Gepasst gewählt haben (ideal für 20/40-Spieler-Schlachtzüge)."
    L.SETTINGS_HIDE_PENDING = "Ausstehende Spieler ausblenden"
    L.SETTINGS_HIDE_PENDING_DESC = "Blendet Spieler aus, die noch nicht gewürfelt haben."
    L.SETTINGS_CHOICE_DISPLAY = "Anzeige der Auswahlspalte"
    L.SETTINGS_CHOICE_ICONS = "Nur Symbole (Standard)"
    L.SETTINGS_CHOICE_TEXT = "Nur Text"
    L.SETTINGS_CHOICE_BOTH = "Symbole & Text"
    L.SETTINGS_ANCHOR_SIDE = "Fensterposition"
    L.SETTINGS_ANCHOR_RIGHT = "Rechts neben Beutefenster (Standard)"
    L.SETTINGS_ANCHOR_LEFT = "Links neben Beutefenster"
    L.SETTINGS_ANCHOR_FREE = "Frei beweglich"
    L.SETTINGS_OPACITY = "Fensterdeckkraft"
    L.SETTINGS_OPACITY_DESC = "Deckkraft/Transparenz des ClearLoot-Fensters anpassen (100% = undurchsichtig)."
    L.SETTINGS_SCALE = "Fensterskalierung"
    L.SETTINGS_SCALE_DESC = "Größe des ClearLoot-Fensters anpassen (100% = Standardgröße)."
    L.SETTINGS_TEST_HEADER = "Simulation & Test"
    L.SETTINGS_TEST_SINGLE_BTN = "Test: 1 Gegenstand"
    L.SETTINGS_TEST_MULTI_BTN = "Test: 4 Gegenstände"
    L.SETTINGS_TEST_RAID_BTN = "Test: 40er-Schlachtzug"
    L.SETTINGS_MOVE_BTN = "Fenster bewegen"
    L.SETTINGS_RESET_POS_BTN = "Position zurücksetzen"
    L.EDIT_MODE_LABEL = "Clear Loot\nZum Bewegen ziehen"
    L.EDIT_MODE_LOCK_BTN = "Sperren"
    L.MSG_SIM_STARTED = "Beutewurf-Simulation gestartet (%d Gegenstand/Gegenstände)."
    L.MSG_SIM_STOPPED = "Beutewurf-Simulation beendet."
    L.MSG_POS_RESET = "Fensterposition wurde zurückgesetzt."

elseif locale == "frFR" then
    L.ADDON_SUBTITLE = "Suivi en temps réel des jets de butin de groupe et de raid."
    L.ROLL_PENDING = ""
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
    L.SETTINGS_ENABLE_DESC = "Afficher la fenêtre de suivi des jets de butin en temps réel."
    L.SETTINGS_AUTO_OPEN = "Ouvrir automatiquement"
    L.SETTINGS_AUTO_OPEN_DESC = "Ouvrir automatiquement la fenêtre ClearLoot lorsqu'un jet de butin commence."
    L.SETTINGS_SHOW_ROLE = "Afficher les icônes de rôle"
    L.SETTINGS_SHOW_ROLE_DESC = "Afficher les icônes Tank, Soigneur ou DPS à côté du nom des joueurs."
    L.SETTINGS_AUTO_SWITCH = "Changer d'objet au survol"
    L.SETTINGS_AUTO_SWITCH_DESC = "Changer automatiquement d'objet en survolant un cadre de butin de groupe."
    L.SETTINGS_KEEP_AFTER_ROLL = "Garder ouvert après mon choix"
    L.SETTINGS_KEEP_AFTER_ROLL_DESC = "Garder la fenêtre ouverte jusqu'à ce que tous les joueurs aient répondu."
    L.SETTINGS_HIDE_PASS = "Masquer les joueurs ayant passé"
    L.SETTINGS_HIDE_PASS_DESC = "Ne pas afficher les joueurs qui ont choisi Passer (idéal en raid 20/40)."
    L.SETTINGS_HIDE_PENDING = "Masquer les joueurs en attente"
    L.SETTINGS_HIDE_PENDING_DESC = "Ne pas afficher les joueurs qui n'ont pas encore répondu."
    L.SETTINGS_CHOICE_DISPLAY = "Affichage de la colonne Choix"
    L.SETTINGS_CHOICE_ICONS = "Icônes uniquement (Défaut)"
    L.SETTINGS_CHOICE_TEXT = "Texte uniquement"
    L.SETTINGS_CHOICE_BOTH = "Icônes et texte"
    L.SETTINGS_ANCHOR_SIDE = "Position de la fenêtre"
    L.SETTINGS_ANCHOR_RIGHT = "À droite du butin (Défaut)"
    L.SETTINGS_ANCHOR_LEFT = "À gauche du butin"
    L.SETTINGS_ANCHOR_FREE = "Fenêtre libre / déplaçable"
    L.SETTINGS_OPACITY = "Opacité de la fenêtre"
    L.SETTINGS_OPACITY_DESC = "Ajuster l'opacité/transparence de la fenêtre ClearLoot (100% = opaque)."
    L.SETTINGS_SCALE = "Échelle de la fenêtre"
    L.SETTINGS_SCALE_DESC = "Ajuster la taille de la fenêtre ClearLoot (100% = taille normale)."
    L.SETTINGS_TEST_HEADER = "Simulation et test"
    L.SETTINGS_TEST_SINGLE_BTN = "Test : 1 objet"
    L.SETTINGS_TEST_MULTI_BTN = "Test : 4 objets"
    L.SETTINGS_TEST_RAID_BTN = "Test : Raid 40 joueurs"
    L.SETTINGS_MOVE_BTN = "Déplacer la fenêtre"
    L.SETTINGS_RESET_POS_BTN = "Réinitialiser la position"
    L.EDIT_MODE_LABEL = "Clear Loot\nGlisser pour déplacer"
    L.EDIT_MODE_LOCK_BTN = "Verrouiller"
    L.MSG_SIM_STARTED = "Simulation de butin lancée (%d objet(s))."
    L.MSG_SIM_STOPPED = "Simulation de butin arrêtée."
    L.MSG_POS_RESET = "Position de la fenêtre réinitialisée."

elseif locale == "esES" or locale == "esMX" then
    L.ADDON_SUBTITLE = "Seguimiento en tiempo real de tiradas de botín de grupo y banda."
    L.ROLL_PENDING = ""
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
    L.TOOLTIP_CLOSE_ITEM_DESC = "Se volverá a abrir automáticamente con el siguiente objeto."
    L.TOOLTIP_PLAYER_CLICK = "Clic derecho: Menú de jugador (Susurrar, Inspeccionar, Objetivo)\nMayús+Clic izq.: Susurrar"
    L.TOOLTIP_TAB_SWITCH = "Haz clic para ver las tiradas de este objeto"
    L.SETTINGS_ENABLE = "Activar ClearLoot"
    L.SETTINGS_ENABLE_DESC = "Muestra la ventana de seguimiento de tiradas en tiempo real."
    L.SETTINGS_AUTO_OPEN = "Abrir automáticamente al iniciar tirada"
    L.SETTINGS_AUTO_OPEN_DESC = "Abre automáticamente la ventana de ClearLoot cuando comienza una tirada de botín."
    L.SETTINGS_SHOW_ROLE = "Mostrar iconos de función"
    L.SETTINGS_SHOW_ROLE_DESC = "Muestra iconos de Tanque, Sanador o DPS junto al nombre del jugador."
    L.SETTINGS_AUTO_SWITCH = "Cambiar de objeto al pasar el ratón"
    L.SETTINGS_AUTO_SWITCH_DESC = "Cambia automáticamente la lista al pasar el ratón sobre un marco de botín."
    L.SETTINGS_KEEP_AFTER_ROLL = "Mantener abierta tras mi tirada"
    L.SETTINGS_KEEP_AFTER_ROLL_DESC = "Mantiene la ventana abierta hasta que todos los jugadores terminen de tirar."
    L.SETTINGS_HIDE_PASS = "Ocultar jugadores que pasan"
    L.SETTINGS_HIDE_PASS_DESC = "No muestra a los jugadores que seleccionaron Pasar (ideal para bandas de 20/40)."
    L.SETTINGS_HIDE_PENDING = "Ocultar jugadores pendientes"
    L.SETTINGS_HIDE_PENDING_DESC = "No muestra a los jugadores que aún no han respondido."
    L.SETTINGS_CHOICE_DISPLAY = "Estilo de columna Elección"
    L.SETTINGS_CHOICE_ICONS = "Solo iconos (Predeterminado)"
    L.SETTINGS_CHOICE_TEXT = "Solo texto"
    L.SETTINGS_CHOICE_BOTH = "Iconos y texto"
    L.SETTINGS_ANCHOR_SIDE = "Posición de la ventana"
    L.SETTINGS_ANCHOR_RIGHT = "A la derecha del botín (Predeterminado)"
    L.SETTINGS_ANCHOR_LEFT = "A la izquierda del botín"
    L.SETTINGS_ANCHOR_FREE = "Ventana libre / movible"
    L.SETTINGS_OPACITY = "Opacidad de la ventana"
    L.SETTINGS_OPACITY_DESC = "Ajusta la opacidad/transparencia de la ventana ClearLoot (100% = opaca)."
    L.SETTINGS_SCALE = "Escala de la ventana"
    L.SETTINGS_SCALE_DESC = "Ajusta el tamaño de la ventana ClearLoot (100% = tamaño normal)."
    L.SETTINGS_TEST_HEADER = "Simulación y prueba"
    L.SETTINGS_TEST_SINGLE_BTN = "Prueba: 1 objeto"
    L.SETTINGS_TEST_MULTI_BTN = "Prueba: 4 objetos"
    L.SETTINGS_TEST_RAID_BTN = "Prueba: Banda de 40"
    L.SETTINGS_MOVE_BTN = "Mover ventana"
    L.SETTINGS_RESET_POS_BTN = "Restablecer posición"
    L.EDIT_MODE_LABEL = "Clear Loot\nArrastra para mover"
    L.EDIT_MODE_LOCK_BTN = "Bloquear"
    L.MSG_SIM_STARTED = "Simulación de tirada iniciada (%d objeto(s))."
    L.MSG_SIM_STOPPED = "Simulación de tirada detenida."
    L.MSG_POS_RESET = "Posición de la ventana restablecida."

elseif locale == "ptBR" or locale == "ptPT" then
    L.ADDON_SUBTITLE = "Rastreador em tempo real de rolagens de saque para grupo e raide."
    L.ROLL_PENDING = ""
    L.HEADER_CHOICE = "Escolha"
    L.HEADER_ROLL = "Rolagem"
    L.WINNER_LEADING = "Liderando: %s (%s - %d)"
    L.WINNER_WON = "Vencedor: %s (%s - %d)"
    L.WINNER_TIE = "Empate (%s - %d): %s"
    L.WINNER_ALL_PASSED = "Todos passaram"
    L.WINNER_WAITING = "Aguardando rolagens..."
    L.FOOTER_SUMMARY = "Respondido: %d/%d (%d pendentes)"
    L.FOOTER_COMPLETE = "Rolagem concluída (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Ocultar para este item"
    L.TOOLTIP_CLOSE_ITEM_DESC = "Abrirá novamente de forma automática no próximo item disputado."
    L.TOOLTIP_PLAYER_CLICK = "Clique direito: Menu do jogador (Sussurrar, Inspecionar, Alvo)\nShift+Clique esq.: Sussurrar"
    L.TOOLTIP_TAB_SWITCH = "Clique para ver as rolagens deste item"
    L.SETTINGS_ENABLE = "Ativar ClearLoot"
    L.SETTINGS_ENABLE_DESC = "Mostra a janela de acompanhamento de rolagens em tempo real."
    L.SETTINGS_AUTO_OPEN = "Abrir automaticamente no saque"
    L.SETTINGS_AUTO_OPEN_DESC = "Abre automaticamente a janela do ClearLoot quando uma disputa de saque começa."
    L.SETTINGS_SHOW_ROLE = "Mostrar ícones de função"
    L.SETTINGS_SHOW_ROLE_DESC = "Exibe ícones de Tanque, Curandeiro ou DPS ao lado do nome dos jogadores."
    L.SETTINGS_AUTO_SWITCH = "Alternar item ao passar o mouse"
    L.SETTINGS_AUTO_SWITCH_DESC = "Alterna automaticamente a lista ao passar o mouse sobre uma janela de saque."
    L.SETTINGS_KEEP_AFTER_ROLL = "Manter aberta após minha escolha"
    L.SETTINGS_KEEP_AFTER_ROLL_DESC = "Continua exibindo a janela até que todos os jogadores terminem de rolar."
    L.SETTINGS_HIDE_PASS = "Ocultar jogadores que passaram"
    L.SETTINGS_HIDE_PASS_DESC = "Não exibe jogadores que escolheram Passar (ideal para raides de 20/40 jogadores)."
    L.SETTINGS_HIDE_PENDING = "Ocultar jogadores pendentes"
    L.SETTINGS_HIDE_PENDING_DESC = "Não exibe jogadores que ainda não responderam."
    L.SETTINGS_CHOICE_DISPLAY = "Exibição da coluna Escolha"
    L.SETTINGS_CHOICE_ICONS = "Apenas ícones (Padrão)"
    L.SETTINGS_CHOICE_TEXT = "Apenas texto"
    L.SETTINGS_CHOICE_BOTH = "Ícones e texto"
    L.SETTINGS_ANCHOR_SIDE = "Posição da janela"
    L.SETTINGS_ANCHOR_RIGHT = "À direita do saque (Padrão)"
    L.SETTINGS_ANCHOR_LEFT = "À esquerda do saque"
    L.SETTINGS_ANCHOR_FREE = "Posição livre / móvel"
    L.SETTINGS_OPACITY = "Opacidade da janela"
    L.SETTINGS_OPACITY_DESC = "Ajusta a opacidade/transparência da janela ClearLoot (100% = totalmente opaca)."
    L.SETTINGS_SCALE = "Escala da janela"
    L.SETTINGS_SCALE_DESC = "Ajusta o tamanho da janela ClearLoot (100% = tamanho padrão)."
    L.SETTINGS_TEST_HEADER = "Simulação e Teste"
    L.SETTINGS_TEST_SINGLE_BTN = "Teste: 1 item"
    L.SETTINGS_TEST_MULTI_BTN = "Teste: 4 itens"
    L.SETTINGS_TEST_RAID_BTN = "Teste: Raide 40 jog."
    L.SETTINGS_MOVE_BTN = "Mover janela"
    L.SETTINGS_RESET_POS_BTN = "Redefinir posição"
    L.EDIT_MODE_LABEL = "Clear Loot\nArraste para mover"
    L.EDIT_MODE_LOCK_BTN = "Travar"
    L.MSG_SIM_STARTED = "Simulação de saque iniciada (%d item(ns))."
    L.MSG_SIM_STOPPED = "Simulação de saque encerrada."
    L.MSG_POS_RESET = "Posição da janela redefinida para o padrão."

elseif locale == "itIT" then
    L.ADDON_SUBTITLE = "Tracciamento in tempo reale dei tiri per il bottino di gruppo e incursione."
    L.ROLL_PENDING = ""
    L.HEADER_CHOICE = "Scelta"
    L.HEADER_ROLL = "Tiro"
    L.WINNER_LEADING = "In testa: %s (%s - %d)"
    L.WINNER_WON = "Vincitore: %s (%s - %d)"
    L.WINNER_TIE = "Pareggio (%s - %d): %s"
    L.WINNER_ALL_PASSED = "Tutti hanno passato"
    L.WINNER_WAITING = "In attesa dei tiri..."
    L.FOOTER_SUMMARY = "Risposto: %d/%d (%d in attesa)"
    L.FOOTER_COMPLETE = "Tiro completato (%d/%d)"
    L.TOOLTIP_CLOSE_ITEM = "Nascondi per questo oggetto"
    L.TOOLTIP_CLOSE_ITEM_DESC = "Si riaprirà automaticamente con il prossimo oggetto conteso."
    L.TOOLTIP_PLAYER_CLICK = "Clic destro: Menu giocatore (Sussurra, Ispeziona, Bersaglio)\nMaiusc+Clic sinistro: Sussurra"
    L.TOOLTIP_TAB_SWITCH = "Clicca per vedere i tiri di questo oggetto"
    L.SETTINGS_ENABLE = "Abilita ClearLoot"
    L.SETTINGS_ENABLE_DESC = "Mostra la finestra di tracciamento dei tiri in tempo reale."
    L.SETTINGS_AUTO_OPEN = "Apertura automatica"
    L.SETTINGS_AUTO_OPEN_DESC = "Apre automaticamente la finestra ClearLoot quando inizia un tiro per il bottino."
    L.SETTINGS_SHOW_ROLE = "Mostra icone di ruolo"
    L.SETTINGS_SHOW_ROLE_DESC = "Mostra le icone Difensore, Guaritore o Assaltatore accanto ai nomi dei giocatori."
    L.SETTINGS_AUTO_SWITCH = "Cambia oggetto al passaggio del mouse"
    L.SETTINGS_AUTO_SWITCH_DESC = "Cambia automaticamente la lista passando il mouse su una finestra del bottino."
    L.SETTINGS_KEEP_AFTER_ROLL = "Mantieni aperta dopo la mia scelta"
    L.SETTINGS_KEEP_AFTER_ROLL_DESC = "Mantiene aperta la finestra finché tutti i giocatori non hanno scelto."
    L.SETTINGS_HIDE_PASS = "Nascondi chi ha passato"
    L.SETTINGS_HIDE_PASS_DESC = "Non mostrare i giocatori che hanno selezionato Passa (ideale per incursioni da 20/40)."
    L.SETTINGS_HIDE_PENDING = "Nascondi giocatori in attesa"
    L.SETTINGS_HIDE_PENDING_DESC = "Non mostrare i giocatori che non hanno ancora risposto."
    L.SETTINGS_CHOICE_DISPLAY = "Stile colonna Scelta"
    L.SETTINGS_CHOICE_ICONS = "Solo icone (Predefinito)"
    L.SETTINGS_CHOICE_TEXT = "Solo testo"
    L.SETTINGS_CHOICE_BOTH = "Icone e testo"
    L.SETTINGS_ANCHOR_SIDE = "Posizione della finestra"
    L.SETTINGS_ANCHOR_RIGHT = "A destra del bottino (Predefinito)"
    L.SETTINGS_ANCHOR_LEFT = "A sinistra del bottino"
    L.SETTINGS_ANCHOR_FREE = "Posizione libera / spostabile"
    L.SETTINGS_OPACITY = "Opacità della finestra"
    L.SETTINGS_OPACITY_DESC = "Regola l'opacità/trasparenza della finestra ClearLoot (100% = opaca)."
    L.SETTINGS_SCALE = "Scala della finestra"
    L.SETTINGS_SCALE_DESC = "Regola la dimensione della finestra ClearLoot (100% = dimensione normale)."
    L.SETTINGS_TEST_HEADER = "Simulazione e Test"
    L.SETTINGS_TEST_SINGLE_BTN = "Test: 1 oggetto"
    L.SETTINGS_TEST_MULTI_BTN = "Test: 4 oggetti"
    L.SETTINGS_TEST_RAID_BTN = "Test: Incursione da 40"
    L.SETTINGS_MOVE_BTN = "Sposta finestra"
    L.SETTINGS_RESET_POS_BTN = "Reimposta posizione"
    L.EDIT_MODE_LABEL = "Clear Loot\nTrascina per spostare"
    L.EDIT_MODE_LOCK_BTN = "Blocca"
    L.MSG_SIM_STARTED = "Simulazione bottino avviata (%d oggetto/i)."
    L.MSG_SIM_STOPPED = "Simulazione bottino terminata."
    L.MSG_POS_RESET = "Posizione della finestra reimpostata."
end

ns.L = L
