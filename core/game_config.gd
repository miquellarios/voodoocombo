class_name GameConfig
extends RefCounted

const ARENA_SIZE := Vector2(1200.0, 600.0)
const GRID_SIZE := Vector2i(30, 15)
const CELL_SIZE := 40.0
const PLAYER_SPEED := 260.0
const PLAYER_RADIUS := 22.0
const DASH_DURATION := 0.18
const DASH_MULTIPLIER := 3.0
const DASH_COOLDOWN := 1.5
const MATCH_SECONDS := 90.0
const CLASSIC_SECONDS := 180.0
const CLASSIC_TARGET := 15
const STARTING_COINS := 50
const COIN_RESPAWN_THRESHOLD := 18
const COIN_RESPAWN_INTERVAL := 0.5
const FRENZY_SECONDS := 15.0
const COMBO_WINDOW := 1.5
const COLORS := [Color("ff5a5f"), Color("3da5ff"), Color("7be042"), Color("f3eefc")]
const SHAPES := ["●", "▲", "■", "◆"]
const BACKGROUND := Color("160e22")
const GOLD := Color("ffd23f")
const BOT_REPATH_SECONDS := 0.3
const BOT_WAYPOINT_RADIUS := 12.0
const BOT_TARGET_BIAS := 24.0
const BOT_TARGET_MATCH_DISTANCE := 36.0
const BOT_TARGET_LEAD := 20.0
const BOT_STUCK_CHECK_SECONDS := 0.5
const BOT_STUCK_DISTANCE := 20.0
const BOT_ESCAPE_SECONDS := 0.3
const BOT_ESCAPE_PROBE := 64.0
const BOT_HAZARD_COST := 4.0
const BOT_RAY_AVOID_DEGREES := 40.0
