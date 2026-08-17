extends Control
class_name SegmentedMeter

# Compact, drawn HUD meter. Unlike a stock ProgressBar this keeps a readable
# value at a glance while carrying the industrial segmented treatment used by
# the combat-preview HUD.

var caption: String = ""
var amount: int = 0
var maximum: int = 1
var colour: Color = Color(0.55, 0.78, 0.92)
var segments: int = 10

var _font: Font = null


func _ready() -> void:
	custom_minimum_size = Vector2(220.0, 18.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	queue_redraw()


func set_amount(value: int, limit: int = maximum) -> void:
	amount = value
	maximum = maxi(limit, 1)
	queue_redraw()


func _draw() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	var label_width: float = 58.0
	# Wide enough for "100/100". At 42 it was not, and draw_string silently
	# truncated rather than overflowing — the crew panel read "100/10", which
	# looks like a health bug rather than a text-clipping one and cost a
	# double-take. Size for the widest value the meter can hold, not the
	# narrowest that fits today.
	var value_width: float = 56.0
	var bar: Rect2 = Rect2(label_width, 4.0, maxf(size.x - label_width - value_width, 1.0), 10.0)

	draw_string(_font, Vector2(0.0, 13.0), caption, HORIZONTAL_ALIGNMENT_LEFT, label_width - 5.0, 10, Color(0.70, 0.74, 0.80))
	draw_rect(bar.grow(1.0), Color(0.22, 0.25, 0.30, 0.9), false, 1.0)
	draw_rect(bar, Color(0.015, 0.02, 0.027, 0.95))

	var active: int = int(round(float(clampi(amount, 0, maximum)) / float(maximum) * float(segments)))
	var gap: float = 2.0
	var segment_width: float = (bar.size.x - gap * float(segments - 1)) / float(segments)
	for i: int in range(segments):
		var at: Rect2 = Rect2(bar.position + Vector2(float(i) * (segment_width + gap), 1.0), Vector2(segment_width, bar.size.y - 2.0))
		var fill: Color = colour if i < active else Color(0.10, 0.12, 0.15, 0.95)
		draw_rect(at, fill)
		if i < active:
			draw_line(at.position, Vector2(at.end.x, at.position.y), Color(1.0, 1.0, 1.0, 0.24), 1.0)

	draw_string(
		_font, Vector2(bar.end.x + 6.0, 13.0), "%d/%d" % [amount, maximum],
		HORIZONTAL_ALIGNMENT_RIGHT, value_width - 6.0, 10, Color(0.82, 0.85, 0.90)
	)
