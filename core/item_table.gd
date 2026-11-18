class_name ItemTable
extends RefCounted

const TABLE := {
	"first": {"magnet": 30, "boots": 25, "cloak": 30, "pin": 10, "frost": 5, "sheep": 0, "ring": 0},
	"middle": {"magnet": 20, "boots": 20, "cloak": 15, "pin": 20, "frost": 15, "sheep": 7, "ring": 3},
	"last": {"magnet": 15, "boots": 15, "cloak": 5, "pin": 20, "frost": 15, "sheep": 20, "ring": 10}
}

static func display_key(item: String, mode: String) -> String:
	return "spell_stitch" if item == "ring" and mode == "survival" else "spell_" + item

static func roll(position: String, rng: RandomNumberGenerator) -> String:
	var key := "middle" if position == "middle" else position
	var weights: Dictionary = TABLE.get(key, TABLE["last"]).duplicate()
	var total := 0
	for weight in weights.values():
		total += int(weight)
	var pick := rng.randi_range(1, total)
	for item in weights:
		pick -= int(weights[item])
		if pick <= 0:
			return str(item)
	return "boots"

static func probabilities_sum(position: String) -> int:
	var total := 0
	for item in TABLE.get(position, {}):
		total += int(TABLE[position][item])
	return total
