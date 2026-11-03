extends Power
class_name Feed
## Comida: se saca desde el HUD o con la tecla F (Esc o click derecho la guardan). Está desde el
## principio, no hay que comprarla. Cada click en la isla gasta un poco de devoción y baja del
## cielo un pan (ver Manna) que se come el que tenga hambre; si hacés click sobre un aldeano,
## es para él.

const COST := 3.0                # Devoción por pan
const COOLDOWN := 0.4
const C_AIM := Color(1.0, 0.72, 0.35)
const C_OUTLINE := Color(0.06, 0.06, 0.1)

var _cooldown := 0.0
var _t := 0.0
static var _wav: AudioStreamWAV

func _init() -> void:
	id = "feed"
	title = "Comida"
	key = KEY_F
	good = true
	accent = HUD.C_FEED
	always = true
	unlocked = true
	scares = false
	cost = COST
	tooltip = "Tirarles comida [F]"
	hint = "Click en la isla para tirarles comida, o sobre un aldeano para dársela a él (−%d devoción) · click derecho, Esc o F para guardarla."

func _ready() -> void:
	z_index = 30   # Encima de los aldeanos

func _on_armed(_on: bool) -> void:
	queue_redraw()   # Al guardarla, que se borre la mira

func _use(at: Vector2) -> void:
	_drop(at)

func _process(dt: float) -> void:
	_t += dt
	_cooldown -= dt
	if armed:
		queue_redraw()

## Tira un pan en p (o a los pies del aldeano que está ahí, y es para él).
func _drop(p: Vector2) -> void:
	if _cooldown > 0.0:
		return
	var v := _villager_at(p)
	var at := v.ground_point() if v else p
	var screen := get_canvas_transform() * at
	if not _on_island(at):
		Game.say("Solo sobre la isla", screen, HUD.C_WARN)
		return
	if not Game.spend_devotion(COST):
		Game.say("Devoción insuficiente", screen, HUD.C_WARN)
		return
	_cooldown = COOLDOWN
	var m := Manna.new()
	m.meant_for = v
	var props: Node = get_parent().get("props")
	(props if props else get_parent()).add_child(m)
	m.drop_at(at)
	if _wav == null:
		_wav = _make_sound()
	var s := AudioStreamPlayer.new()
	s.stream = _wav
	s.volume_db = -12.0
	s.pitch_scale = randf_range(0.95, 1.08)
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)

## El aldeano vivo bajo el punto (el de más adelante), o null.
func _villager_at(at: Vector2) -> Villager:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = at
	q.collide_with_bodies = true
	var best: Villager = null
	for r in get_world_2d().direct_space_state.intersect_point(q, 16):
		var v := r.collider as Villager
		if v and v.is_alive() and (best == null or Gun.drawn_in_front(v, best)):
			best = v
	return best

func _on_island(p: Vector2) -> bool:
	var poly: Variant = get_parent().get("island_poly_global")
	return poly is PackedVector2Array and Geometry2D.is_point_in_polygon(p, poly)

func _draw() -> void:
	if not armed:
		return
	var m := get_global_mouse_position()
	var ready := _cooldown <= 0.0
	for pass_i in 2:
		var c := C_OUTLINE if pass_i == 0 else Color(C_AIM, 0.95 if ready else 0.4)
		draw_arc(m, 14.0, 0.0, TAU, 28, c, 3.5 if pass_i == 0 else 1.6, true)
	Manna.paint_bread(self, m + Vector2(0, -sin(_t * 3.0) * 2.0), 0.75)

## "Plin" suave: dos notas que bajan.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.5)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes := [880.0, 660.0]
	for j in notes.size():
		var start := int(rate * 0.09 * j)
		for i in range(start, n):
			var t := float(i - start) / rate
			var f: float = notes[j]
			buf[i] += sin(TAU * f * t) * exp(-t * 7.0) * minf(1.0, t * 300.0) * 0.3
	return Synth.wav(buf, rate, 1.0)
