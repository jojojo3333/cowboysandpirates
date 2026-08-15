extends Control

# Boot smoke test. If you see "BOOT OK" on screen and in the terminal,
# the project is wired up correctly and Claude Code can take over from here.

func _ready() -> void:
	print("BOOT OK")
	# PRESET_FULL_RECT, not PRESET_CENTER. A Label anchored to the centre has
	# zero size until the first layout pass computes its minimum size, which is
	# the "runs fine, screen is empty" trap in CLAUDE.md. Filling the parent and
	# centring the text inside it cannot be zero-sized.
	var label := Label.new()
	label.text = "BOOT OK — Deadweight v0.1"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
