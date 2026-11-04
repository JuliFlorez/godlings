extends Decoration
class_name Hut
## La choza: una decoración más (se dibuja, se coloca, se mueve y se quita como las otras, ver
## Decoration) con lo suyo. En las chozas viven los aldeanos (ver VillagerHome): de noche duermen
## adentro (con la puerta iluminada y unas zetas saliendo del techo) y de día entran cada tanto a
## descansar; las parejas que están adentro juntas cada tanto tienen un bebé (ver _try_birth).
## Arriba de la puerta tienen un cartel con el nombre que les pone el jugador (ver hut_name y
## HutCard), y el meteorito, el rayo y el tornado las rompen en pedacitos (ver smash).

## Los que viven ahí (ver residents), y una pareja que está adentro junta cada tanto tiene un
## bebé, si hay lugar en la choza y en la isla.
const BEDS := 4
const BIRTH_CHECK := 4.0            # Cada cuánto se fija
const BIRTH_CHANCE := 0.2           # Y la probabilidad cada vez
const LIGHT_SCALE := 0.5            # La luz de la puerta, de noche (más chica que la de la antorcha)
const LIGHT_ENERGY := 0.9
const NAME_MAX := 14                # Letras del nombre del cartel

## Lo que dice el cartel (lo escribe el jugador, ver HutCard).
var hut_name := "":
	set(v):
		hut_name = v
		queue_redraw()
var _glow := 0.0            # La puerta iluminada (alguien adentro, de noche)
var _door_light: PointLight2D
var _sleepers := 0          # Los que están adentro
var _birth_t := BIRTH_CHECK
var _hud: HUD               # Para saber si tiene el cartel abierto

func _init() -> void:
	kind = "hut"

func _ready() -> void:
	super()
	if ghost:
		return
	add_to_group("hut")   # Los aldeanos buscan dónde vivir
	_sky = get_tree().get_first_node_in_group("sky")
	_hud = get_tree().get_first_node_in_group("hud")
	# La puerta iluminada tiene que verse aunque la noche oscurezca todo
	_door_light = PointLight2D.new()
	_door_light.texture = _torch_light_texture()
	_door_light.texture_scale = LIGHT_SCALE
	_door_light.color = TORCH_LIGHT_COLOR
	_door_light.position = Vector2(0, LIFT - HUT_DOOR.y * 0.5 * HUT_SCALE)
	_door_light.enabled = false
	add_child(_door_light)

func _process(dt: float) -> void:
	super(dt)
	if not ghost:
		_update_hut(dt)

func _light_amount() -> float:
	return _glow

func _sign_text() -> String:
	return hut_name

func _draw_over() -> void:
	if _sleepers > 0 and _glow > 0.5:
		# Durmiendo: zetas que suben del techo
		var t := World.anim_time
		for i in 3:
			var k := fposmod(t * 0.4 + i / 3.0, 1.0)
			var c := Vector2(22.0 + k * 16.0 + sin(k * 6.0 + i) * 3.0, HUT_TOP * HUT_SCALE + 8.0 - k * 30.0)
			SpeechBubble._text(self, "z", c, 10.0 + k * 7.0, Color(1, 1, 1, 0.9 * (1.0 - k)))
	if not ghost and _hud and _hud.selected_hut() == self:
		# Con su cartel abierto (ver HutCard): una flechita arriba, como la del carnet
		var y := (HUT_CROSS.y + HUT_BONE.y) * HUT_SCALE - 12.0 - (0.5 + 0.5 * sin(World.anim_time * 6.0)) * NameTag.ARROW_BOB
		var tri := PackedVector2Array([Vector2(-NameTag.ARROW.x, y - NameTag.ARROW.y), Vector2(NameTag.ARROW.x, y - NameTag.ARROW.y), Vector2(0, y)])
		draw_colored_polygon(tri, UiStyle.C_XP)
		tri.append(tri[0])
		draw_polyline(tri, NameTag.C_OUTLINE, 2.0, true)

## El piso frente a la puerta, donde entra y sale el que vive ahí.
func door() -> Vector2:
	return global_position + Vector2(0, LIFT)

## El punto del piso que ocupa (del frente hasta HUT_DEPTH para atrás) más cerca de p.
## Para saber si la alcanzó el meteorito, el rayo o el tornado.
func footprint_point(p: Vector2) -> Vector2:
	var half := HUT_WALL.x * HUT_SCALE
	var base := door()
	return Vector2(clampf(p.x, base.x - half, base.x + half), clampf(p.y, base.y - HUT_DEPTH * HUT_SCALE, base.y))

## Se rompe en pedacitos que salen volando desde from (ver HutDebris), con fuerza force
## (px/s) y burnt (0..1) de chamuscados. Los que estaban adentro salen de golpe (y los alcanza
## lo que la rompió) y todos se quedan sin casa. No devuelve nada: hay que comprar otra.
## Mientras la mueven de lugar no le pasa nada.
func smash(from: Vector2, force: float, burnt := 0.0) -> void:
	if not is_in_group("hut") or moving or is_queued_for_deletion():
		return
	for v in residents():
		v.lose_home()
	remove_from_group("hut")
	HutDebris.burst(self, from, force, burnt)
	queue_free()

## Los que viven ahí (vivos).
func residents() -> Array[Villager]:
	var out: Array[Villager] = []
	for node in get_tree().get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.home == self and v.is_alive():
			out.append(v)
	return out

## Cuántos más entran.
func free_beds() -> int:
	return BEDS - residents().size()

## La puerta se ilumina de noche si hay alguien adentro, y cada tanto se fija si la
## pareja que está adentro tiene un bebé.
func _update_hut(dt: float) -> void:
	var inside := residents().filter(func(v: Villager): return v.inside)
	_sleepers = inside.size()
	var night: float = _sky.night if _sky else 0.0
	_glow = move_toward(_glow, 1.0 if _sleepers > 0 and night > 0.5 else 0.0, dt * 1.5)
	_door_light.enabled = _glow > 0.01
	_door_light.energy = LIGHT_ENERGY * _glow
	queue_redraw()
	_birth_t -= dt
	if _birth_t > 0.0:
		return
	_birth_t = BIRTH_CHECK
	_try_birth(inside)

## Una pareja adentro (los dos grandes, sin gripe ni muertos de hambre y sin bebé reciente),
## con lugar en la choza y en la isla: a veces tiene un bebé, que nace adentro y vive con ellos.
func _try_birth(inside: Array) -> void:
	var world := get_parent().get_parent() as World   # La choza está en Props, adentro de World
	if world == null or free_beds() < 1 or world.alive_villagers() >= world.capacity():
		return
	for i in inside.size():
		for j in range(i + 1, inside.size()):
			var a: Villager = inside[i]
			var b: Villager = inside[j]
			if Relations.kind(a, b) == Relations.Kind.COUPLE and a.can_have_baby() and b.can_have_baby() \
					and randf() < BIRTH_CHANCE:
				_birth(world, a, b)
				return

func _birth(world: World, a: Villager, b: Villager) -> void:
	var baby := world.add_villager(door())
	baby.set_age(0.0)
	baby.inherit_looks(a, b)   # Parecido a sus padres
	baby.parents.assign([a.id_number, b.id_number])
	baby.faith = (a.faith + b.faith) * 0.5   # Cree en vos como sus padres
	baby.fear = 0.0
	baby.hunger = 0.0
	var family := a.last_name if a.last_name != "" else b.last_name
	if family != "":
		baby.last_name = family   # Si no, el suyo, al azar
	baby.home = self
	baby.enter_home()   # Nace adentro
	for p: Villager in [a, b]:
		p.baby_cool = VillagerAge.BABY_COOLDOWN
	Relations.note_birth(a, b)
	Game.say("¡Nació un bebé!", get_global_transform_with_canvas().origin + Vector2(0, HUT_TOP * HUT_SCALE), Relations.color(Relations.Kind.COUPLE))
	for i in 4:
		var h := Coconut.Heart.new()
		get_parent().add_child(h)
		h.global_position = global_position + Vector2(randf_range(-16.0, 16.0), -20.0)
		h.delay = i * 0.15
