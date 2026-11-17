extends Node

var language := "es"
var strings := {
	"es": {"play": "JUGAR", "classic": "CLÁSICO", "classic_mode": "MODO CLÁSICO", "voodoo": "VOODOO COMBO", "combo": "¡Combo!", "voodoo_combo": "¡VOODOO COMBO!", "settings": "AJUSTES", "history": "HISTORIAL", "how": "Recoge doblones · Encadena combos · Golpea con el dash", "ready": "¡YA!", "again": "¡OTRA!", "menu": "MENÚ", "main_menu": "MENÚ PRINCIPAL", "winner": "GANADOR", "move": "MOVER", "spell": "HECHIZO", "you": "TÚ", "player": "J", "characters": "PERSONAJES", "exit": "SALIR", "time_up": "¡TIEMPO!", "choose_arena": "ELIGE ARENA", "random_arena": "ALEATORIA", "arena_cienaga": "Ciénaga Embrujada", "arena_cripta": "Cripta de Huesos", "arena_taller": "Taller Gnómico", "arena_biblioteca": "Biblioteca Arcana", "spell_magnet": "Imán de Mithril", "spell_boots": "Botas de Montaraz", "spell_cloak": "Capa Élfica", "spell_pin": "Alfiler Vudú", "spell_frost": "Nova de Escarcha", "spell_sheep": "Maldición Ovina", "spell_ring": "Anillo de Poder", "spell_desc_magnet": "Atrae doblones durante 5 s", "spell_desc_boots": "Velocidad y dash mejorados durante 4 s", "spell_desc_cloak": "Bloquea el siguiente golpe durante 8 s", "spell_desc_pin": "Lanza un alfiler hacia el rival", "spell_desc_frost": "Congela a los rivales cercanos", "spell_desc_sheep": "Convierte al líder en oveja", "spell_desc_ring": "Dobla el valor de los doblones durante 6 s", "trap_root": "¡Atrapado!", "trap_zap": "¡Zas!", "trap_ghost": "¡Buuu!", "trap_mud": "¡Lodo!", "trap_steam": "¡Vapor!", "trap_barrel": "¡Pum!", "trap_portal": "¡Portal!", "trap_ray": "¡Rayo!", "trap_blocked": "¡Bloqueado!"},
	"ca": {"play": "JUGAR", "classic": "CLÀSSIC", "classic_mode": "MODE CLÀSSIC", "voodoo": "VOODOO COMBO", "combo": "Combo!", "voodoo_combo": "VOODOO COMBO!", "settings": "AJUSTOS", "history": "HISTORIAL", "how": "Recull doblons · Encadena combos · Colpeja amb el dash", "ready": "JA!", "again": "UNA ALTRA!", "menu": "MENÚ", "main_menu": "MENÚ PRINCIPAL", "winner": "GUANYADOR", "move": "MOU-TE", "spell": "ENCANTERI", "you": "TU", "player": "J", "characters": "PERSONATGES", "exit": "SORTIR", "time_up": "TEMPS!", "choose_arena": "TRIA L'ARENA", "random_arena": "ALEATÒRIA", "arena_cienaga": "Pantà Embruixat", "arena_cripta": "Cripta d'Ossos", "arena_taller": "Taller Gnòmic", "arena_biblioteca": "Biblioteca Arcana", "spell_magnet": "Imant de Mithril", "spell_boots": "Botes de Muntaner", "spell_cloak": "Capa Èlfica", "spell_pin": "Agulla Vudú", "spell_frost": "Nova de Gel", "spell_sheep": "Maledicció Ovina", "spell_ring": "Anell de Poder", "spell_desc_magnet": "Atreu doblons durant 5 s", "spell_desc_boots": "Velocitat i dash millorats durant 4 s", "spell_desc_cloak": "Bloqueja el cop següent durant 8 s", "spell_desc_pin": "Llança una agulla cap al rival", "spell_desc_frost": "Congela els rivals propers", "spell_desc_sheep": "Converteix el líder en ovella", "spell_desc_ring": "Dobla el valor dels doblons durant 6 s", "trap_root": "Atrapat!", "trap_zap": "Zas!", "trap_ghost": "Buuu!", "trap_mud": "Fang!", "trap_steam": "Vapor!", "trap_barrel": "Pum!", "trap_portal": "Portal!", "trap_ray": "Llamp!", "trap_blocked": "Bloquejat!"},
	"en": {"play": "PLAY", "classic": "CLASSIC", "classic_mode": "CLASSIC MODE", "voodoo": "VOODOO COMBO", "combo": "Combo!", "voodoo_combo": "VOODOO COMBO!", "settings": "SETTINGS", "history": "HISTORY", "how": "Collect coins · Chain combos · Dash to hit", "ready": "GO!", "again": "AGAIN!", "menu": "MENU", "main_menu": "MAIN MENU", "winner": "WINNER", "move": "MOVE", "spell": "SPELL", "you": "YOU", "player": "P", "characters": "CHARACTERS", "exit": "EXIT", "time_up": "TIME!", "choose_arena": "CHOOSE ARENA", "random_arena": "RANDOM", "arena_cienaga": "Haunted Swamp", "arena_cripta": "Bone Crypt", "arena_taller": "Gnome Workshop", "arena_biblioteca": "Arcane Library", "spell_magnet": "Mithril Magnet", "spell_boots": "Ranger Boots", "spell_cloak": "Elven Cloak", "spell_pin": "Voodoo Pin", "spell_frost": "Frost Nova", "spell_sheep": "Sheep Curse", "spell_ring": "Ring of Power", "spell_desc_magnet": "Attracts coins for 5 s", "spell_desc_boots": "Boosts speed and dash for 4 s", "spell_desc_cloak": "Blocks the next hit for 8 s", "spell_desc_pin": "Fires a pin at a rival", "spell_desc_frost": "Freezes nearby rivals", "spell_desc_sheep": "Turns the leader into a sheep", "spell_desc_ring": "Doubles coin value for 6 s", "trap_root": "Trapped!", "trap_zap": "Zap!", "trap_ghost": "Boo!", "trap_mud": "Mud!", "trap_steam": "Steam!", "trap_barrel": "Boom!", "trap_portal": "Portal!", "trap_ray": "Zap!", "trap_blocked": "Blocked!"}
}

func _init() -> void:
	strings.es.merge({
		"loading_controls": "WASD / flechas mover · Espacio dash · E hechizo · 1–4 emotes",
		"loading_player": "Eres el Jugador",
		"loading_skip": "Pulsa Espacio para empezar",
		"loading_trap_lodo": "Lodo · reduce tu velocidad mientras lo cruzas.",
		"loading_trap_raices": "Raíces · avisan y atrapan; quitan el 15 % (mín. 2, máx. 10).",
		"loading_trap_pinchos": "Pinchos · avisan antes de subir; quitan el 15 % (mín. 2, máx. 10).",
		"loading_trap_fantasma": "Fantasma · aturde y quita el 15 % (mín. 2, máx. 10).",
		"loading_trap_cinta": "Cinta · te empuja en la dirección de las flechas.",
		"loading_trap_vapor": "Vapor · avisa, empuja y quita el 15 % (mín. 2, máx. 10).",
		"loading_trap_barril": "Barril · explota tras un dash; quita el 15 % (mín. 2, máx. 10).",
		"loading_trap_portal": "Portal · te teletransporta a su pareja.",
		"loading_trap_rayo": "Rayo · evita el haz; quita el 15 % (mín. 2, máx. 10).",
		"loading_tip_1": "El combo se pierde si pasan 1,5 s sin recoger un doblón.",
		"loading_tip_2": "Con la corona sueltas más doblones cuando te golpean.",
		"loading_tip_3": "Los doblones que sueltas no se pueden recoger durante un momento.",
		"loading_tip_4": "Si ya llevas un hechizo, no podrás abrir otro cofre.",
		"loading_tip_5": "El Anillo añade un punto al valor de cada doblón.",
		"loading_tip_6": "En Frenesí, cada doblón vale un punto extra.",
		"loading_tip_7": "Usa el dash para golpear y robar doblones.",
		"loading_tip_8": "Las raíces avisan antes de atrapar a quien se acerque.",
		"loading_tip_9": "Los portales emparejados te transportan al instante.",
		"loading_tip_10": "Recoge los doblones cerca del centro antes de que acabe la partida."
	}, true)
	strings.ca.merge({
		"loading_controls": "WASD / fletxes moure · Espai dash · E encanteri · 1–4 emotes",
		"loading_player": "Ets el Jugador",
		"loading_skip": "Prem Espai per començar",
		"loading_trap_lodo": "Fang · redueix la velocitat mentre el travesses.",
		"loading_trap_raices": "Arrels · avisen i atrapen; treuen el 15 % (mín. 2, màx. 10).",
		"loading_trap_pinchos": "Punxes · avisen abans de pujar; treuen el 15 % (mín. 2, màx. 10).",
		"loading_trap_fantasma": "Fantasma · atordeix i treu el 15 % (mín. 2, màx. 10).",
		"loading_trap_cinta": "Cinta · t'empeny en la direcció de les fletxes.",
		"loading_trap_vapor": "Vapor · avisa, empeny i treu el 15 % (mín. 2, màx. 10).",
		"loading_trap_barril": "Barril · explota després d'un dash; treu el 15 % (mín. 2, màx. 10).",
		"loading_trap_portal": "Portal · et teletransporta a la seva parella.",
		"loading_trap_rayo": "Llamp · evita el feix; treu el 15 % (mín. 2, màx. 10).",
		"loading_tip_1": "El combo es perd si passen 1,5 s sense recollir un dobló.",
		"loading_tip_2": "Amb la corona deixes anar més doblons quan et colpegen.",
		"loading_tip_3": "No pots recollir els doblons que deixes anar durant un instant.",
		"loading_tip_4": "Si ja tens un encanteri, no podràs obrir cap altre cofre.",
		"loading_tip_5": "L'Anell afegeix un punt al valor de cada dobló.",
		"loading_tip_6": "En Frenesí, cada dobló val un punt extra.",
		"loading_tip_7": "Fes servir el dash per colpejar i robar doblons.",
		"loading_tip_8": "Les arrels avisen abans d'atrapar qui s'acosti.",
		"loading_tip_9": "Els portals aparellats et transporten a l'instant.",
		"loading_tip_10": "Recull els doblons prop del centre abans que s'acabi la partida."
	}, true)
	strings.en.merge({
		"loading_controls": "WASD / arrows move · Space dash · E spell · 1–4 emotes",
		"loading_player": "You are Player",
		"loading_skip": "Press Space to start",
		"loading_trap_lodo": "Mud · slows you while you cross it.",
		"loading_trap_raices": "Roots · warn and trap; remove 15% (min 2, max 10).",
		"loading_trap_pinchos": "Spikes · warn before rising; remove 15% (min 2, max 10).",
		"loading_trap_fantasma": "Ghost · stuns and removes 15% (min 2, max 10).",
		"loading_trap_cinta": "Conveyor · pushes you in the arrow direction.",
		"loading_trap_vapor": "Steam · warns, pushes and removes 15% (min 2, max 10).",
		"loading_trap_barril": "Barrel · explodes after a dash; removes 15% (min 2, max 10).",
		"loading_trap_portal": "Portal · teleports you to its pair.",
		"loading_trap_rayo": "Ray · avoid its beam; removes 15% (min 2, max 10).",
		"loading_tip_1": "Your combo resets after 1.5 s without collecting a coin.",
		"loading_tip_2": "The crown makes you drop more coins when hit.",
		"loading_tip_3": "Dropped coins are locked briefly before anyone can pick them up.",
		"loading_tip_4": "You cannot open another chest while holding a spell.",
		"loading_tip_5": "The Ring adds one point to every coin.",
		"loading_tip_6": "During Frenzy, every coin is worth one extra point.",
		"loading_tip_7": "Dash into rivals to hit them and steal coins.",
		"loading_tip_8": "Roots warn before trapping nearby players.",
		"loading_tip_9": "Paired portals teleport you instantly.",
		"loading_tip_10": "Collect coins near the center before the match ends."
	}, true)

func t(key: String) -> String:
	return str(strings.get(language, strings.es).get(key, key))

func set_language(value: String) -> void:
	if strings.has(value):
		language = value
