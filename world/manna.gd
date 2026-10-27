extends Food
class_name Manna
## Pan que les tirás (ver Feed): baja del cielo brillando hasta donde hiciste click, y en el
## piso se lo viene a comer el que tenga hambre. Si se lo tiraste a alguien es para él: se lo
## come aunque no tenga tanta hambre. Como es un milagro, al que se lo come le sube la fe. Si
## nadie lo come, al rato se desvanece.
## Como los cocos, el origen del nodo queda LIFT px arriba del pan, así el orden por Y es parejo
## con los aldeanos.

enum State { FALLING, GROUND, FADING }

const LIFT := 24.0
const FALL_FROM := 320.0         # Aparece así de alto arriba de donde cae
const GRAVITY := 900.0
const LIFE := 120.0              # En el piso, hasta desvanecerse si nadie se lo come
const NUTRITION := 45.0
const FAITH := 6.0               # Lo que le sube la fe al que se lo come
const BITES := 3
const C_CRUST := Color(0.85, 0.55, 0.22)
const C_CRUST_DARK := Color(0.55, 0.3, 0.1)
const C_CRUST_LIGHT := Color(0.98, 0.78, 0.42)
const C_GLOW := Color(1.0, 0.9, 0.55)

var state := State.FALLING
var meant_for: Villager          # Al que se lo tiraste (o null)
var _floor_y := 0.0
var _vy := 0.0
var _t := 0.0
var _bites := 0

func _init() -> void:
	nutrition = NUTRITION

func _ready() -> void:
	add_to_group("food")
	z_index = 10   # Cayendo, por delante de todo

func point() -> Vector2:
	return global_position + Vector2(0, LIFT)

func set_point(p: Vector2) -> void:
	global_position = p - Vector2(0, LIFT)

## Lo larga desde arriba para que caiga en p (el piso).
func drop_at(p: Vector2) -> void:
	_floor_y = p.y
	set_point(p - Vector2(0, FALL_FROM))

func available() -> bool:
	return is_free() and state == State.GROUND

func _process(dt: float) -> void:
	check_eater()
	_t += dt
	match state:
		State.FALLING:
			_vy += GRAVITY * dt
			var p := point() + Vector2(0, _vy * dt)
			if p.y >= _floor_y:
				p.y = _floor_y
				set_point(p)
				_land()
			else:
				set_point(p)
		State.GROUND:
			if _t > LIFE and is_free():
				state = State.FADING
		State.FADING:
			modulate.a -= dt
			if modulate.a <= 0.02:
				queue_free()
	queue_redraw()

func _land() -> void:
	state = State.GROUND
	z_index = 0
	_t = 0.0
	_sparkles(point(), 14)
	# Si se lo tiraste a alguien, se lo come él
	if not is_instance_valid(meant_for):
		return
	var v := meant_for
	if not v.dead and v.food == null and v.chat_with == null and v.is_idle() and not v.on_fire:
		v.go_eat(self)

func nibble(progress: float) -> void:
	var b := clampi(floori(progress * BITES), 0, BITES - 1)
	if b > _bites:
		_bites = b
		_sparkles(point(), 4, C_CRUST_LIGHT)

## Comida del cielo: además de sacarle el hambre, le sube la fe.
func finish_eating(v: Villager) -> void:
	v.add_faith(FAITH)
	v.add_mood(Villager.MOOD_MANNA, "Le mandaste comida del cielo")
	v.say(Villager.Bubble.HEART, 1.4, false)
	_sparkles(point(), 10)
	super(v)

func _sparkles(at: Vector2, amount: int, color := C_GLOW) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.z_index = 11
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)

func _draw() -> void:
	var c := Vector2(0, LIFT)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	if state == State.FALLING:
		# Baja con un halo y una estela de luz
		draw_line(c + Vector2(0, -40), c, Color(C_GLOW, 0.35), 6.0, true)
		draw_circle(c, 16.0, Color(C_GLOW, 0.3), true, -1.0, true)
	else:
		draw_set_transform(c + Vector2(0, 6), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 16.0 + pulse * 3.0, Color(C_GLOW, 0.25), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(Coconut._ellipse(c + Vector2(0, 6), 12.0, 3.5), Color(0, 0, 0, 0.18))
	paint_bread(self, c, 1.0 - 0.25 * _bites)

## Un pan dorado con tres cortes, centrado en c (s: escala; 1 mide unos 22 px de ancho).
static func paint_bread(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_colored_polygon(Coconut._ellipse(c, 11.5 * s, 7.0 * s), C_CRUST_DARK)
	ci.draw_colored_polygon(Coconut._ellipse(c + Vector2(0, -1.0) * s, 10.5 * s, 5.8 * s), C_CRUST)
	ci.draw_colored_polygon(Coconut._ellipse(c + Vector2(-2.0, -3.0) * s, 6.0 * s, 2.0 * s), C_CRUST_LIGHT)
	for x: float in [-5.0, 0.0, 5.0]:
		ci.draw_line(c + Vector2(x - 2.0, 2.5) * s, c + Vector2(x + 2.0, -3.5) * s, C_CRUST_DARK, maxf(1.0, 1.4 * s), true)
