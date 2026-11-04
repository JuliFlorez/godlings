extends RefCounted
class_name VillagerAge
## La edad: nace chiquito y crece hasta ser grande (ADULT_AGE); de chico no se pone de novio ni tiene
## hijos. Los que invocás ya son grandes (SPAWN_AGE). Con los días le salen canas, cada uno a su edad
## (ver greyness y waterline.gdshader), y de viejo (ELDER_AGE) se encorva y se achica un poco, camina
## más despacio arrastrando los pies, se cansa antes, se para más seguido y ya no tiene hijos. Cada
## uno vive lo suyo (lifespan): cuando le llega la hora, parado en la isla (o durmiendo, y ahí ni se
## despierta), se muere de viejo. La edad son los días vividos: pasan con los del cielo (ver
## Sky.passed; si adelantás el sol o la luna, también). También dice si puede tener un bebé (ver
## can_have_baby y Hut._try_birth). Se ve en el carnet y se guarda con la partida.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (age, is_child, set_age...).

const ADULT_AGE := 2.0                            # A los 2 días ya es grande
const BABY_SIZE := 0.5                            # El tamaño al nacer (veces el de un grande)
const SPAWN_AGE := Vector2(2.0, 4.0)              # Los que invocás (y los de la partida nueva)
const ELDER_AGE := 7.0                            # Desde acá es viejo (y en ELDER_DAYS, bien viejo)...
const ELDER_DAYS := 1.5
const LIFESPAN := Vector2(8.0, 10.0)              # ...y se muere de viejo entre los 8 y los 10 días
const GREY_AGE := Vector2(4.0, 6.0)               # Le empiezan a salir canas (a los hijos, como a alguno de los padres)...
const GREY_DAYS := 3.5                            # ...y en estos días le queda todo el pelo blanco
const ELDER_SHRINK := 0.94                        # Bien viejo es un poco más bajo (veces su altura)
const ELDER_SPEED := 0.75                         # Viejo camina más despacio...
const ELDER_REST := 0.55                          # ...se para más seguido...
const ELDER_TIRED := 1.3                          # ...y se cansa más rápido
const BABY_COOLDOWN := 180.0                      # Después de tener un bebé, lo que tarda una pareja en tener otro
var age := ADULT_AGE                  # Días vividos
var lifespan := LIFESPAN.x            # A los cuántos días se muere de viejo
var grey_age := GREY_AGE.x            # A los cuántos días le empiezan a salir canas
var baby_cool := 0.0                  # Lo que le falta para poder tener otro bebé

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	age = randf_range(SPAWN_AGE.x, SPAWN_AGE.y)   # Los bebés y las partidas guardadas traen la suya
	lifespan = randf_range(LIFESPAN.x, LIFESPAN.y)
	grey_age = randf_range(GREY_AGE.x, GREY_AGE.y)

## Para la partida guardada (ver Villager.to_dict): los días vividos, a los cuántos se muere de
## viejo y a los cuántos le salen canas.
func to_dict() -> Dictionary:
	return {"days": age, "lifespan_days": lifespan, "grey_days": grey_age}

## Sigue como se guardó, con el tamaño y las canas que le tocan (ver set_age). Las partidas de antes
## tenían la edad en segundos (años de 20 s): pasa a días en la misma etapa de la vida (los 15 años
## de grande son los ADULT_AGE días de ahora).
func from_dict(d: Dictionary) -> void:
	var days := age   # Si no trae la suya, la que le tocó al crearlo
	if d.has("days"):
		days = d.days
		lifespan = d.get("lifespan_days", lifespan)
		grey_age = d.get("grey_days", grey_age)
	elif d.has("age"):
		var to_days := ADULT_AGE / (15.0 * 20.0)
		if d.has("lifespan"):
			days = d.age * to_days
			lifespan = d.lifespan * to_days
			grey_age = clampf(d.get("grey_age", 0.0) * 20.0 * to_days, GREY_AGE.x, GREY_AGE.y)
		elif d.age < 15.0 * 20.0:
			days = d.age * to_days   # Y antes los grandes no envejecían: los chicos sí traen la suya
	set_age(days)

## Todavía es chico (ver ADULT_AGE).
func is_child() -> bool:
	return age < ADULT_AGE

## Ya es viejo (ver ELDER_AGE).
func is_elder() -> bool:
	return age >= ELDER_AGE

## Cuántos días enteros vivió.
func days() -> int:
	return int(age)

## Qué tan viejo está: 0 hasta ELDER_AGE, 1 ELDER_DAYS después (bien encorvado, ver VillagerRig).
func oldness() -> float:
	return clampf((age - ELDER_AGE) / ELDER_DAYS, 0.0, 1.0)

## Cuántas canas tiene: 0 ninguna .. 1 el pelo todo blanco (ver GREY_AGE y waterline.gdshader).
func greyness() -> float:
	return clampf((age - grey_age) / GREY_DAYS, 0.0, 1.0)

## Grande (y no viejo), sano (sin gripe ni espora), no muerto de hambre, más o menos contento y
## sin un bebé reciente.
func can_have_baby() -> bool:
	return not is_child() and not is_elder() and not v.dead and not v.is_sick() and not v.starving() \
			and baby_cool <= 0.0 and v.mood >= VillagerMood.MOOD_BABY_AT and v.spore <= 0.0

## La edad (al pasar los días, al nacer y al cargar la partida), con el tamaño que le toca (con su
## altura) y sus canas.
func set_age(a: float) -> void:
	age = a
	var grow := lerpf(BABY_SIZE, 1.0, clampf(age / ADULT_AGE, 0.0, 1.0))
	v.scale = Vector2.ONE * grow * lerpf(1.0, ELDER_SHRINK, oldness()) * v.height
	if v._waterline:
		v._waterline.set_shader_parameter("grey", greyness())

## Le pasan los días (de chico crece; de grande le salen canas y de viejo se achica) y, si le
## llegó la hora, se muere de viejo. Se le va pasando lo del último bebé.
func update(dt: float) -> void:
	if not v.is_alive():
		return
	baby_cool = maxf(0.0, baby_cool - dt)
	var was_child := is_child()
	var sky := v.get_tree().get_first_node_in_group("sky")
	if sky and sky.passed > 0.0:
		set_age(age + sky.passed)
	if was_child and not is_child():
		if v.visible:
			Game.say("¡Ya es grande!", v.get_global_transform_with_canvas().origin + Vector2(0, -80), UiStyle.C_SHOP)
	# Termina parado en la isla (o durmiendo): no se muere colgando del mouse, flotando ni adentro
	if age >= lifespan and (v.is_idle() or v.asleep) and not v.on_fire:
		_die_of_old_age()

## Le llegó la hora: se muere tranquilo donde está (si estaba durmiendo, ni se despierta).
func _die_of_old_age() -> void:
	Game.say("Murió de vieja" if v.gender == Villager.Gender.FEMALE else "Murió de viejo",
			v.get_global_transform_with_canvas().origin + Vector2(0, -80), UiStyle.C_MUTED)
	if v.food:
		v.food.release_eater()
	v._gentle_death = true
	v._old_age_death = true
	var lying := v.asleep
	v._die()
	if not lying:
		v.swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.0, 3.0)   # Se cae para un costado, despacito
		v.corpse_vel = Vector2.ZERO
