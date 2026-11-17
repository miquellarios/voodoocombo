extends Node

var language := "es"
var strings := {
	"es": {"play": "JUGAR", "classic": "CLÁSICO", "classic_mode": "MODO CLÁSICO", "voodoo": "VOODOO COMBO", "combo": "¡Combo!", "voodoo_combo": "¡VOODOO COMBO!", "settings": "AJUSTES", "history": "HISTORIAL", "how": "Recoge doblones · Encadena combos · Golpea con el dash", "ready": "¡YA!", "again": "¡OTRA!", "menu": "MENÚ", "main_menu": "MENÚ PRINCIPAL", "winner": "GANADOR", "move": "MOVER", "spell": "HECHIZO", "you": "TÚ", "player": "J", "characters": "PERSONAJES", "exit": "SALIR", "time_up": "¡TIEMPO!", "trap_root": "¡Atrapado!", "trap_zap": "¡Zas!", "trap_ghost": "¡Buuu!", "trap_mud": "¡Lodo!", "trap_steam": "¡Vapor!", "trap_barrel": "¡Pum!", "trap_portal": "¡Portal!", "trap_ray": "¡Rayo!", "trap_blocked": "¡Bloqueado!"},
	"ca": {"play": "JUGAR", "classic": "CLÀSSIC", "classic_mode": "MODE CLÀSSIC", "voodoo": "VOODOO COMBO", "combo": "Combo!", "voodoo_combo": "VOODOO COMBO!", "settings": "AJUSTOS", "history": "HISTORIAL", "how": "Recull doblons · Encadena combos · Colpeja amb el dash", "ready": "JA!", "again": "UNA ALTRA!", "menu": "MENÚ", "main_menu": "MENÚ PRINCIPAL", "winner": "GUANYADOR", "move": "MOU-TE", "spell": "ENCANTERI", "you": "TU", "player": "J", "characters": "PERSONATGES", "exit": "SORTIR", "time_up": "TEMPS!", "trap_root": "Atrapat!", "trap_zap": "Zas!", "trap_ghost": "Buuu!", "trap_mud": "Fang!", "trap_steam": "Vapor!", "trap_barrel": "Pum!", "trap_portal": "Portal!", "trap_ray": "Llamp!", "trap_blocked": "Bloquejat!"},
	"en": {"play": "PLAY", "classic": "CLASSIC", "classic_mode": "CLASSIC MODE", "voodoo": "VOODOO COMBO", "combo": "Combo!", "voodoo_combo": "VOODOO COMBO!", "settings": "SETTINGS", "history": "HISTORY", "how": "Collect coins · Chain combos · Dash to hit", "ready": "GO!", "again": "AGAIN!", "menu": "MENU", "main_menu": "MAIN MENU", "winner": "WINNER", "move": "MOVE", "spell": "SPELL", "you": "YOU", "player": "P", "characters": "CHARACTERS", "exit": "EXIT", "time_up": "TIME!", "trap_root": "Trapped!", "trap_zap": "Zap!", "trap_ghost": "Boo!", "trap_mud": "Mud!", "trap_steam": "Steam!", "trap_barrel": "Boom!", "trap_portal": "Portal!", "trap_ray": "Zap!", "trap_blocked": "Blocked!"}
}

func t(key: String) -> String:
	return str(strings.get(language, strings.es).get(key, key))

func set_language(value: String) -> void:
	if strings.has(value):
		language = value
