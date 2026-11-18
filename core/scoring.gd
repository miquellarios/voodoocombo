class_name Scoring
extends RefCounted

static func multiplier(combo: int) -> int:
	if combo >= 12:
		return 3
	if combo >= 5:
		return 2
	return 1

static func coin_value(combo: int, frenzy: bool, ring: bool) -> int:
	return mini(5, multiplier(combo) + int(frenzy) + int(ring))

static func dropped_coins(coins: int, crowned: bool, ring: bool) -> int:
	if coins <= 0:
		return 0
	var fraction := 0.4 if ring else (0.35 if crowned else 0.25)
	return mini(coins, clampi(int(ceil(coins * fraction)), 3, 12))

static func next_combo(combo: int, elapsed: float) -> int:
	return combo + 1 if elapsed < GameConfig.COMBO_WINDOW else 1
