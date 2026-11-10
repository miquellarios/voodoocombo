extends Node

var language := "es"
var strings := {
	"es": {"play": "JUGAR", "classic": "CLÁSICO", "voodoo": "VOODOO COMBO", "settings": "AJUSTES", "how": "Recoge doblones · Encadena combos · Golpea con el dash", "ready": "¡YA!", "again": "¡OTRA!", "menu": "MENÚ", "winner": "GANADOR", "move": "MOVER", "spell": "HECHIZO"},
	"ca": {"play": "JUGAR", "classic": "CLÀSSIC", "voodoo": "VOODOO COMBO", "settings": "AJUSTOS", "how": "Recull doblons · Encadena combos · Colpeja amb el dash", "ready": "JA!", "again": "UNA ALTRA!", "menu": "MENÚ", "winner": "GUANYADOR", "move": "MOU-TE", "spell": "ENCANTERI"},
	"en": {"play": "PLAY", "classic": "CLASSIC", "voodoo": "VOODOO COMBO", "settings": "SETTINGS", "how": "Collect coins · Chain combos · Dash to hit", "ready": "GO!", "again": "AGAIN!", "menu": "MENU", "winner": "WINNER", "move": "MOVE", "spell": "SPELL"}
}

func t(key: String) -> String:
	return str(strings.get(language, strings.es).get(key, key))

func set_language(value: String) -> void:
	if strings.has(value):
		language = value
