extends RefCounted
class_name VillagerFlu
## La gripe: se contagia por el estornudo de un enfermo (alcanza a los que tiene adelante) o por
## quedarse pegado a uno; aparece sola cada tanto (ver World._update_outbreak), la pueden agarrar
## los que se llevó el agua del diluvio y la peste (ver Plague) la da sin incubar. Primero la incuba
## sin que se note (solo lo dice el carnet); después anda pálido y verdoso, lento, se para a cada
## rato, estornuda y no reza. Al final se cura (y queda inmune un tiempo) o se muere. El escudo y la
## vacuna la frenan. Se ve en el carnet y se guarda con la partida.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (flu, is_sick, catch_flu...).

enum Stage { HEALTHY, INCUBATING, SICK, IMMUNE }
const INCUBATION := Vector2(8.0, 14.0)
const SICK_TIME := Vector2(35.0, 50.0)
const IMMUNE_TIME := 600.0       # Más que lo que dura un brote: así se termina y no se la vuelven a pasar
const FLU_DEATH_CHANCE := 0.3
const FLU_SPEED := 0.55          # Veces speed, enfermo
const FLU_REST_CHANCE := 0.7     # Enfermo se para mucho más seguido
const FLU_TINT := 0.55           # Lo verdoso que se pone (ver waterline.gdshader)
const SNEEZE_EVERY := Vector2(3.0, 7.0)
const SNEEZE_REACH := 46.0       # Hasta dónde llega el estornudo, para adelante...
const SNEEZE_CONE := 0.6         # ...en un cono de este coseno
const SNEEZE_CATCH := 0.5        # Probabilidad de contagiar a cada uno que alcanza
const CLOSE_CATCH := 4.0         # Segundos pegado a un enfermo hasta contagiarse
const SOAKED_CATCH := 0.35       # Probabilidad de agarrársela si se lo llevó el agua del diluvio
var flu := Stage.HEALTHY
var flu_t := 0.0                 # Lo que le falta a la etapa de ahora
var _flu_tint := 0.0             # Lo verdoso que se le ve (sigue a la etapa de a poco)
var _sneeze_t := 0.0             # Lo que le falta para el próximo estornudo
var _exposure := 0.0             # Segundos pegado a un enfermo (ver CLOSE_CATCH)

var v: Villager

func _init(villager: Villager) -> void:
	v = villager

## Para la partida guardada (ver Villager.to_dict): la etapa y lo que le falta.
func to_dict() -> Dictionary:
	return {"flu": flu, "flu_t": flu_t}

func from_dict(d: Dictionary) -> void:
	set_flu(d.get("flu", Stage.HEALTHY) as Stage, d.get("flu_t", 0.0))

## Enfermo de verdad (con síntomas, contagia y no reza).
func is_sick() -> bool:
	return flu == Stage.SICK and not v.dead

## La tiene: la está incubando o está enfermo (el que se curó y quedó inmune, no).
func has_flu() -> bool:
	return flu == Stage.INCUBATING or flu == Stage.SICK

## Lo verdoso que se lo ve, 0..1 (ver waterline.gdshader y la foto del carnet).
func flu_look() -> float:
	return _flu_tint / FLU_TINT

## Se contagió: la incuba un rato sin que se note (solo lo dice el carnet). Los sanos nada más:
## el que ya la tiene o se acaba de curar no.
func catch_flu() -> void:
	if flu != Stage.HEALTHY or not v.is_alive():
		return
	if v.protected_from_disease():
		_exposure = 0.0
		v._ward_off()
		return
	flu = Stage.INCUBATING
	flu_t = randf_range(INCUBATION.x, INCUBATION.y)
	_exposure = 0.0

## Para cargar la partida: en qué etapa estaba y lo que le faltaba.
func set_flu(state: Stage, time_left: float) -> void:
	flu = state
	flu_t = time_left
	_flu_tint = FLU_TINT if flu == Stage.SICK else 0.0
	_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y)

## La peste (ver Plague): se enferma ya, sin incubarla y aunque estuviera inmune (con el escudo o
## vacunado, no).
func infect() -> void:
	if not v.is_alive() or v.inside or flu == Stage.SICK:
		return
	if v.protected_from_disease():
		v._ward_off()
		return
	flu = Stage.SICK
	flu_t = randf_range(SICK_TIME.x, SICK_TIME.y)
	_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y) * 0.5
	_exposure = 0.0

## Se le pasó (o lo curaste, ver Villager.cure): queda inmune un tiempo (IMMUNE_TIME) y lo dice.
func recover() -> void:
	flu = Stage.IMMUNE
	flu_t = IMMUNE_TIME
	Game.say("¡Se curó!", v.get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_SHOP)

## Volvió a la vida (ver Villager._come_back): sano y sin lo verdoso, sin decir nada. Si la tenía,
## queda inmune.
func heal() -> void:
	if has_flu():
		flu = Stage.IMMUNE
		flu_t = IMMUNE_TIME
	_flu_tint = 0.0

## Cada frame (lo llama el aldeano): avanza la etapa, estornuda, se contagia de los enfermos que
## tiene pegados y se pone verdoso (o se le va) de a poco.
func update(dt: float) -> void:
	if v.eaten or v.is_queued_for_deletion():
		return
	if not v.dead:
		match flu:
			Stage.HEALTHY:
				_update_exposure(dt)
			Stage.INCUBATING:
				flu_t -= dt
				if flu_t <= 0.0:
					flu = Stage.SICK
					flu_t = randf_range(SICK_TIME.x, SICK_TIME.y)
					_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y) * 0.5
			Stage.SICK:
				flu_t -= dt
				if v.is_idle() and not v.on_fire:
					_sneeze_t -= dt
					if _sneeze_t <= 0.0:
						_sneeze_t = randf_range(SNEEZE_EVERY.x, SNEEZE_EVERY.y)
						_sneeze()
					# Termina parado en la isla: no se muere colgando del mouse ni flotando
					if flu_t <= 0.0:
						if randf() < FLU_DEATH_CHANCE:
							_die_of_flu()
						else:
							recover()
			Stage.IMMUNE:
				flu_t -= dt
				if flu_t <= 0.0:
					flu = Stage.HEALTHY
	# Se pone verdoso de a poco (y muerto de gripe se queda así)
	var tint := FLU_TINT if flu == Stage.SICK else 0.0
	if not v.dead or tint > 0.0:
		_flu_tint = move_toward(_flu_tint, tint, dt * 0.15)
	if v._waterline:
		v._waterline.set_shader_parameter("sick", _flu_tint)

## Sano y parado en la isla: si se queda pegado a un enfermo, al rato se contagia.
func _update_exposure(dt: float) -> void:
	var near := false
	if v.is_idle():
		for node in v.get_tree().get_nodes_in_group("villager"):
			var o := node as Villager
			if o and o != v and o.is_sick() and o.is_idle() \
					and o.global_position.distance_to(v.global_position) < Villager.SEPARATION_RADIUS * 1.4:
				near = true
				break
	_exposure = _exposure + dt if near else maxf(0.0, _exposure - dt * 0.5)
	if _exposure >= CLOSE_CATCH:
		catch_flu()

## ¡Achís! Se sacude, le salen gotitas para adelante y contagia a los que tiene enfrente.
func _sneeze() -> void:
	var facing := v.rig.facing() if v.rig else 1.0
	var mouth := v.to_global(Vector2(7.0 * facing, -24.0))
	if v.rig:
		v.rig.hit(mouth, Vector2(facing, 0.6), 0.35)
		v.rig.sneeze()
	_spawn_droplets(mouth, Vector2(facing, 0.15))
	v._play_sfx(VillagerSounds.sneeze(), Villager.VOICE_DB - 4.0, v._voice_pitch * randf_range(0.92, 1.05))
	Game.say("¡Achís!", v.get_global_transform_with_canvas().origin + Vector2(0, -70), HUD.C_TEXT)
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o == null or o == v or o.flu != Stage.HEALTHY or not o.is_idle():
			continue
		var d := o.global_position - v.global_position
		if d.length() < SNEEZE_REACH and (d.length() < Villager.SEPARATION_RADIUS or d.normalized().x * facing > SNEEZE_CONE) \
				and randf() < SNEEZE_CATCH:
			o.catch_flu()

## No aguantó: se desploma donde está (cuenta como sacrificio, como cualquier muerte).
func _die_of_flu() -> void:
	Game.say("Murió de gripe", v.get_global_transform_with_canvas().origin + Vector2(0, -80), HUD.C_WARN)
	if v.food:
		v.food.release_eater()
	v._gentle_death = true
	v._die()
	v.swing_vel = (1.0 if randf() < 0.5 else -1.0) * randf_range(2.5, 4.0)   # Se cae para un costado
	v.corpse_vel = Vector2.ZERO

## Las gotitas del estornudo.
func _spawn_droplets(at: Vector2, toward: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.5
	p.direction = toward
	p.spread = 22.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4
	p.color_ramp = Villager._fade_ramp(Color(0.8, 0.95, 0.7, 0.85), Color(0.75, 0.9, 0.65, 0.0))
	v.get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
