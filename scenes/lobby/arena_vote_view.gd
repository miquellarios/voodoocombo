class_name ArenaVoteView
extends Control

signal voted(arena_id: String)
var state: Dictionary = {}
var cards: Array[Button] = []
var selected := 0
var last_hop := ""
var title: Label
var roster: Array[Dictionary] = []

func _ready() -> void:
	size = Vector2(1280,720)
	theme = ThemeBuilder.build()
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/fase12.json"))
	for index in 4:
		var quad: Array = metadata.votacion.quads_1920[index]
		var card := Button.new()
		card.position = Vector2(quad[0], quad[1]) * 2.0 / 3.0
		card.size = Vector2(quad[2], quad[3]) * 2.0 / 3.0
		var arena_id: String = str(metadata.votacion.order[index])
		card.pressed.connect(func(): selected = index; voted.emit(arena_id))
		card.focus_entered.connect(func(): selected = index)
		add_child(card)
		cards.append(card)
		var image := TextureRect.new()
		image.texture = load("res://assets/ui/arena_%s_mini.png" % arena_id)
		image.size = card.size
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
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
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	var counts := {}
	for player: Dictionary in roster:
		var arena_id: String = str(state.votes.get(int(player.peer_id), ""))
		if arena_id.is_empty(): continue
		var index := GameConfig.ARENA_IDS.find(arena_id)
		var offset := int(counts.get(index,0))
		counts[index] = offset + 1
		var texture: Texture2D = load("res://assets/characters/portrait_%s.png" % str(player.character))
		draw_texture_rect(texture, Rect2(cards[index].position + Vector2(24 + offset * 50,20),Vector2(46,46)),false)

func _unhandled_input(event: InputEvent) -> void:
	if state.is_empty() or state.phase != "voting": return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		selected = (selected + 1) % 4
		cards[selected].grab_focus()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		selected = posmod(selected - 1,4)
		cards[selected].grab_focus()
	elif event.is_action_pressed("dash"): voted.emit(GameConfig.ARENA_IDS[selected])
