class_name ArenaVoteView
extends Control

signal voted(arena_id: String)
var state: Dictionary = {}
var cards: Array[Button] = []
var selected := 0
var last_hop := ""
var title: Label
var roster: Array[Dictionary] = []
var portrait_layer: Control
const TRAP_ICONS := preload("res://assets/ui/trampas_iconos.png")
const ARENA_TRAP_FRAMES := {"cienaga": [0, 1], "cripta": [2, 3], "taller": [4, 5, 6], "biblioteca": [7, 8]}

func _ready() -> void:
	size = Vector2(1280,720)
	theme = ThemeBuilder.build()
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b0710")
	backdrop.size = size
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var medallion := Panel.new()
	medallion.position = Vector2(566, 281)
	medallion.size = Vector2(148, 148)
	var medallion_style := StyleBoxFlat.new()
	medallion_style.bg_color = Color("241838")
	medallion_style.border_color = GameConfig.GOLD
	medallion_style.set_border_width_all(4)
	medallion_style.set_corner_radius_all(74)
	medallion_style.shadow_color = Color(0, 0, 0, 0.65)
	medallion_style.shadow_size = 12
	medallion_style.shadow_offset = Vector2(0, 5)
	medallion.add_theme_stylebox_override("panel", medallion_style)
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(medallion)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/fase12.json"))
	for index in 4:
		var quad: Array = metadata.votacion.quads_1920[index]
		var card := Button.new()
		card.position = Vector2(quad[0], quad[1]) * 2.0 / 3.0
		card.size = Vector2(quad[2], quad[3]) * 2.0 / 3.0
		card.clip_contents = true
		var arena_id: String = str(metadata.votacion.order[index])
		card.pressed.connect(func(): selected = index; voted.emit(arena_id))
		card.focus_entered.connect(func(): selected = index)
		add_child(card)
		cards.append(card)
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.size = card.size
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture = load("res://assets/ui/arena_%s_mini.png" % arena_id)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		var shade := ColorRect.new()
		shade.color = Color(0.04,0.02,0.06,0.85)
		shade.position.y = card.size.y - 125
		shade.size = Vector2(card.size.x,125)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(shade)
		var label := Label.new()
		label.text = I18n.t("arena_" + arena_id) + "\n" + I18n.t("premise_" + arena_id)
		label.position = shade.position + Vector2(20,8)
		label.size = shade.size - Vector2(40,16)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size",21)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		var trap_frames: Array = ARENA_TRAP_FRAMES.get(arena_id, [])
		for trap_index in trap_frames.size():
			var trap_icon := TextureRect.new()
			trap_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trap_icon.position = Vector2(card.size.x - 40.0 - trap_index * 34.0, card.size.y - 164.0)
			trap_icon.size = Vector2(30.0, 30.0)
			var trap_atlas := AtlasTexture.new()
			trap_atlas.atlas = TRAP_ICONS
			trap_atlas.region = Rect2(int(trap_frames[trap_index]) * 128.0, 0.0, 128.0, 128.0)
			trap_icon.texture = trap_atlas
			trap_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(trap_icon)
		var frame := NinePatchRect.new()
		frame.name = "Frame"
		frame.texture = load("res://assets/ui/cuadrante_marco.png")
		frame.size = card.size
		frame.patch_margin_left = 40
		frame.patch_margin_right = 40
		frame.patch_margin_top = 40
		frame.patch_margin_bottom = 40
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
	move_child(medallion, get_child_count() - 1)
	portrait_layer = Control.new()
	portrait_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_layer)
	title = Label.new()
	title.position = Vector2(480,305)
	title.size = Vector2(320,100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color", GameConfig.EMBER)
	title.add_theme_constant_override("outline_size",8)
	add_child(title)
	cards[0].grab_focus()

func update_state(value: Dictionary) -> void:
	state = value
	var lit := ""
	if state.phase != "voting":
		lit = str(state.winner)
		for hop: Dictionary in state.hops:
			if float(hop.at) <= float(state.spin_elapsed): lit = str(hop.arena)
			else: break
		if lit != last_hop:
			Sfx.play_tone(640,0.045)
			last_hop = lit
	title.text = I18n.t("vote_now") + "\n%d" % maxi(0, ceili(GameConfig.VOTE_SECONDS - float(state.elapsed))) if state.phase == "voting" else I18n.t("arena_" + lit)
	for index in cards.size():
		var id: String = GameConfig.ARENA_IDS[index]
		cards[index].modulate = Color.WHITE if id == lit or state.phase == "voting" else Color(0.4,0.4,0.4)
		var frame := cards[index].get_node("Frame") as NinePatchRect
		frame.texture = load("res://assets/ui/cuadrante_brillo.png" if id == lit else "res://assets/ui/cuadrante_marco.png")
		var won: bool = id == lit and state.phase != "voting" and (state.hops.is_empty() or float(state.spin_elapsed) >= GameConfig.VOTE_SPIN_SECONDS)
		cards[index].pivot_offset = cards[index].size * 0.5
		cards[index].scale = Vector2.ONE * (1.04 if won and not Settings.reduce_motion else 1.0)
	_update_vote_portraits()
	queue_redraw()

func _update_vote_portraits() -> void:
	for child in portrait_layer.get_children(): child.queue_free()
	var counts := {}
	for player: Dictionary in roster:
		var arena_id: String = str(state.votes.get(int(player.peer_id), ""))
		if arena_id.is_empty(): continue
		var index := GameConfig.ARENA_IDS.find(arena_id)
		if index < 0: continue
		var offset := int(counts.get(index, 0))
		counts[index] = offset + 1
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.texture = load("res://assets/characters/portrait_%s.png" % str(player.character))
		portrait.position = cards[index].position + Vector2(24 + offset * 42, 20)
		portrait.size = Vector2(38, 38)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_layer.add_child(portrait)

func _draw() -> void:
	if state.is_empty(): return

func _unhandled_input(event: InputEvent) -> void:
	if state.is_empty() or state.phase != "voting": return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		selected = (selected + 1) % 4
		cards[selected].grab_focus()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		selected = posmod(selected - 1,4)
		cards[selected].grab_focus()
	elif event.is_action_pressed("dash"): voted.emit(GameConfig.ARENA_IDS[selected])
