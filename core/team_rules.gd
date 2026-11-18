class_name TeamRules
extends RefCounted

static func speed(coins: int) -> float:
	return 1.0 - minf(GameConfig.TEAM_CARRY_SLOW_MAX, coins * GameConfig.TEAM_CARRY_SLOW)

static func scale_for(coins: int) -> float:
	return 1.0 + minf(GameConfig.TEAM_CARRY_GROW_MAX, coins * GameConfig.TEAM_CARRY_GROW)

static func coin_value(frenzy: bool, ring: bool) -> int:
	return (2 if frenzy else 1) * (2 if ring else 1)
