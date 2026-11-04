extends RefCounted
class_name VillagerHome
## La casa: cada uno se busca una choza donde vivir (ver Hut): con su pareja si tiene (en
## la de alguno de los dos, o en una con lugar para los dos) y si no, en cualquiera con lugar. De
## noche se van a dormir adentro hasta que se hace de día, y de día entran cada tanto a descansar un
## rato (las parejas, juntas). Adentro no se lo ve ni lo alcanza nada (ni rayos ni meteoritos ni la
## peste; ver Villager.inside); si le agarra hambre de verdad sale a comer. Las parejas que están
## adentro juntas a veces tienen un bebé (ver Hut._try_birth y VillagerAge.can_have_baby).
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (home, has_home, enter_home...).

const SLEEP_AT := 0.6             # Con la noche así de cerrada (ver Sky.night) se van a dormir...
const WAKE_AT := 0.4              # ...y salen cuando aclara
const REST_EVERY := Vector2(70.0, 140.0)   # De día, cada cuánto entran a descansar...
const REST_INSIDE := Vector2(12.0, 25.0)   # ...y lo que se quedan
const HOME_CHECK := 2.0           # Cada cuánto se fija dónde vivir
const HOME_REACH := 6.0
const HOME_GIVE_UP := 15.0        # Si no llega a la puerta en este tiempo, lo deja
var home: Hut                     # Su choza (null: sin casa)
var going_home := false            # Va caminando a su choza (ver walk_home)
var _home_t := 0.0
var _inside_t := 0.0
var _rest_t := 0.0
var _home_check := 0.0

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	_rest_t = randf_range(REST_EVERY.x, REST_EVERY.y)
	_home_check = randf_range(0.0, HOME_CHECK)

## Su choza sigue estando (no la quitaron).
func has_home() -> bool:
	return is_instance_valid(home) and home.is_in_group("hut") and not home.is_queued_for_deletion()

func can_go_home() -> bool:
	return has_home() and not going_home and v.is_idle() and not v.on_fire and v.food == null \
			and v.chat_with == null and v._flee <= 0.0 and v._scram <= 0.0 and v.pose == VillagerFaith.Pose.NONE \
			and v.hunger < VillagerHunger.HUNGRY_AT and not home.moving and not v.is_zombie()

func go_home() -> void:
	going_home = true
	_home_t = 0.0
	_rest_t = randf_range(REST_EVERY.x, REST_EVERY.y) * (VillagerMood.MOOD_SAD_HOME if v.is_sad() else 1.0)
	v._resting = false

## Entra a su choza: no se lo ve ni lo alcanza nada hasta que sale.
func enter_home() -> void:
	v.inside = true
	going_home = false
	v.visible = false
	v.get_node("CollisionShape2D").set_deferred("disabled", true)
	v.velocity = Vector2.ZERO
	_inside_t = randf_range(REST_INSIDE.x, REST_INSIDE.y)
	if v.chat_with:
		v.end_chat()
	if v.food:
		v.food.release_eater()

## Sale por la puerta (o donde estaba, si le quitaron la choza).
func leave_home() -> void:
	v.inside = false
	v._sleep.left_home()
	v.visible = true
	v.get_node("CollisionShape2D").set_deferred("disabled", false)
	if has_home():
		v.global_position = _door_spot() + Vector2(0, 4)
	_rest_t = randf_range(REST_EVERY.x, REST_EVERY.y) * (VillagerMood.MOOD_SAD_HOME if v.is_sad() else 1.0)
	v.dir = Vector2(randf_range(-0.8, 0.8), 1.0).normalized()
	v._update_sprite_flip()
	v._walk = 0.0
	v._heading = Vector2.ZERO
	v.wander_timer = randf_range(1.5, 3.0)

## Le rompieron la choza (ver Hut.smash): si estaba adentro sale de golpe, y se queda
## sin casa (después se busca otra).
func lose_home() -> void:
	if v.inside:
		leave_home()
	home = null
	v.add_mood(VillagerMood.MOOD_LOST_HOME, "Le rompieron la casa")

## Cada tanto se fija dónde vivir (ver _update_home).
func update(dt: float) -> void:
	if not v.is_alive():
		return
	_home_check -= dt
	if _home_check <= 0.0:
		_home_check = HOME_CHECK
		_update_home()

## De noche, o de día cada tanto, se va a su choza (si está tranquilo y sin hambre de verdad).
## Las parejas que viven juntas se van juntas.
func seek_home(dt: float) -> void:
	_rest_t -= dt
	if not can_go_home():
		return
	if v._night() >= SLEEP_AT or _rest_t <= 0.0:
		go_home()
		var p := _partner()
		if p and p.home == home and p.can_go_home():
			p.go_home()

## Camina hasta la puerta de su choza y entra. false si ya no va.
func walk_home(dt: float) -> bool:
	if not has_home() or not v.is_idle() or home.moving:
		going_home = false
		return false
	_home_t += dt
	if _home_t > HOME_GIVE_UP:
		going_home = false
		return false
	var to := _door_spot() - v.global_position
	if to.length() <= HOME_REACH:
		going_home = false
		enter_home()
		return true
	v.dir = to.normalized()
	v._update_sprite_flip()
	v.velocity = (v.dir * v.speed + v.shove_vel).limit_length(maxf(to.length() / dt, v.shove_vel.length()))
	var prev_pos := v.global_position
	v.move_and_slide()
	if v.island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(v.global_position, v.island_poly):
		if v.shove_timer > 0.0:
			going_home = false
			v._fall_from_shove()
			return true
		v.global_position = prev_pos
		if to.length() < 30.0:   # La puerta queda en la orilla: entra desde ahí
			going_home = false
			enter_home()
	return true

## Adentro: se queda hasta que se hace de día (o, de día, hasta que descansó), o hasta que le
## agarra hambre de verdad. Si le quitaron la choza, sale.
func inside_ai(dt: float) -> void:
	v.velocity = Vector2.ZERO
	if v.is_zombie():
		leave_home()   # Se hizo zombi adentro: sale (ver _spore_turned)
		return
	if not has_home():
		leave_home()
		home = null
		return
	v.global_position = _door_spot()   # Si mueven la choza, va con ella
	_inside_t -= dt
	# De día sale cuando descansó (de la noche, o de la siesta: ahí no importa _inside_t)
	var rested := v._sleep.rested()
	if v.hunger >= VillagerHunger.HUNGRY_AT or (v._night() < WAKE_AT and rested and (_inside_t <= 0.0 or v._sleep.napping)):
		if v._sleep.slept_inside and v.hunger < VillagerHunger.HUNGRY_AT:
			v.add_mood(VillagerSleep.MOOD_SLEPT_WELL, "Durmió bien")
		leave_home()

## Su pareja (viva), o null.
func _partner() -> Villager:
	var id := Relations.partner_id(v)
	if id == 0:
		return null
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o.id_number == id and o.is_alive():
			return o
	return null

## Dónde vivir: con su pareja (en la choza de alguno de los dos, si hay lugar, o en una con
## lugar para los dos) y si no, en cualquier choza con lugar. Adentro no se muda.
func _update_home() -> void:
	if home and not has_home():
		home = null
	if v.inside:
		return
	var p := _partner()
	if p and p.home != home:
		if p.has_home() and p.home.free_beds() >= 1:
			home = p.home
		elif home and home.free_beds() >= 1 and not p.inside:
			p.home = home
		elif not p.inside:
			var h := _free_hut(2)
			if h:
				home = h
				p.home = h
		return
	if home == null:
		home = _free_hut(1)

## La choza más cerca con al menos beds lugares libres, o null.
func _free_hut(beds: int) -> Hut:
	var best: Hut = null
	var best_d := INF
	for node in v.get_tree().get_nodes_in_group("hut"):
		var h := node as Hut
		var d := h.door().distance_to(v.global_position)
		if h and not h.moving and h.free_beds() >= beds and d < best_d:
			best = h
			best_d = d
	return best

## Dónde se para para entrar: con los pies en la puerta.
func _door_spot() -> Vector2:
	return home.door() - Vector2(0, (Villager.FEET - 2.0) * v.scale.y)
