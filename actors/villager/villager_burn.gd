extends RefCounted
class_name VillagerBurn
## Quemarse: el fuego y el rayo, que terminan igual (carbonizado y hecho cenizas).
## - Fuego: agarrado (o cayendo) arriba de la llama de una antorcha se calienta y se prende.
##   Prendido fuego grita y corre desesperado por la isla, y contagia a los que toca. Tirándolo al
##   agua (o con la lluvia del diluvio) se apaga y queda tiznado un rato; si no, se va tostando y
##   muere carbonizado. Un cadáver también se quema, y más rápido.
## - Rayo (ver Lightning): se electrocuta (tieso, temblando y con el esqueleto a la vista) y queda
##   carbonizado y humeando. El escudo lo para.
## - Carbonizado, se desarma en cenizas de la cabeza a los pies. Si está en la isla se queda ahí;
##   volando sigue cayendo y se deshace cuando queda tirado, y en el agua se hunde.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (on_fire, zap, ashes...).

# Fuego
const IGNITE_TIME := 0.5         # Segundos en el fuego hasta prenderse
const HEAT_COOL := 1.5           # Lo que se enfría por segundo lejos del fuego
const BURN_TIME := 5.0           # Prendido fuego, hasta morir carbonizado
const CORPSE_BURN_TIME := 2.0
const BURN_SOOT := 0.6           # Lo tostado que llega a quedar antes de morir (ver waterline.gdshader)
const SOOT_FADE := 0.04          # Apagado, lo que se le va el tizne por segundo
const SPREAD_DIST := 16.0        # Distancia (entre centros) a la que contagia el fuego
const PANIC_SPEED := 2.6         # Veces speed corriendo prendido fuego
const PANIC_TURN := Vector2(0.25, 0.6)   # Segundos entre volantazos
const PANIC_SWERVE := 1.1        # Cuánto dobla en cada volantazo (rad)
const SCREAM_EVERY := Vector2(0.6, 1.0)
const FIRE_LIGHT_ENERGY := 0.8   # De noche ilumina alrededor, como una antorcha
var on_fire := false
var _heat := 0.0
var _burn_t := 0.0
var _soot := 0.0
var _scream_t := 0.0
var _flames: Flames
var _sparks: CPUParticles2D
var _fire_light: PointLight2D

# Rayo, carbonizado y cenizas
enum Zap { NONE, SHOCK, CHARRED, ASHES }
const SHOCK_TIME := 1.1
const CHAR_TIME := 0.8        # Carbonizado, todavía entero, antes de deshacerse
const ASH_TIME := 1.2         # Lo que tarda en deshacerse
const XRAY_HZ := 11.0         # Cuadros de rayos X por segundo
const CRUMBLE_EDGE := 8.0     # Lo que sobresale el borde desgranado (ver waterline.gdshader)
var zap_state := Zap.NONE
var _zap_t := 0.0
var _zap_pinned := false      # Le cayó en la isla: no se mueve de ahí
var xray_mat: ShaderMaterial  # El esqueleto: con el recorte del agua, pero sin oscurecerse
var _arcs: ZapArcs
var _smoke: CPUParticles2D    # El mismo para el fuego y para el carbonizado
var _pile: AshPile

var v: Villager

func _init(villager: Villager) -> void:
	v = villager

## Si le puede caer un rayo (vivo o cadáver; no si ya se está friendo).
func can_zap() -> bool:
	return v.can_blast() and v.modulate.a > 0.2

## Electrocutado o carbonizado en la isla: se queda quieto donde le cayó.
func zap_pinned() -> bool:
	return zap_state != Zap.NONE and _zap_pinned

## 0..1: cuánto ya se hizo cenizas.
func ashes() -> float:
	return clampf(_zap_t / ASH_TIME, 0.0, 1.0) if zap_state == Zap.ASHES else 0.0

## Tiene algo que curar (ver Villager.cure): se está quemando o le queda tizne.
func has_burns() -> bool:
	return on_fire or _soot > 0.0

## Se prende fuego.
func ignite() -> void:
	if on_fire or v.eaten or zap_state != Zap.NONE:
		return
	on_fire = true
	_burn_t = 0.0
	_scream_t = 0.0
	v._resting = false
	v.wander_timer = 0.0
	if _flames == null:
		_flames = Flames.new()
		v.add_child(_flames)   # Después del Rig: las llamas van por delante del cuerpo
		_sparks = _make_sparks()
		v.add_child(_sparks)
	_flames.on = true
	_sparks.emitting = true
	if _smoke == null:
		_start_smoke()
	_smoke.emitting = true
	if _fire_light == null:
		_fire_light = PointLight2D.new()
		_fire_light.texture = Decoration._torch_light_texture()
		_fire_light.color = Decoration.TORCH_LIGHT_COLOR
		_fire_light.enabled = false
		v.add_child(_fire_light)
	if not v.dead:
		Game.say("¡Se prendió fuego!", v.get_global_transform_with_canvas().origin + Vector2(0, -70), UiStyle.C_WARN)

## Se apaga. steam: cayó al agua o lo agarró la lluvia (sale vapor).
func put_out(steam := false) -> void:
	if not on_fire:
		return
	on_fire = false
	v.add_mood(VillagerMood.MOOD_BURNED, "Se prendió fuego")
	_heat = 0.0
	_flames.on = false
	_sparks.emitting = false
	_smoke.emitting = false
	_fire_light.enabled = false
	v._waterline.set_shader_parameter("embers", 0.0)
	if steam:
		_spawn_steam()
		if not v.dead:
			Game.say("¡Fiuuu!", v.get_global_transform_with_canvas().origin + Vector2(0, -60), UiStyle.C_TEXT)

## Le cayó un rayo (ver Lightning): se electrocuta y muere. Con el escudo, el rayo rebota.
func zap() -> void:
	if not can_zap():
		return
	if v.shielded():
		v._ward_off(true)
		return
	put_out()   # El rayo se encarga de carbonizarlo
	zap_state = Zap.SHOCK
	_zap_t = 0.0
	_zap_pinned = not (v.dragging or v.falling or v.in_water) and (not v.dead or v.corpse_grounded)
	v._die()
	xray_mat = ShaderMaterial.new()
	xray_mat.shader = Villager.WATERLINE_SHADER
	_arcs = ZapArcs.new()
	v.add_child(_arcs)

## Lo curaste (ver Villager.cure) o volvió a la vida: se apaga (sin vapor), se enfría y se le va el
## tizne.
func heal() -> void:
	put_out()
	_soot = 0.0
	_heat = 0.0
	if v._waterline:
		v._waterline.set_shader_parameter("burnt", 0.0)

## Lo agarraste (ver Villager._start_drag): carbonizado también se lo puede levantar, y se deshace al
## volver a quedar tirado.
func unpin() -> void:
	_zap_pinned = false

## Se fue del árbol (ver Villager._exit_tree): si estaba a mitad de hacerse cenizas (se lo comió el
## tiburón), el montoncito igual se apaga.
func finish_ashes() -> void:
	if is_instance_valid(_pile) and _pile.is_inside_tree():
		_pile.finish()

## Cada frame (lo llama el aldeano): primero el fuego, después el rayo y las cenizas.
func update(dt: float) -> void:
	_update_fire(dt)
	_update_zap(dt)

## Prendido fuego se va tostando (y el agua lo apaga); apagado se le va el tizne, y si toca fuego
## se calienta hasta prenderse.
func _update_fire(dt: float) -> void:
	if v.eaten or zap_state != Zap.NONE or v._rising > 0.0 or v.is_queued_for_deletion():
		return
	if on_fire:
		if v.in_water or Storm.wet():   # El agua (o la lluvia del diluvio) lo apaga
			put_out(true)
			return
		_burn_t += dt
		var burn_time := CORPSE_BURN_TIME if v.dead else BURN_TIME
		_soot = maxf(_soot, BURN_SOOT * minf(1.0, _burn_t / burn_time))
		v._waterline.set_shader_parameter("burnt", _soot)
		v._waterline.set_shader_parameter("embers", 0.5 + 0.3 * sin(_burn_t * 9.0))
		_sparks.global_rotation = 0.0   # Suben aunque esté tirado o colgando
		_smoke.global_rotation = 0.0
		_update_fire_light()
		if not v.dead:
			_scream_t -= dt
			if _scream_t <= 0.0:
				_scream_t = randf_range(SCREAM_EVERY.x, SCREAM_EVERY.y)
				v._voice.pitch_scale = v._voice_pitch * randf_range(1.05, 1.2)
				v._voice.play()
		if _burn_t >= burn_time:
			_burn_out()
		return

	# Apagado: el tizne se le va de a poco
	if _soot > 0.0 and not v.dead:
		_soot = maxf(0.0, _soot - SOOT_FADE * dt)
		v._waterline.set_shader_parameter("burnt", _soot)
		v._waterline.set_shader_parameter("embers", 0.0)

	if _touching_fire():
		_heat += dt
		if _heat >= IGNITE_TIME:
			ignite()
	else:
		_heat = maxf(0.0, _heat - HEAT_COOL * dt)

## En la llama de una antorcha (solo agarrado o volando: caminando pasa por delante o por
## detrás), o pegado a otro aldeano que se está quemando. Con la lluvia no se prende.
func _touching_fire() -> bool:
	if v.in_water or v.modulate.a < 0.2 or Storm.wet():
		return false
	if v.dragging or v.falling:
		for t in v.get_tree().get_nodes_in_group("torch"):
			if (t as Decoration).burns(v):
				return true
	for node in v.get_tree().get_nodes_in_group("villager"):
		var o := node as Villager
		if o and o != v and o.on_fire and o.global_position.distance_to(v.global_position) < SPREAD_DIST:
			return true
	return false

## Se terminó de quemar: muere carbonizado y después se hace cenizas, como con el rayo (ver
## _update_zap).
func _burn_out() -> void:
	var pinned := not (v.dragging or v.falling or v.in_water) and (not v.dead or v.corpse_grounded)
	put_out()
	v._die()
	zap_state = Zap.CHARRED
	_zap_t = 0.0
	_zap_pinned = pinned
	_soot = 1.0

## De noche ilumina alrededor, titilando como una antorcha.
func _update_fire_light() -> void:
	var sky := v.get_tree().get_first_node_in_group("sky")
	var night: float = sky.night if sky else 0.0
	var dark := smoothstep(0.55, 0.95, night)
	_fire_light.enabled = dark > 0.01
	_fire_light.energy = FIRE_LIGHT_ENERGY * dark * (1.0 + sin(_burn_t * 19.0) * 0.08 + sin(_burn_t * 31.0) * 0.05)

## Chispas que se desprenden y suben (en coords del mundo: si lo mueven, dejan estela).
func _make_sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 0.8
	p.local_coords = false
	p.position = Vector2(0, -6)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(9, 22)
	p.direction = Vector2.UP
	p.spread = 35.0
	p.gravity = Vector2(0, -70)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color_ramp = Villager._fade_ramp(Color(1.0, 0.85, 0.35), Color(0.9, 0.25, 0.05, 0.0))
	return p

## Bocanada de vapor al apagarse en el agua.
func _spawn_steam() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 24
	p.lifetime = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(10, 6)
	p.direction = Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color_ramp = Villager._fade_ramp(Color(0.95, 0.97, 1.0, 0.8), Color(0.85, 0.9, 0.95, 0.0))
	v.get_parent().add_child(p)
	p.global_position = v.global_position + Vector2(0, -10)
	p.emitting = true
	p.finished.connect(p.queue_free)

## Electrocutado → carbonizado → cenizas (también el que se terminó de quemar, ver _burn_out).
func _update_zap(dt: float) -> void:
	if zap_state == Zap.NONE or v.eaten:
		return
	_zap_t += dt
	match zap_state:
		Zap.SHOCK:
			if _zap_t >= SHOCK_TIME:
				zap_state = Zap.CHARRED
				_zap_t = 0.0
				_arcs.queue_free()
				_start_smoke()
		Zap.CHARRED:
			if v.in_water and not v.dragging:
				v.drowning = true   # Carbonizado no flota: se hunde
			elif _zap_t >= CHAR_TIME and not (v.dragging or v.falling) \
					and (_zap_pinned or (v.corpse_grounded and v.corpse_timer > 0.4)):
				_start_ashes()
		Zap.ASHES:
			_pile.amount = ashes()
			if _zap_t >= ASH_TIME:
				_pile.finish()
				v.queue_free()
	if _smoke:
		_smoke.global_rotation = 0.0   # El humo sube aunque esté tirado
		_smoke.emitting = zap_state == Zap.CHARRED and not v.in_water
	_update_zap_fx()

## Rayos X, carbonizado y desarmarse (ver waterline.gdshader).
func _update_zap_fx() -> void:
	if v._waterline == null:
		return
	var xray := zap_state == Zap.SHOCK and fmod(_zap_t * XRAY_HZ, 1.0) < 0.5
	v._waterline.set_shader_parameter("xray", xray)
	v.rig.set_xray(xray, xray_mat)
	var burnt := 1.0
	var embers := 0.3
	match zap_state:
		Zap.SHOCK:
			burnt = 0.6 * _zap_t / SHOCK_TIME   # Se va tostando mientras se electrocuta
			embers = 0.0
		Zap.CHARRED:
			burnt = lerpf(0.6, 1.0, minf(1.0, _zap_t / 0.15))
			embers = lerpf(1.0, 0.3, minf(1.0, _zap_t / CHAR_TIME))
	v._waterline.set_shader_parameter("burnt", burnt)
	v._waterline.set_shader_parameter("embers", embers)
	if zap_state == Zap.ASHES:
		var from := v.to_global(Vector2(0, Villager.HEAD_TOP))
		var axis := (v.to_global(Vector2(0, Villager.FEET)) - from).normalized()
		var reach := ashes() * (Villager.FEET - Villager.HEAD_TOP + CRUMBLE_EDGE)
		v._waterline.set_shader_parameter("crumble", reach)
		v._waterline.set_shader_parameter("crumble_from", from)
		v._waterline.set_shader_parameter("crumble_axis", axis)
		# El polvo se desprende de donde se está deshaciendo (hasta que ya casi no queda nada)
		_pile.dust.global_position = from + axis * minf(reach, Villager.FEET - Villager.HEAD_TOP)
		_pile.dust.global_rotation = v.rotation
		_pile.dust.emitting = ashes() < 0.85

## El humo: del que se quema y del carbonizado (es el mismo).
func _start_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.amount = 14
	_smoke.lifetime = 1.1
	_smoke.local_coords = false
	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_smoke.emission_rect_extents = Vector2(8, 20)
	_smoke.direction = Vector2.UP
	_smoke.spread = 20.0
	_smoke.gravity = Vector2(0, -30)
	_smoke.initial_velocity_min = 12.0
	_smoke.initial_velocity_max = 30.0
	_smoke.scale_amount_min = 2.5
	_smoke.scale_amount_max = 5.0
	_smoke.color_ramp = Villager._fade_ramp(Color(0.22, 0.21, 0.21, 0.6), Color(0.5, 0.5, 0.5, 0.0))
	_smoke.position = Vector2(0, -6)
	v.add_child(_smoke)

## Carbonizado y quieto: empieza a deshacerse en cenizas, y debajo queda el montoncito.
func _start_ashes() -> void:
	zap_state = Zap.ASHES
	_zap_t = 0.0
	_zap_pinned = true
	_pile = AshPile.new()
	var lying := absf(sin(v.rotation))
	_pile.width = lerpf(14.0, 24.0, lying)
	var layer := v.get_tree().get_first_node_in_group("ground_layer")
	(layer if layer else v.get_parent()).add_child(_pile)
	# Al pie si está parado; tirado, debajo del cuerpo
	var a := v.to_global(Vector2(0, Villager.HEAD_TOP))
	var b := v.to_global(Vector2(0, Villager.FEET))
	_pile.global_position = Vector2((a.x + b.x) * 0.5, maxf(a.y, b.y) + lying * 9.0 - 1.0)
