extends RefCounted
class_name VillagerChat
## Las charlas: cada tanto, dos que andan cerca y con ganas se juntan a charlar un rato. El que la
## empieza va hasta el lado del otro, se miran y hablan por turnos (con un globito arriba de la
## cabeza y un bla-bla con su voz, ver Villager.say). Según cómo les fue se quieren más o menos (ver
## Relations): así se hacen amigos, enemigos o pareja, y los enemigos a veces terminan a los
## empujones. Se ve en el carnet.
## Charlar es de a dos: lo que hace falta del lado del otro va por lo que reenvía su aldeano
## (join_chat, leave_chat, can_chat...).
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (chat_with, end_chat...).

const CHAT_EVERY := Vector2(12.0, 25.0) # Después de una charla, hasta tener ganas de otra
const CHAT_SEEK := 130.0                # Hasta dónde busca con quién charlar
const CHAT_SEEK_EVERY := 0.5
const CHAT_GAP := 40.0                  # Charlando, uno al lado del otro (entre centros)
const CHAT_REACH := 3.0
const CHAT_APPROACH := 5.0              # Si no llega al lado del otro en este tiempo, lo deja
const CHAT_TURNS := Vector2i(3, 6)
const CHAT_TURN := Vector2(0.8, 1.2)    # Lo que dura el globito de cada uno
const CHAT_PAUSE := 0.3                 # Entre un turno y otro
const CHAT_MOOD := 3.0                  # Ganando o perdiendo más que esto, se les nota
const FIGHT_CHANCE := 0.5               # Enemigos que se pelearon: alguno empuja al otro
var chat_with: Villager
var _chat_lead := false                 # La empezó él: la lleva él
var _chat_talking := false              # Ya están uno al lado del otro (si no, va yendo)
var _chat_t := 0.0
var _chat_turn := 0
var _chat_len := 0
var _chat_delta := 0.0                  # Cómo les va a ir (ver Relations.chat_delta)
var _chat_cool := 0.0                   # Hasta tener ganas de charlar
var _chat_seek := 0.0

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	_chat_cool = randf_range(2.0, CHAT_EVERY.y)

## Tranquilo en la isla: sin quemarse, asustarse, comer, escaparse del agua o de tu mano, ni
## rezarte o agacharse de miedo.
func can_chat() -> bool:
	return v.is_idle() and not v.on_fire and not v.is_scared() and v._flee <= 0.0 and v.food == null \
			and v._scram <= 0.0 and v.pose == VillagerFaith.Pose.NONE and not v.going_home and not v.is_zombie()

func wants_chat() -> bool:
	return chat_with == null and _chat_cool <= 0.0 and can_chat()

## El otro lo invitó a charlar (ver _start_chat): la lleva el otro.
func join_chat(o: Villager) -> void:
	chat_with = o
	_chat_lead = false

## El otro cortó la charla (ver end_chat): un rato sin ganas de otra.
func leave_chat() -> void:
	chat_with = null
	_chat_cool = randf_range(CHAT_EVERY.x, CHAT_EVERY.y)

## Se terminó (o se cortó) la charla: un rato sin ganas de otra, los dos.
func end_chat() -> void:
	var o := chat_with
	chat_with = null
	_chat_cool = randf_range(CHAT_EVERY.x, CHAT_EVERY.y)
	if is_instance_valid(o) and o.chat_with == v:
		o.leave_chat()

## Para la consola de trucos (ver DebugConsole._simulate_chats): ya tiene ganas de charlar.
func clear_chat_cool() -> void:
	_chat_cool = 0.0

## Cada frame (lo llama el aldeano): se le va pasando el rato sin ganas de charlar (ver CHAT_EVERY).
func update(dt: float) -> void:
	_chat_cool = maxf(0.0, _chat_cool - dt)

## Con ganas de charlar, busca a alguien cerca que también tenga ganas: más seguido a su
## pareja y sus amigos, poco a sus enemigos.
func seek_chat(dt: float) -> void:
	if not wants_chat():
		return
	_chat_seek -= dt
	if _chat_seek > 0.0:
		return
	_chat_seek = CHAT_SEEK_EVERY
	var best: Villager
	var best_w := 0.0
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or not o.wants_chat():
			continue
		var d := o.global_position.distance_to(v.global_position)
		if d > CHAT_SEEK:
			continue
		var w := Relations.chat_weight(v, o) * (1.5 - d / CHAT_SEEK) * randf()
		if w > best_w:
			best = o
			best_w = w
	if best:
		_start_chat(best)

func _start_chat(o: Villager) -> void:
	chat_with = o
	_chat_lead = true
	o.join_chat(v)
	_chat_talking = false
	_chat_t = 0.0
	_chat_turn = 0
	_chat_len = randi_range(CHAT_TURNS.x, CHAT_TURNS.y)
	_chat_delta = Relations.chat_delta(v, o)

## Charlando con chat_with: el que la empezó va hasta el lado del otro, y ahí se quedan
## mirándose y hablando por turnos (lo lleva el que la empezó). false si se cortó.
func chat_ai(dt: float) -> bool:
	var o := chat_with
	if not is_instance_valid(o) or o.chat_with != v or not can_chat() or not o.can_chat():
		end_chat()
		return false
	if not _chat_lead:
		v._stand_facing(o)   # Espera (o charla) parado, mirándolo
		return true
	if not _chat_talking:
		_chat_t += dt
		if _chat_t > CHAT_APPROACH:
			end_chat()
			return false
		if _walk_to_chat(o, dt):
			_chat_talking = true
			_chat_t = CHAT_PAUSE
		return true
	v._stand_facing(o)
	_chat_t -= dt
	if _chat_t > 0.0:
		return true
	if _chat_turn >= _chat_len:
		_finish_chat(o)
		return true
	# Hablan por turnos: primero el que la empezó
	var speaker: Villager = v if _chat_turn % 2 == 0 else o
	_chat_turn += 1
	var time := randf_range(CHAT_TURN.x, CHAT_TURN.y)
	speaker.say(_chat_topic(o), time)
	_chat_t = time + CHAT_PAUSE
	return true

## Va caminando hasta quedar al lado del otro (del lado de donde viene; si ahí no hay isla,
## del otro). true al llegar.
func _walk_to_chat(o: Villager, dt: float) -> bool:
	var side := 1.0 if v.global_position.x >= o.global_position.x else -1.0
	var spot := o.global_position + Vector2(CHAT_GAP * side, 0.0)
	if v.island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(spot, v.island_poly):
		spot = o.global_position - Vector2(CHAT_GAP * side, 0.0)
	var to := spot - v.global_position
	if to.length() <= CHAT_REACH:
		return true
	v.dir = to.normalized()
	v._update_sprite_flip()
	v.velocity = (v.dir * v.speed + v.shove_vel).limit_length(maxf(to.length() / dt, v.shove_vel.length()))
	var prev_pos := v.global_position
	v.move_and_slide()
	if v.island_poly.size() > 0 and not Geometry2D.is_point_in_polygon(v.global_position, v.island_poly):
		if v.shove_timer > 0.0:
			v._fall_from_shove()
			return false
		v.global_position = prev_pos
		# Trabado en la orilla: si ya está cerca, charlan desde ahí
		return v.global_position.distance_to(o.global_position) < CHAT_GAP * 1.8
	return false

## De qué habla: según lo que son y si la charla viene bien o mal.
func _chat_topic(o: Villager) -> Villager.Bubble:
	if v.mood_level() == VillagerMood.Mood.DEPRESSED and randf() < 0.4:
		return [Villager.Bubble.TEAR, Villager.Bubble.DOTS].pick_random()   # Deprimido no tiene ganas de nada
	var bad := _chat_delta < -CHAT_MOOD and randf() < 0.6
	match Relations.kind(v, o):
		Relations.Kind.COUPLE:
			if bad:
				return Villager.Bubble.ANGER
			return [Villager.Bubble.HEART, Villager.Bubble.HEART, Villager.Bubble.MUSIC, Villager.Bubble.LAUGH].pick_random()
		Relations.Kind.FRIEND:
			if bad:
				return [Villager.Bubble.ANGER, Villager.Bubble.EXCLAIM].pick_random()
			return [Villager.Bubble.LAUGH, Villager.Bubble.LAUGH, Villager.Bubble.MUSIC, Villager.Bubble.SUN, Villager.Bubble.EXCLAIM].pick_random()
		Relations.Kind.ENEMY:
			if bad or randf() < 0.5:
				return Villager.Bubble.ANGER
			return [Villager.Bubble.EXCLAIM, Villager.Bubble.QUESTION].pick_random()
	if bad:
		return [Villager.Bubble.ANGER, Villager.Bubble.EXCLAIM, Villager.Bubble.QUESTION].pick_random()
	return [Villager.Bubble.DOTS, Villager.Bubble.QUESTION, Villager.Bubble.SUN, Villager.Bubble.EXCLAIM, Villager.Bubble.MUSIC, Villager.Bubble.LAUGH].pick_random()

## Terminó la charla: se quieren más o menos según cómo les fue, lo muestran con una cara (y
## si cambió lo que son, con un cartel), y cada uno sigue con lo suyo.
func _finish_chat(o: Villager) -> void:
	var ev := Relations.change(v, o, _chat_delta)
	var k := Relations.kind(v, o)
	if absf(_chat_delta) > CHAT_MOOD:   # Cómo les fue también les cambia el ánimo
		var why := "Charló lindo" if _chat_delta > 0.0 else "Discutió"
		v.add_mood(_chat_delta * VillagerMood.MOOD_CHAT, why)
		o.add_mood(_chat_delta * VillagerMood.MOOD_CHAT, why)
	var face := Villager.Bubble.NONE
	if ev == Relations.Event.BROKE_UP:
		face = Villager.Bubble.TEAR
	elif _chat_delta > CHAT_MOOD:
		face = Villager.Bubble.HEART if k == Relations.Kind.COUPLE else Villager.Bubble.SMILE
	elif _chat_delta < -CHAT_MOOD:
		face = Villager.Bubble.ANGER
	if face != Villager.Bubble.NONE:
		v.say(face, Villager.REACT_TIME, false)
		o.say(face, Villager.REACT_TIME, false)
	var n := Relations.news(ev)
	var news: String = n[0]
	var color: Color = n[1]
	# Los enemigos que se pelearon a veces terminan a los empujones
	# (más si andan tristes)
	if k == Relations.Kind.ENEMY and _chat_delta < 0.0 and randf() < FIGHT_CHANCE * lerpf(1.6, 0.6, (v.mood + o.mood) / 200.0):
		var pusher: Villager = v if randf() < 0.5 else o
		var pushed: Villager = o if pusher == v else v
		pushed.get_pushed_by(pusher)
		pushed.add_mood(VillagerMood.MOOD_SHOVED, "Se peleó a los empujones")
		if news == "":
			news = "¡Pelea!"
			color = UiStyle.C_WARN
	if news != "":
		var mid := (v.get_global_transform_with_canvas().origin + o.get_global_transform_with_canvas().origin) * 0.5
		Game.say(news, mid + Vector2(0, -100), color)
	end_chat()
	v._wander_off()
	o._wander_off()
