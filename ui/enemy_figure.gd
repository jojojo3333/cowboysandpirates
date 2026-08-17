extends Node2D
class_name EnemyFigure

# A deliberately simple matte enemy figure. Player crew use rendered armour;
# these silhouettes must read as hostile people, not as another metallic clone.

const BODY: Color = Color(0.33, 0.045, 0.035)
const EDGE: Color = Color(0.12, 0.012, 0.012)
const VISOR: Color = Color(0.78, 0.12, 0.08)


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	# Drop shadow, helmet, torso, arms and legs. The restrained palette and lack
	# of specular highlights are intentional: this is cloth / matte armour.
	_draw_squashed_circle(Vector2(0.0, 25.0), Vector2(15.0, 5.0), Color(0.0, 0.0, 0.0, 0.65))
	draw_circle(Vector2(0.0, -22.0), 10.0, EDGE)
	draw_circle(Vector2(0.0, -22.0), 8.0, BODY)
	draw_rect(Rect2(-5.5, -24.0, 11.0, 3.0), VISOR)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -11.0), Vector2(11.0, -11.0), Vector2(13.0, 14.0),
		Vector2(7.0, 20.0), Vector2(-7.0, 20.0), Vector2(-13.0, 14.0),
	]), EDGE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.5, -9.0), Vector2(8.5, -9.0), Vector2(9.5, 12.0),
		Vector2(5.0, 17.0), Vector2(-5.0, 17.0), Vector2(-9.5, 12.0),
	]), BODY)
	draw_line(Vector2(-9.0, -6.0), Vector2(-16.0, 12.0), EDGE, 6.0)
	draw_line(Vector2(9.0, -6.0), Vector2(16.0, 12.0), EDGE, 6.0)
	draw_line(Vector2(-8.0, 17.0), Vector2(-10.0, 30.0), EDGE, 7.0)
	draw_line(Vector2(8.0, 17.0), Vector2(10.0, 30.0), EDGE, 7.0)
	draw_line(Vector2(-8.0, 17.0), Vector2(-10.0, 30.0), BODY, 3.0)
	draw_line(Vector2(8.0, 17.0), Vector2(10.0, 30.0), BODY, 3.0)


# Named `_draw_squashed_circle` and not `draw_ellipse`, which is what broke the
# build this arrived in.
#
# Godot 4.7's CanvasItem has its own `draw_ellipse(Vector2, float, float, Color,
# bool, float, bool)`. Declaring a method with the same name and a different
# signature is a hard parse error — "the function signature doesn't match the
# parent" — and it takes the whole scene down with it, which is why the project
# would not load at all rather than merely drawing the wrong thing.
#
# Any helper defined on a Node type risks this. The leading underscore is not
# decoration; it is what keeps a private helper out of the engine's namespace.
func _draw_squashed_circle(centre: Vector2, radius: Vector2, colour: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(18):
		var angle: float = TAU * float(i) / 18.0
		points.append(centre + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, colour)
