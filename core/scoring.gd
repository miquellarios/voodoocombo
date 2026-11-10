class_name Scoring
extends RefCounted

static func multiplier(combo: int, classic: bool = false) -> int:
	if classic:
		return 1
	if combo >= 20:
		return 4
	if combo >= 10:
		return 3
	if combo >= 5:
		return 2
	return 1

static func coin_value(combo: int, frenzy: bool, ring: bool, classic: bool = false) -> int:
	return multiplier(combo, classic) * (2 if frenzy and not classic else 1) * (2 if ring and not classic else 1)

static func dropped_coins(coins: int, crowned: bool, ring: bool) -> int:
	if coins <= 0:
		return 0
	var fraction := 0.4 if ring else (0.35 if crowned else 0.25)
	return mini(coins, clampi(int(ceil(coins * fraction)), 3, 12))

static func next_combo(combo: int, elapsed: float) -> int:
	return combo + 1 if elapsed < GameConfig.COMBO_WINDOW else 1
