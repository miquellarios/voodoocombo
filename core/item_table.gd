class_name ItemTable
extends RefCounted

const TABLE := {
	"first": {"magnet": 30, "boots": 25, "cloak": 30, "pin": 10, "frost": 5, "sheep": 0, "ring": 0},
	"middle": {"magnet": 20, "boots": 20, "cloak": 15, "pin": 20, "frost": 15, "sheep": 7, "ring": 3},
	"last": {"magnet": 15, "boots": 15, "cloak": 5, "pin": 20, "frost": 15, "sheep": 20, "ring": 10}
}

static func roll(position: String, rng: RandomNumberGenerator, classic: bool = false) -> String:
	var key := "middle" if position == "middle" else position
	var weights: Dictionary = TABLE.get(key, TABLE["last"]).duplicate()
	if classic:
		weights["ring"] = 0
	var total := 0
	for weight in weights.values():
		total += int(weight)
	var pick := rng.randi_range(1, total)
	for item in weights:
		pick -= int(weights[item])
		if pick <= 0:
			return str(item)
	return "boots"

static func probabilities_sum(position: String, classic: bool = false) -> int:
	var total := 0
	for item in TABLE.get(position, {}):
		if classic and item == "ring": continue
		total += int(TABLE[position][item])
	return total
