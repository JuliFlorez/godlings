extends RefCounted
class_name VillagerHunger
## El hambre y la comida: el hambre (0 lleno, 100 la panza vacía) les va subiendo. Con un poco ya
## comen lo que tengan cerca, y con hambre de verdad salen a buscar por toda la isla (y lo dicen con
## un globito): un medio coco tirado, el pan que les tirás o las bayas de un arbusto (ver Food).
## Muertos de hambre caminan más lento, no rezan, se enojan charlando y te creen cada vez menos; con
## la panza vacía aguantan un rato y se mueren. Se ve en el carnet y se guarda.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (hunger, food, feed...).

const HUNGER_RATE := 0.2         # Por segundo: de lleno a la panza vacía en algo más de 8 minutos
const HUNGER_START := Vector2(5.0, 35.0)
const SNACK_AT := 20.0           # Con esto ya come si tiene algo cerca...
const SNACK_REACH := 220.0
const HUNGRY_AT := 50.0          # ...y con esto sale a buscar por toda la isla (y lo dice)
const STARVING_AT := 85.0        # Muerto de hambre
const STARVING_SPEED := 0.7      # Veces speed
const STARVE_TIME := 60.0        # Con la panza vacía aguanta esto
const FAITH_DRIFT_STARVING := 0.1   # Fe que pierde de más por segundo, muerto de hambre
const HUNGRY_SAY_EVERY := Vector2(8.0, 14.0)
const FOOD_SEEK_EVERY := 0.6
const FOOD_SPEED := 1.8          # Van a la comida más rápido que cuando pasean
const EAT_REACH := 6.0
const EAT_TIME := 1.8
const FOOD_GIVE_UP := 10.0       # Si no llega en este tiempo (trabado en el borde), la deja
const FOOD_COOLDOWN := 5.0       # ...y por un rato no busca otra
var hunger := 0.0
var food: Food
var eat_t := 0.0
var _food_t := 0.0
var _food_cooldown := 0.0
var _food_seek := 0.0
var _starve_t := 0.0
var _hungry_say := 0.0

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	hunger = randf_range(HUNGER_START.x, HUNGER_START.y)
	_hungry_say = randf_range(HUNGRY_SAY_EVERY.x, HUNGRY_SAY_EVERY.y)

## Para la partida guardada (ver Villager.to_dict).
func to_dict() -> Dictionary:
	return {"hunger": hunger}

func from_dict(d: Dictionary) -> void:
	hunger = d.get("hunger", hunger)

## Muerto de hambre (ver STARVING_AT).
func starving() -> bool:
	return hunger >= STARVING_AT and not v.dead

## Con hambre (aunque sea un poco), libre y tranquilo en la isla.
func wants_food() -> bool:
	return food == null and v.chat_with == null and v.is_idle() and not v.on_fire and _food_cooldown <= 0.0 \
			and hunger >= SNACK_AT and not v.going_home and not v.is_zombie()

## Comió: se le va el hambre.
func feed(amount: float) -> void:
	v.add_mood(minf(amount, hunger) * VillagerMood.MOOD_ATE)
	hunger = maxf(0.0, hunger - amount)
	_starve_t = 0.0

## Va a comerse f (lo reserva, así no va otro).
func go_eat(f: Food) -> void:
	food = f
	f.claim(v)
	eat_t = 0.0
	_food_t = 0.0
	v._resting = false

func stop_eating() -> void:
	food = null
	eat_t = 0.0
	if v.rig:
		v.rig.position = v._rig_rest

## Volvió a la vida (ver Villager._come_back): con la panza casi llena (Villager.RISEN_HUNGER).
func heal() -> void:
	hunger = minf(hunger, Villager.RISEN_HUNGER)
	_starve_t = 0.0

## Se le va pasando el rato sin buscar comida después de rendirse (ver FOOD_GIVE_UP). Lo llama el
## aldeano en su _physics_process.
func cool_down(dt: float) -> void:
	_food_cooldown = maxf(0.0, _food_cooldown - dt)

## Le sube el hambre; con hambre lo dice cada tanto, y con la panza vacía aguanta un rato
## (parado en la isla, como con la gripe) y se muere.
func update(dt: float) -> void:
	if not v.is_alive() or v.is_zombie():
		return   # (El zombi no tiene hambre: lo alimenta el hongo)
	hunger = minf(100.0, hunger + HUNGER_RATE * dt)
	if hunger < 100.0:
		_starve_t = 0.0
	elif (v.is_idle() or v.asleep) and not v.on_fire:
		_starve_t += dt
		if _starve_t >= STARVE_TIME:
			_die_of_hunger()
			return
	if hunger >= HUNGRY_AT and food == null:
		_hungry_say -= dt * (2.0 if starving() else 1.0)
		if _hungry_say <= 0.0:
			_hungry_say = randf_range(HUNGRY_SAY_EVERY.x, HUNGRY_SAY_EVERY.y)
			if v.chat_with == null and v.bubble_t <= 0.0 and v.is_idle():
				v.say(Villager.Bubble.HUNGRY, 1.6, false)

## Con hambre, busca lo más cerca para comer: algo tirado (un medio coco, el pan que le
## tiraste) o una baya de un arbusto. Con poca hambre, solo si está cerca.
func seek_food(dt: float) -> void:
	if not wants_food():
		return
	_food_seek -= dt
	if _food_seek > 0.0:
		return
	_food_seek = FOOD_SEEK_EVERY
	var best_d := INF if hunger >= HUNGRY_AT else SNACK_REACH
	var best: Food = null
	var bush: Decoration = null
	for node in v.get_tree().get_nodes_in_group("food"):
		var f := node as Food
		if f and f.available() and f.point().distance_to(v.global_position) < best_d:
			best = f
			best_d = f.point().distance_to(v.global_position)
	for node in v.get_tree().get_nodes_in_group("berry_bush"):
		var b := node as Decoration
		var d := b.global_position.distance_to(v.global_position)
		if b.free_berry() >= 0 and d < best_d:
			bush = b
			best_d = d
	if bush:
		best = bush.pick_berry()
	if best:
		go_eat(best)

## Camina hasta su comida y se la come. false si ya no tiene.
func food_ai(dt: float) -> bool:
	if not is_instance_valid(food) or food.eater != v:
		stop_eating()
		return false
	var to := food.eat_spot(v) - v.global_position
	if eat_t > 0.0 or to.length() <= EAT_REACH:
		# Comiendo: quieto, mirando la comida y masticando
		v.velocity = Vector2.ZERO
		if v.rig:
			v.rig.set_facing_left(food.point().x < v.global_position.x)
			v.rig.position = v._rig_rest + Vector2(0, -absf(sin(eat_t * 12.0)) * 2.5)
		eat_t += dt
		food.nibble(eat_t / EAT_TIME)
		if eat_t >= EAT_TIME:
			var f := food
			stop_eating()
			f.finish_eating(v)
			v._pick_dir()
			v.wander_timer = randf_range(1.5, 3.0)
		return true

	_food_t += dt
	if _food_t > FOOD_GIVE_UP:
		food.release_eater()
		_food_cooldown = FOOD_COOLDOWN
		return false
	v.dir = to.normalized()
	v._update_sprite_flip()
	v.velocity = (v.dir * v.speed * FOOD_SPEED + v.shove_vel).limit_length(maxf(to.length() / dt, v.shove_vel.length()))
	var prev_pos := v.global_position
	v.move_and_slide()
	if v.island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(v.global_position, v.island_poly):
		if v.shove_timer > 0.0:
			v._fall_from_shove()
			return true
		v.global_position = prev_pos
		# El lugar para comer queda fuera de la isla: come estirándose desde el borde
		if to.length() < 24.0:
			eat_t = 0.001
	return true

func _die_of_hunger() -> void:
	Game.say("Murió de hambre", v.get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
	if food:
		food.release_eater()
	v._gentle_death = true
	v._die()
	v.swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.5, 4.0)   # Se cae para un costado
	v.corpse_vel = Vector2.ZERO
