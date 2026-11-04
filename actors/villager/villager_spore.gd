extends RefCounted
class_name VillagerSpore
## La espora zombi: un hongo como el cordyceps. Se agarra por la espora (el poder, ver Spore), por
## la mordida de un zombi, por la tos de uno al que ya le salen hongos o por la nube que suelta un
## zombi al brotar. Mientras más tiempo lo tiene, más se adueña de él (spore, de 0 a 1):
## - Incubando: no se le nota nada, salvo algún tic (solo lo dice el carnet).
## - Con hongos: le salen manchas de micelio que se extienden desde la cabeza hasta los pies, le
##   crecen hongos en el pelo, tiembla, camina lento, no reza, anda triste y tose esporas (que
##   contagian a los que tiene enfrente).
## - Zombi: el hongo lo domina. Los ojos lechosos, la piel gris, tallos de cordyceps en la cabeza
##   y los brazos estirados; ya no come, no duerme, no charla ni te reza: arrastra los pies y
##   persigue a los sanos para morderlos (y contagiarlos). Los que lo ven cerca salen corriendo.
## - Al final se queda duro, de rodillas, le brota de la cabeza un tallo enorme y revienta en una
##   nube de esporas que contagia a los que están cerca (y queda flotando un rato), y se muere.
## Curar lo salva solo antes de que se haga zombi. Se ve en el carnet y se guarda con la partida.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el aldeano
## reenvía (spore, is_zombie, catch_spore...).

enum Infection { NONE, INCUBATING, SPREADING, ZOMBIE }
const SPORE_TIME := Vector2(130.0, 170.0)   # Segundos desde que se contagia hasta que brota
const SPORE_START := 0.02          # Recién contagiado
const SPORE_DOSE := 0.12           # Otra dosis (el poder) al que ya la tenía: lo apura
const SPORE_SPREAD_AT := 0.22      # Desde acá se le nota...
const SPORE_ZOMBIE_AT := 0.6       # ...desde acá es un zombi...
const SPORE_BLOOM_TIME := 4.5      # ...y al llegar a 1 brota: lo que tarda en crecerle el tallo
const SPORE_LOOK := 0.5            # Por segundo: lo que tardan en aparecer (o irse) las manchas
const SPORE_SPEED := 0.75          # Veces speed, con hongos...
const SPORE_REST := 0.6            # ...y se para más seguido
const SPORE_COUGH_EVERY := Vector2(7.0, 13.0)
const SPORE_COUGH_REACH := 40.0
const SPORE_COUGH_CATCH := 0.3
const ZOMBIE_SPEED := 0.55         # Arrastrando los pies (veces speed)...
const ZOMBIE_CHASE := 1.0          # ...persiguiendo a alguien...
const ZOMBIE_LUNGE := 2.0          # ...y ya encima, se le tira
const ZOMBIE_LUNGE_AT := 55.0
const ZOMBIE_SEEK := 240.0         # Hasta dónde busca a quién morder
const ZOMBIE_SEEK_EVERY := 0.5
const ZOMBIE_REST := 0.15
const BITE_REACH := 20.0
const BITE_COOLDOWN := 3.5
const BITE_TIME := 0.7             # Quieto, mordiendo
const BITE_SHOVE := 150.0
const GROAN_EVERY := Vector2(4.0, 9.0)
const GROAN_TIME := 1.1
const ZOMBIE_DREAD := 85.0         # Un zombi así de cerca: los demás salen corriendo...
const FEAR_ZOMBIE := 6.0           # ...y se asustan (por segundo)
const DREAD_CHECK := 0.25
const DREAD_FREEZE := 0.9          # Al verlo, a veces se queda duro del susto un ratito...
const DREAD_FREEZE_CHANCE := 0.35  # ...(una vez cada vez que se le acerca uno)
const BURST_RADIUS := 95.0         # La nube del brote alcanza a los que están a esto
const MOOD_SPORE := -20.0          # Le crecen hongos
const MOOD_BITTEN := -12.0
const FAITH_BITTEN := 6.0          # ¿Y su dios dónde estaba?
var spore := 0.0                   # 0 sano .. 1 brota (ver Infection)
var _spore_rate := 1.0 / 150.0     # Por segundo (cada uno a su ritmo)
var spore_fx := 0.0               # Lo que se le ve (sigue a spore de a poco, ver SPORE_LOOK)
var _spore_seen := Infection.NONE  # La etapa en la que estaba (para avisar cuando cambia)
var _spore_burst := false          # Ya reventó el tallo
var _bloom := 0.0                  # Brotando: 0..1 lo que creció el tallo
var _cough_t := 0.0
var _groan_t := 0.0
var groaning := 0.0               # Gimiendo: abre la boca
var _bite_cool := 0.0
var _bite_t := 0.0
var _prey: Villager                # A quién persigue (zombi)
var _prey_seek := 0.0
var _dread_check := 0.0
var _dread_seen := false           # Ya vio al zombi que tiene cerca (para no paralizarse otra vez)

var v: Villager

func _init(villager: Villager) -> void:
	v = villager

## En qué etapa de la espora está (ver Infection).
func infection() -> Infection:
	if spore <= 0.0:
		return Infection.NONE
	if spore < SPORE_SPREAD_AT:
		return Infection.INCUBATING
	if spore < SPORE_ZOMBIE_AT:
		return Infection.SPREADING
	return Infection.ZOMBIE

## Ya se le nota la espora: le crecen hongos, tose y no reza (el zombi también).
func spore_shows() -> bool:
	return spore >= SPORE_SPREAD_AT and not v.dead

## El hongo lo domina: es un zombi.
func is_zombie() -> bool:
	return spore >= SPORE_ZOMBIE_AT and not v.dead

## Lo que se le ve de la espora, 0..1 (ver waterline.gdshader y VillagerRig.Fungus).
func spore_look() -> float:
	return spore_fx

## Qué tan zombi se lo ve, 0..1: los brazos estirados y la cabeza caída (ver VillagerRig).
func zombie_look() -> float:
	if v.dead:
		return 0.0
	return smoothstep(SPORE_ZOMBIE_AT - 0.04, SPORE_ZOMBIE_AT + 0.02, spore_fx)

## Brotando: lo que ya le creció el tallo de la cabeza, 0..1.
func bloom_amount() -> float:
	return _bloom

## Ya le reventó el tallo (ver _burst).
func bloom_burst() -> bool:
	return _spore_burst

## La boca del zombi: entreabierta, y gimiendo se abre más (ver VillagerRig).
func zombie_mouth() -> float:
	if groaning <= 0.0:
		return 0.3
	return 0.3 + 0.6 * sin((1.0 - groaning / GROAN_TIME) * PI)

## Se le metió la espora (el poder, una mordida, una tos o la nube de un brote). Al que ya la
## tenía, dose lo apura. Adentro de su choza no le llega, ni con el escudo o vacunado.
func catch_spore(dose := 0.0) -> void:
	if not v.is_alive() or v.inside:
		return
	if v.protected_from_disease():
		v._ward_off()
		return
	if spore > 0.0:
		spore = minf(1.0, spore + dose)
		return
	spore = SPORE_START
	_spore_rate = 1.0 / randf_range(SPORE_TIME.x, SPORE_TIME.y)
	_cough_t = randf_range(SPORE_COUGH_EVERY.x, SPORE_COUGH_EVERY.y)

## Para cargar la partida: cuánto lo dominaba el hongo (se le ve tal cual, sin avisar nada).
func set_spore(value: float) -> void:
	clear()
	if value <= 0.0:
		return
	catch_spore()
	spore = minf(value, 1.0)
	spore_fx = spore
	_spore_seen = infection()
	_update_spore_look()

## Ya no tiene la espora (lo curaste): las manchas y los hongos se le van de a poco.
func clear() -> void:
	spore = 0.0
	_bloom = 0.0
	_spore_burst = false
	_spore_seen = Infection.NONE
	_prey = null
	_bite_t = 0.0

## La espora avanza (también durmiendo o adentro de su choza). Con hongos tose; zombi gime, y al
## final, parado en la isla, le brota el tallo de la cabeza y revienta.
func update(dt: float) -> void:
	_bite_cool = maxf(0.0, _bite_cool - dt)
	if spore > 0.0 and v.is_alive():
		spore = minf(1.0, spore + _spore_rate * dt)
		var stage := infection()
		if stage != _spore_seen:
			_spore_turned(stage)
		match stage:
			Infection.SPREADING:
				_cough_t -= dt
				if _cough_t <= 0.0:
					_cough_t = randf_range(SPORE_COUGH_EVERY.x, SPORE_COUGH_EVERY.y)
					if v.is_idle() and not v.on_fire:
						_cough()
			Infection.ZOMBIE:
				_groan_t -= dt
				if _groan_t <= 0.0:
					_groan_t = randf_range(GROAN_EVERY.x, GROAN_EVERY.y)
					if v.visible:
						groan()
				# Brota parado en la isla (no colgando del mouse, volando, flotando ni en el altar)
				if spore >= 1.0 and v.is_idle() and not v.on_fire:
					_bloom = minf(1.0, _bloom + dt / SPORE_BLOOM_TIME)
					if _bloom >= 1.0:
						_burst()
	_update_spore_look(dt)

## Las manchas de hongo (ver waterline.gdshader) siguen a la espora de a poco.
func _update_spore_look(dt := 0.0) -> void:
	if spore <= 0.0 and spore_fx <= 0.0:
		return
	spore_fx = move_toward(spore_fx, spore, SPORE_LOOK * dt)
	if v._waterline:
		v._waterline.set_shader_parameter("spore", spore_fx)

## Pasó a otra etapa de la espora: se le empieza a notar (le salen hongos) o se hizo zombi.
func _spore_turned(stage: Infection) -> void:
	_spore_seen = stage
	match stage:
		Infection.SPREADING:
			_cough_t = randf_range(SPORE_COUGH_EVERY.x, SPORE_COUGH_EVERY.y) * 0.5
			if v.visible:
				Game.say("¡Le salen hongos!", v.get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_SPORE)
		Infection.ZOMBIE:
			# Deja todo lo que estaba haciendo (y si estaba adentro de su choza, sale)
			v.wake_up()
			if v.inside:
				v._leave_home()
			if v.chat_with:
				v.end_chat()
			if v.food:
				v.food.release_eater()
			v._going_home = false
			v._resting = false
			_prey = null
			_groan_t = randf_range(0.2, 0.8)
			Game.say("¡Se hizo zombi!", v.get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
			# Los que lo ven se asustan y se quedan mirando
			var at := v.body_center()
			for node in v.get_tree().get_nodes_in_group("villager"):
				var o := node as Villager
				if o and o != v and o.is_alive() and not o.is_zombie():
					var seen := o.witness(at)
					if seen > 0.0:
						o.add_fear(VillagerFaith.FEAR_DEATH * 0.6 * seen)
						o.scare(VillagerFaith.WITNESS_STARE, at)

## ¡Cof! Tose una nubecita de esporas para adelante: contagia a los que tiene enfrente.
func _cough() -> void:
	var facing := v.rig.facing() if v.rig else 1.0
	var mouth := v.to_global(Vector2(7.0 * facing, -24.0))
	if v.rig:
		v.rig.hit(mouth, Vector2(facing, 0.6), 0.3)
		v.rig.sneeze()
	_spawn_spores(mouth, Vector2(facing, -0.1), 14, 0.6)
	v._play_sfx(VillagerSounds.cough(), Villager.VOICE_DB - 5.0, v._voice_pitch * randf_range(0.9, 1.05))
	Game.say("¡Cof!", v.get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SPORE)
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or o.spore > 0.0 or not (o.is_idle() or o.asleep):
			continue
		var d := o.global_position - v.global_position
		if d.length() < SPORE_COUGH_REACH and (d.length() < Villager.SEPARATION_RADIUS or d.normalized().x * facing > VillagerFlu.SNEEZE_CONE) \
				and randf() < SPORE_COUGH_CATCH:
			o.catch_spore()

## "Uuurgh": el zombi gime (con la boca abierta, ver zombie_mouth).
func groan() -> void:
	v._play_sfx(VillagerSounds.groan(), Villager.VOICE_DB - 6.0, v._voice_pitch * randf_range(0.85, 1.0))
	groaning = GROAN_TIME

## Zombi: arrastrando los pies, busca al sano más cerca y lo persigue; ya encima se le tira y lo
## muerde. Brotando se queda duro donde está. true si ya se encargó de moverlo (quieto); false si
## camina para donde dice dir (ver _physics_process).
func zombie_ai(dt: float) -> bool:
	if spore >= 1.0 or _bloom > 0.0:
		_prey = null
		v._hold_still()
		return true
	if _bite_t > 0.0:
		_bite_t -= dt
		if _has_prey():
			v._stand_facing(_prey)
		else:
			v._hold_still()
		return true
	_prey_seek -= dt
	if not _has_prey():
		_prey = null
	if _prey_seek <= 0.0:
		_prey_seek = ZOMBIE_SEEK_EVERY
		_prey = _find_prey()
	if _prey == null:
		return false   # Nadie cerca: deambula
	var to := _prey.global_position - v.global_position
	if to.length() <= BITE_REACH:
		if _bite_cool <= 0.0:
			_bite(_prey)
		else:
			v._stand_facing(_prey)
		return true
	v.dir = to.normalized()
	v._update_sprite_flip()
	v._resting = false
	v.wander_timer = maxf(v.wander_timer, 1.0)   # Que el paseo no le cambie el rumbo
	return false

## Veces speed del zombi: arrastra los pies, persiguiendo a alguien va más rápido y ya encima se
## le tira.
func zombie_pace() -> float:
	if not _has_prey():
		return ZOMBIE_SPEED
	if _prey.global_position.distance_to(v.global_position) < ZOMBIE_LUNGE_AT:
		return ZOMBIE_LUNGE
	return ZOMBIE_CHASE

## Si o es alguien a quien morder: vivo, sin la espora ni el escudo, en la isla (despierto o
## durmiendo en el piso; no adentro de su choza) y no muy lejos.
func _prey_ok(o: Villager) -> bool:
	return is_instance_valid(o) and o != v and not o.is_queued_for_deletion() and o.spore <= 0.0 \
			and not o.dead and not o.shielded() and (o.is_idle() or o.asleep) \
			and o.global_position.distance_to(v.global_position) < ZOMBIE_SEEK * 1.3

## Sigue teniendo a quién perseguir (no se lo comió el tiburón, no se curó...).
func _has_prey() -> bool:
	return is_instance_valid(_prey) and _prey_ok(_prey)

## El más cerca para morder (o null).
func _find_prey() -> Villager:
	var best: Villager = null
	var best_d := ZOMBIE_SEEK
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or not _prey_ok(o):
			continue
		var d := o.global_position.distance_to(v.global_position)
		if d < best_d:
			best = o
			best_d = d
	return best

## Se le tira encima y lo muerde.
func _bite(o: Villager) -> void:
	_bite_cool = BITE_COOLDOWN
	_bite_t = BITE_TIME
	if v.rig:
		v.rig.set_facing_left(o.global_position.x < v.global_position.x)
		v.rig.lunge()
	v._play_sfx(VillagerSounds.bite(), Villager.VOICE_DB - 2.0, randf_range(0.9, 1.1))
	o.get_bitten(v)

## Lo mordió un zombi: grita, sangra, sale empujado (capaz que se cae de la isla) y corriendo, y
## se le metió la espora. Con el escudo no le pasa nada (y el zombi rebota).
func get_bitten(z: Villager) -> void:
	if v.shielded():
		v._ward_off(true)
		z.get_shoved(Vector2.ZERO, Vector2(signf(z.global_position.x - v.global_position.x), 0.0) * BITE_SHOVE)
		return
	v.wake_up()
	if v.chat_with:
		v.end_chat()
	if v.food:
		v.food.release_eater()
	v._going_home = false
	var push := Vector2(1.0 if v.global_position.x >= z.global_position.x else -1.0, 0.0)
	v._spawn_blood(v.body_center() + Vector2(-push.x * 6.0, -14.0), push + Vector2.UP * 0.5, 12)
	if v.rig:
		v.rig.hit(v.body_center(), push, 0.9)
	v._voice.pitch_scale = v._voice_pitch * randf_range(1.05, 1.2)
	v._voice.play()
	v.get_shoved(Vector2.ZERO, push * BITE_SHOVE)
	v._scram = Villager.SCRAM_TIME * 2.0
	v.dir = (push + (v.island_center - v.global_position).normalized() * 0.5).normalized()
	v._update_sprite_flip()
	v._resting = false
	v.wander_timer = maxf(v.wander_timer, v._scram)
	v.add_fear(VillagerFaith.FEAR_THROW)
	v.add_faith(-FAITH_BITTEN)
	v.add_mood(MOOD_BITTEN, "La mordió un zombi" if v.gender == Villager.Gender.FEMALE else "Lo mordió un zombi")
	Game.say("¡Mordida!", v.get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_WARN)
	catch_spore()

## Con un zombi cerca se asusta y sale corriendo para el otro lado (y un poco para el medio de la
## isla, así no lo arrincona contra la orilla). A veces, al verlo, primero se queda duro del susto.
func avoid_zombies(dt: float) -> void:
	if v.on_fire or v.shielded():
		return   # (Con el escudo, ni se asusta: no lo pueden morder)
	_dread_check -= dt
	if _dread_check > 0.0:
		return
	_dread_check = DREAD_CHECK
	var near: Villager = null
	var best := ZOMBIE_DREAD
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != v and o.is_zombie() and o.is_idle():
			var d := o.global_position.distance_to(v.global_position)
			if d < best:
				best = d
				near = o
	if near == null:
		_dread_seen = false
		return
	v.add_fear(FEAR_ZOMBIE * DREAD_CHECK)
	if v.is_scared():
		return   # Duro del susto, mirándolo con la boca abierta
	if not _dread_seen:
		_dread_seen = true
		if randf() < DREAD_FREEZE_CHANCE:
			v.scare(DREAD_FREEZE, near.body_center())
			if v.food:
				v.food.release_eater()
			if v.chat_with:
				v.end_chat()
			return
	v._scram = maxf(v._scram, Villager.SCRAM_TIME)
	var away := (v.global_position - near.global_position).normalized()
	v.dir = (away + (v.island_center - v.global_position).normalized() * 0.35).normalized()
	v._update_sprite_flip()
	v._resting = false
	v.wander_timer = maxf(v.wander_timer, Villager.SCRAM_TIME)
	if v.food:
		v.food.release_eater()
	if v.chat_with:
		v.end_chat()

## Le revienta el tallo de la cabeza: suelta una nube de esporas que contagia a los que están
## cerca (y a los que ya la tenían los apura), la nube queda flotando un rato (ver Spore.Cloud) y
## se muere.
func _burst() -> void:
	_spore_burst = true
	var tip := v.rig.bloom_tip() if v.rig else v.body_center() + Vector2(0, -40)
	var feet := v.ground_point()
	_spawn_spores(tip, Vector2.UP, 70, 1.6)
	v._play_sfx(VillagerSounds.burst(), Villager.VOICE_DB, randf_range(0.9, 1.1))
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != v and not o.dead and Spore.reaches(o, feet, BURST_RADIUS):
			o.catch_spore(SPORE_DOSE * 0.5)
	Spore.release_cloud(v.get_tree(), feet, BURST_RADIUS * 0.8)
	Game.say("La consumió la espora" if v.gender == Villager.Gender.FEMALE else "Lo consumió la espora",
			v.get_global_transform_with_canvas().origin + Vector2(0, -90), HUD.C_SPORE)
	if v.food:
		v.food.release_eater()
	v._die()
	v.swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.0, 3.0)   # Se cae para un costado
	v.corpse_vel = Vector2.ZERO

## Esporas que salen de at para el lado de toward (la tos, el brote).
func _spawn_spores(at: Vector2, toward: Vector2, amount: int, power: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = 0.6 + 0.5 * power
	p.direction = toward
	p.spread = 30.0 if power < 1.0 else 80.0
	p.initial_velocity_min = 30.0 * power
	p.initial_velocity_max = 95.0 * power
	p.damping_min = 25.0
	p.damping_max = 50.0
	p.gravity = Vector2(0, 12)
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.2 + 1.2 * power
	p.color_ramp = Villager._fade_ramp(Color(1.0, 0.76, 0.36, 0.95), Color(0.85, 0.58, 0.28, 0.0))
	p.z_index = 15
	v.get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
