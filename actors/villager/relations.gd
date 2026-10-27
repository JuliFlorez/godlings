extends RefCounted
class_name Relations
## Lo que se quieren (o no) los aldeanos entre sí. Cada dos aldeanos tienen una afinidad de
## -100 a 100 que sube o baja con cada charla (ver Villager._finish_chat): pasando FRIEND_AT
## se hacen amigos, por debajo de ENEMY_AT enemigos, y dos amigos solteros que se gustan,
## pasando COUPLE_AT, se ponen de novios. Para dejar de ser amigos o enemigos tiene que
## cambiar bastante (FRIEND_KEEP, ENEMY_KEEP): así no van y vienen con cada charla.
## Cada dos aldeanos tienen además su química (si se caen bien de entrada) y su atracción,
## fijas: salen de sus números de carnet, así no hace falta guardarlas.
## Se guarda con la partida (ver World.save_game) y se ve en el carnet (ver VillagerCard).
## Cada cambio queda anotado en el historial (ver HistoryPanel).

enum Kind { NONE, FRIEND, ENEMY, COUPLE }
## Lo que cambió con una charla (para avisar con un cartel y anotarlo en el historial).
enum Event { NONE, FRIENDS, ENEMIES, MADE_UP, COUPLE, BROKE_UP, DRIFTED }

const FRIEND_AT := 35.0
const FRIEND_KEEP := 20.0
const ENEMY_AT := -35.0
const ENEMY_KEEP := -20.0
const COUPLE_AT := 65.0
const BREAK_UP_AT := 30.0
const ROMANCE := 0.6             # Atracción mínima para ponerse de novios (a 4 de cada 10 les pasa)
const CHEMISTRY := 15.0          # Lo que suma (o resta) la química en cada charla
const MOMENTUM := 0.06           # Los amigos charlan cada vez mejor y los enemigos, peor
const LUCK := Vector2(-8.0, 12.0)
const BAD_DAY := 0.1             # A veces discuten (hasta los amigos y las parejas)...
const BAD_DAY_COST := Vector2(12.0, 22.0)
const SICK_MOOD := 3.0           # ...y con gripe se anda de mal humor
const COLORS := {
	Kind.FRIEND: Color(0.46, 0.84, 0.52),
	Kind.ENEMY: Color(1.0, 0.45, 0.4),
	Kind.COUPLE: Color(1.0, 0.52, 0.74),
}

const HISTORY_MAX := 100         # Los más viejos se van borrando

static var _affinity := {}       # Vector2i(carnet menor, carnet mayor) -> float
static var _bonds := {}          # Vector2i -> Kind (los que no son NONE)
## Historial, del más viejo al más nuevo: {time (segundos jugados, ver World.play_time),
## event, a, b (carnets), a_name, b_name (para cuando ya no estén)}.
static var history: Array[Dictionary] = []
static var history_version := 0  # Sube con cada cambio (para rearmar el panel solo si hace falta)

## Sin nadie (al arrancar el mundo, antes de cargar una partida).
static func clear() -> void:
	_affinity.clear()
	_bonds.clear()
	history.clear()
	history_version += 1

static func _key(a: Villager, b: Villager) -> Vector2i:
	return Vector2i(mini(a.id_number, b.id_number), maxi(a.id_number, b.id_number))

static func affinity(a: Villager, b: Villager) -> float:
	return _affinity.get(_key(a, b), 0.0)

## Qué son a y b (NONE si alguno es null o son el mismo).
static func kind(a: Villager, b: Villager) -> Kind:
	if a == null or b == null or a == b:
		return Kind.NONE
	return _bonds.get(_key(a, b), Kind.NONE)

static func color(k: Kind) -> Color:
	return COLORS.get(k, HUD.C_TEXT)

## Número de carnet de su pareja (0: soltero).
static func partner_id(v: Villager) -> int:
	for k: Vector2i in _bonds:
		if _bonds[k] == Kind.COUPLE and (k.x == v.id_number or k.y == v.id_number):
			return k.y if k.x == v.id_number else k.x
	return 0

## Número fijo de 0 a 1 para estos dos (salt: para qué es).
static func _pair_rand(a: Villager, b: Villager, salt: int) -> float:
	var k := _key(a, b)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([k.x, k.y, salt])
	return rng.randf()

## Si se caen bien de entrada: -0.7 a 1 (la mayoría se lleva más o menos bien).
static func chemistry(a: Villager, b: Villager) -> float:
	return lerpf(-0.7, 1.0, _pair_rand(a, b, 1))

static func attraction(a: Villager, b: Villager) -> float:
	return _pair_rand(a, b, 2)

## Cuánto van a cambiar lo que se quieren con una charla (se decide al empezar, así se nota
## en lo que dicen si les está yendo bien o mal).
static func chat_delta(a: Villager, b: Villager) -> float:
	var d := chemistry(a, b) * CHEMISTRY + affinity(a, b) * MOMENTUM + randf_range(LUCK.x, LUCK.y)
	if randf() < BAD_DAY:
		d -= randf_range(BAD_DAY_COST.x, BAD_DAY_COST.y)
	if a.is_sick() or b.is_sick():
		d -= SICK_MOOD
	return d

## Con quién tiene más ganas de charlar: su pareja y sus amigos, mucho más que sus enemigos.
static func chat_weight(a: Villager, b: Villager) -> float:
	match kind(a, b):
		Kind.COUPLE:
			return 4.0
		Kind.FRIEND:
			return 2.5
		Kind.ENEMY:
			return 0.6
	return 1.0

## Terminó una charla: suma delta a lo que se quieren. Devuelve lo que cambió entre ellos (y
## lo anota en el historial).
static func change(a: Villager, b: Villager, delta: float) -> Event:
	var ev := _change(a, b, delta)
	if ev != Event.NONE:
		history.append({
			"time": World.play_time,
			"event": ev,
			"a": a.id_number,
			"b": b.id_number,
			"a_name": a.full_name(),
			"b_name": b.full_name(),
		})
		if history.size() > HISTORY_MAX:
			history.pop_front()
		history_version += 1
	return ev

static func _change(a: Villager, b: Villager, delta: float) -> Event:
	var k := _key(a, b)
	var aff := clampf(affinity(a, b) + delta, -100.0, 100.0)
	_affinity[k] = aff
	match kind(a, b):
		Kind.COUPLE:
			if aff < BREAK_UP_AT:
				_bonds.erase(k)
				return Event.BROKE_UP
		Kind.FRIEND:
			if aff >= COUPLE_AT and partner_id(a) == 0 and partner_id(b) == 0 and attraction(a, b) >= ROMANCE:
				_bonds[k] = Kind.COUPLE
				return Event.COUPLE
			if aff < FRIEND_KEEP:
				_bonds.erase(k)
				return Event.DRIFTED   # Se distanciaron (sin cartel)
		Kind.ENEMY:
			if aff > ENEMY_KEEP:
				_bonds.erase(k)
				return Event.MADE_UP
		_:
			if aff >= FRIEND_AT:
				_bonds[k] = Kind.FRIEND
				return Event.FRIENDS
			if aff <= ENEMY_AT:
				_bonds[k] = Kind.ENEMY
				return Event.ENEMIES
	return Event.NONE

## Se murió o ya no está: deja de contar para los demás (en el historial queda con el nombre
## que tenía).
static func forget(v: Villager) -> void:
	for e in history:
		for side: String in ["a", "b"]:
			if e[side] == v.id_number:
				e[side + "_name"] = v.full_name()
	for k: Vector2i in _affinity.keys():
		if k.x == v.id_number or k.y == v.id_number:
			_affinity.erase(k)
			_bonds.erase(k)

## Para la partida guardada: [carnet, carnet, afinidad, Kind] de los que se guardan (ids).
static func save_state(ids: Array) -> Array:
	var rows := []
	for k: Vector2i in _affinity:
		if ids.has(k.x) and ids.has(k.y):
			rows.append([k.x, k.y, _affinity[k], _bonds.get(k, Kind.NONE)])
	return rows

static func load_state(rows: Array) -> void:
	clear()
	for r: Array in rows:
		if r.size() < 4:
			continue
		var k := Vector2i(mini(r[0], r[1]), maxi(r[0], r[1]))
		_affinity[k] = float(r[2])
		if int(r[3]) != Kind.NONE:
			_bonds[k] = int(r[3])

## Para la partida guardada (va después de load_state, que borra todo).
static func load_history(rows: Array) -> void:
	history.clear()
	for e: Dictionary in rows:
		if e.has_all(["time", "event", "a", "b"]):
			history.append(e)
	history_version += 1
