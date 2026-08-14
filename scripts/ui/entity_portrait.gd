class_name EntityPortrait
extends Control


var _case_id := "rain_guest"
var _mood := "watchful"
var _phase := 0.0
var _pulse := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(260, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_entity(case_id: String, mood: String) -> void:
	_case_id = case_id
	_mood = mood
	queue_redraw()


func react() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_phase += delta
	_pulse = maxf(0.0, _pulse - delta * 2.4)
	queue_redraw()


func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color("090b13"))
	_draw_scanlines(bounds)
	var center := Vector2(size.x * 0.5, size.y * 0.52)
	var doorway := Rect2(center.x - 90.0, 22.0, 180.0, size.y - 42.0)
	draw_rect(doorway, Color("111827"), true)
	draw_rect(doorway, Color("3c465a"), false, 2.0)
	draw_line(Vector2(doorway.position.x + 12, doorway.end.y), Vector2(doorway.position.x + 35, doorway.position.y + 20), Color("252c3c"), 2.0)
	draw_line(Vector2(doorway.end.x - 12, doorway.end.y), Vector2(doorway.end.x - 35, doorway.position.y + 20), Color("252c3c"), 2.0)
	match _case_id:
		"shadow_tailor": _draw_tailor(center)
		"red_rescue": _draw_vampire(center)
		_: _draw_rain_guest(center)
	_draw_ward(doorway)
	var signal_color := Color("77e0cf") if _mood == "open" else Color("ff6b6b") if _mood == "threatening" else Color("f0b85a")
	draw_circle(Vector2(18, 18), 4.0 + sin(_phase * 4.0) * 1.0, signal_color)
	draw_string(ThemeDB.fallback_font, Vector2(30, 23), "THRESHOLD FEED / LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("8290a8"))


func _draw_scanlines(bounds: Rect2) -> void:
	for y: int in range(0, int(bounds.size.y), 5):
		draw_line(Vector2(0, y), Vector2(bounds.size.x, y), Color(0.12, 0.16, 0.23, 0.16), 1.0)
	var sweep_y := fmod(_phase * 32.0, maxf(1.0, bounds.size.y))
	draw_rect(Rect2(0, sweep_y, bounds.size.x, 2), Color(0.35, 0.85, 0.78, 0.07))


func _draw_rain_guest(center: Vector2) -> void:
	var sway := sin(_phase * 1.3) * 2.0
	var body := PackedVector2Array([
		Vector2(center.x - 52, center.y + 82),
		Vector2(center.x - 36 + sway, center.y - 22),
		Vector2(center.x + 34 + sway, center.y - 22),
		Vector2(center.x + 55, center.y + 82),
	])
	draw_colored_polygon(body, Color("17283a"))
	draw_circle(Vector2(center.x + sway, center.y - 48), 34.0, Color("23384a"))
	draw_arc(Vector2(center.x + sway, center.y - 48), 34.0, PI, TAU, 20, Color("698397"), 2.0)
	var eye_color := Color("ff8274") if _mood == "threatening" else Color("b9e6df")
	draw_circle(Vector2(center.x - 11 + sway, center.y - 50), 2.4 + _pulse, eye_color)
	draw_circle(Vector2(center.x + 11 + sway, center.y - 50), 2.4 + _pulse, eye_color)
	for index: int in range(12):
		var x := center.x - 78.0 + float((index * 29) % 156)
		var offset := fmod(_phase * (18.0 + index) + index * 13.0, 150.0)
		draw_line(Vector2(x, 55 + offset), Vector2(x - 3, 64 + offset), Color(0.45, 0.72, 0.86, 0.45), 1.0)


func _draw_tailor(center: Vector2) -> void:
	var twitch := sin(_phase * 5.0) * (1.0 + _pulse * 3.0)
	var body := PackedVector2Array([
		Vector2(center.x, center.y - 84),
		Vector2(center.x - 56, center.y + 82),
		Vector2(center.x + 58, center.y + 82),
	])
	draw_colored_polygon(body, Color("17151f"))
	draw_circle(Vector2(center.x + twitch, center.y - 63), 27, Color("272132"))
	for side: int in [-1, 1]:
		for arm: int in range(3):
			var origin := Vector2(center.x + side * 23, center.y - 8 + arm * 19)
			var target := Vector2(center.x + side * (72 + arm * 9), center.y - 25 + arm * 27 + twitch)
			draw_line(origin, target, Color("61526e"), 3.0)
			draw_line(target, target + Vector2(side * 12, -7), Color("a88db8"), 1.0)
	var eye_color := Color("ff6b6b") if _mood == "threatening" else Color("d7b5ec")
	draw_line(Vector2(center.x - 12 + twitch, center.y - 65), Vector2(center.x - 3 + twitch, center.y - 60), eye_color, 2.0 + _pulse)
	draw_line(Vector2(center.x + 12 + twitch, center.y - 65), Vector2(center.x + 3 + twitch, center.y - 60), eye_color, 2.0 + _pulse)


func _draw_vampire(center: Vector2) -> void:
	var breath := sin(_phase * 1.8) * 1.5
	var cape := PackedVector2Array([
		Vector2(center.x, center.y - 95 + breath),
		Vector2(center.x - 82, center.y + 82),
		Vector2(center.x, center.y + 56),
		Vector2(center.x + 82, center.y + 82),
	])
	draw_colored_polygon(cape, Color("251521"))
	draw_circle(Vector2(center.x, center.y - 53 + breath), 34, Color("c5b8b5"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x - 34, center.y - 59 + breath),
		Vector2(center.x - 17, center.y - 105 + breath),
		Vector2(center.x + 23, center.y - 94 + breath),
		Vector2(center.x + 34, center.y - 59 + breath),
	]), Color("1a1720"))
	var eye_color := Color("ff3e50") if _mood in ["threatening", "guarded"] else Color("f06b6b")
	draw_line(Vector2(center.x - 17, center.y - 56 + breath), Vector2(center.x - 6, center.y - 54 + breath), eye_color, 2.0 + _pulse)
	draw_line(Vector2(center.x + 17, center.y - 56 + breath), Vector2(center.x + 6, center.y - 54 + breath), eye_color, 2.0 + _pulse)
	draw_line(Vector2(center.x - 8, center.y - 35 + breath), Vector2(center.x + 8, center.y - 35 + breath), Color("70424b"), 1.0)


func _draw_ward(doorway: Rect2) -> void:
	var ward_color := Color("5dd9c7") if _mood != "threatening" else Color("ff665e")
	var alpha := 0.42 + sin(_phase * 2.2) * 0.10 + _pulse * 0.25
	ward_color.a = alpha
	for index: int in range(7):
		var x := doorway.position.x + 13.0 + index * 25.5
		draw_line(Vector2(x, doorway.end.y - 5), Vector2(x + 8, doorway.end.y - 16), ward_color, 2.0)
		draw_line(Vector2(x + 8, doorway.end.y - 16), Vector2(x + 16, doorway.end.y - 5), ward_color, 2.0)

