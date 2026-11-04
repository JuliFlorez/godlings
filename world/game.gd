extends RefCounted
class_name Game
## La partida que se está jugando: las monedas (ofrendas y sacrificios), la devoción, la XP y los
## puntos para agrandar la isla, lo que se compró en la tienda (los poderes, la Luna de Sangre y los
## tiburones) y todo lo demás que dura lo que dura una partida (ver reset).
## Es una clase con estáticos, como Settings: se llega desde cualquier lado sin buscar a nadie. El
## HUD solo la muestra: se entera de lo que cambia (y de los carteles que tiene que mostrar) por
## events; World también, para los orbes de la isla y los tiburones. Se guarda con la partida (ver
## save_state y World.save_game).

## Lo que pasa, para el que quiera enterarse.
class Events extends RefCounted:
	## Cambió algo de lo que muestra el HUD.
	signal changed
	## Se cargó una partida guardada (el HUD pone las barras en su lugar, sin animarlas).
	signal loaded
	## Ganaste ofrendas o sacrificios (el HUD hace brillar la moneda).
	signal offerings_gained(amount: int)
	signal sacrifices_gained(amount: int)
	## Un punto más para agrandar la isla (el HUD lo festeja)...
	signal point_earned
	## ...y cuántos hay ahora (World pone o saca los orbes de la isla).
	signal expansion_points_changed(points: int)
	## Se prendió o se apagó un tiburón (World lo suelta o lo saca).
	signal shark_changed(index: int, on: bool)
	## Un cartel flotante en at, en la pantalla (lo muestra el HUD, ver say).
	signal said(text: String, at: Vector2, color: Color)

static var events := Events.new()

## Con lo que se arranca.
const START_OFFERINGS := 20
## La devoción (la gastan invocar aldeanos, la comida y los milagros): hasta cuánto llega, y en
## cuántos segundos se llena desde cero (con la fe de la isla normal, ver refill).
const DEVOTION_MAX := 100.0
const DEVOTION_REFILL_TIME := 300.0
## La XP para cada punto de expansión (el último se repite).
const XP_PER_POINT: Array[int] = [3, 5, 8, 12, 16, 20]

static var offerings := START_OFFERINGS
## Los sacrificios para gastar: cada muerte suma (en el altar, más; ver Villager).
static var sacrifices := 0
static var devotion := DEVOTION_MAX
## La XP hacia el próximo punto de expansión y los puntos para gastar en agrandar la isla.
static var xp := 0
static var expansion_points := 0
static var _points_earned := 0
## El tamaño de la isla, que lo dice World (ver set_island): no se ganan más puntos que los tamaños
## que faltan.
static var island_level := 0
static var island_max := 0
## Lo comprado en la tienda (de cada poder, su unlocked: ver Power).
static var blood_moon := false
## Por tiburón (Shark.MAX): si está comprado y si está prendido. Si lo matan de un tiro deja de estar
## comprado: hay que volver a comprarlo.
static var shark_owned: Array[bool] = []
static var shark_on: Array[bool] = []

## Una partida nueva (World la arma al empezar, antes de cargar la guardada si la hay). Los estáticos
## sobreviven a "Menú principal", que recarga la escena, así que acá se borra todo lo de la partida
## que vive en estáticos, también lo de los demás. Un estático nuevo con algo de la partida va acá.
static func reset() -> void:
	offerings = START_OFFERINGS
	sacrifices = 0
	devotion = DEVOTION_MAX
	xp = 0
	expansion_points = 0
	_points_earned = 0
	island_level = 0
	island_max = 0
	blood_moon = false
	shark_owned.clear()
	shark_owned.resize(Shark.MAX)
	shark_on.clear()
	shark_on.resize(Shark.MAX)
	Villager.ids_issued = 0
	World.play_time = 0.0
	Relations.clear()
	Genealogy.clear()
	Storm.clear()
	events.changed.emit()

# ---- Devoción ----
## Se va recargando sola (rate: veces lo normal, según la fe de la isla; ver World._devotion_rate).
static func refill(dt: float, rate: float) -> void:
	if devotion >= DEVOTION_MAX:
		return
	devotion = minf(DEVOTION_MAX, devotion + DEVOTION_MAX / DEVOTION_REFILL_TIME * rate * dt)
	events.changed.emit()

static func spend_devotion(amount: float) -> bool:
	if devotion < amount:
		return false
	devotion -= amount
	events.changed.emit()
	return true

## Llena (la consola de trucos).
static func fill_devotion() -> void:
	devotion = DEVOTION_MAX
	events.changed.emit()

# ---- Ofrendas y sacrificios ----
static func add_offerings(amount: int) -> void:
	offerings += amount
	events.offerings_gained.emit(amount)
	events.changed.emit()

## Se murió un aldeano (ver Villager._grant_sacrifice_xp); en el altar, puede valer más.
static func add_sacrifices(amount := 1) -> void:
	sacrifices += amount
	events.sacrifices_gained.emit(amount)
	events.changed.emit()

static func can_afford(amount: int) -> bool:
	return offerings >= amount

static func spend_offerings(amount: int) -> bool:
	if offerings < amount:
		return false
	offerings -= amount
	events.changed.emit()
	return true

## Si alcanzan las ofrendas y los sacrificios (las cosas malas cuestan las dos monedas).
static func can_buy(price: int, sacrifice_cost := 0) -> bool:
	return offerings >= price and sacrifices >= sacrifice_cost

## Cobra price ofrendas y sacrifice_cost sacrificios (o nada, si no alcanza alguna).
static func buy(price: int, sacrifice_cost := 0) -> bool:
	if not can_buy(price, sacrifice_cost):
		return false
	offerings -= price
	sacrifices -= sacrifice_cost
	events.changed.emit()
	return true

# ---- XP y puntos de expansión ----
## Si todavía se pueden ganar puntos (no más que los tamaños de isla que faltan).
static func can_earn_points() -> bool:
	return island_max == 0 or island_level + expansion_points < island_max

static func xp_needed() -> int:
	return XP_PER_POINT[mini(_points_earned, XP_PER_POINT.size() - 1)]

## Cada sacrificio suma 1 (ver Villager); al llenarse, un punto para agrandar la isla.
static func add_xp(amount: int) -> void:
	if not can_earn_points():
		return
	xp += amount
	while xp >= xp_needed() and can_earn_points():
		xp -= xp_needed()
		_points_earned += 1
		expansion_points += 1
		events.point_earned.emit()
		events.expansion_points_changed.emit(expansion_points)
	if not can_earn_points():
		xp = 0
	events.changed.emit()

static func spend_expansion_point() -> bool:
	if expansion_points <= 0:
		return false
	expansion_points -= 1
	events.expansion_points_changed.emit(expansion_points)
	events.changed.emit()
	return true

## Puntos gratis (la consola de trucos).
static func add_expansion_points(amount: int) -> void:
	expansion_points += amount
	events.expansion_points_changed.emit(expansion_points)
	events.changed.emit()

## El tamaño de la isla (World, cada vez que cambia).
static func set_island(level: int, max_level: int) -> void:
	island_level = level
	island_max = max_level
	events.changed.emit()

# ---- Tienda ----
## Compra un poder (ver Shop).
static func unlock_power(power: Power) -> bool:
	if power.unlocked or not buy(power.price, power.sacrifices):
		return false
	power.unlocked = true
	announce(power.unlocked_message(), power.unlock_color())
	events.changed.emit()
	return true

static func unlock_blood_moon() -> bool:
	if blood_moon or not buy(Moon.PRICE, Moon.SACRIFICES):
		return false
	blood_moon = true
	announce("¡Luna de Sangre desbloqueada! De noche, tocá la luna 5 veces", Color(1.0, 0.45, 0.4))
	events.changed.emit()
	return true

## Compra el primer tiburón que falta (se compran en orden).
static func buy_shark() -> bool:
	var index := shark_owned.find(false)
	if index < 0 or not buy(Shark.PRICE, Shark.SACRIFICES):
		return false
	give_shark(index)
	announce("¡Tiburón suelto en el agua!", UiStyle.C_DEVOTION)
	return true

## El tiburón index queda comprado y suelto (también la consola de trucos).
static func give_shark(index: int) -> void:
	shark_owned[index] = true
	shark_on[index] = true
	events.shark_changed.emit(index, true)
	events.changed.emit()

static func set_shark_on(index: int, on: bool) -> void:
	if index < 0 or index >= shark_on.size() or not shark_owned[index] or shark_on[index] == on:
		return
	shark_on[index] = on
	events.shark_changed.emit(index, on)
	events.changed.emit()

## Lo mataron de un tiro: hay que volver a comprarlo.
static func lose_shark(index: int) -> void:
	shark_owned[index] = false
	shark_on[index] = false
	announce("¡Mataste al tiburón! Comprá otro en la tienda", UiStyle.C_WARN)
	events.changed.emit()

# ---- Carteles ----
## Un cartel flotante en at (en la pantalla): sube y se desvanece (lo muestra el HUD).
static func say(text: String, at: Vector2, color := UiStyle.C_TEXT) -> void:
	events.said.emit(text, at, color)

## Un cartel en el medio de la pantalla.
static func announce(text: String, color := UiStyle.C_TEXT) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		say(text, tree.root.get_visible_rect().size * Vector2(0.5, 0.42), color)

# ---- Partida guardada ----
## Lo que se guarda (ver World.save_game; va en game/hud, como cuando lo tenía el HUD).
static func save_state() -> Dictionary:
	var unlocks := {}
	for power in Power.all():
		if not power.always:
			unlocks[power.id] = power.unlocked
	return {
		"xp": xp,
		"energy": devotion,
		"offerings": offerings,
		"sacrifices": sacrifices,
		"expansion_points": expansion_points,
		"points_earned": _points_earned,
		"unlocked": unlocks,   # Los poderes comprados, {id: bool} (ver Power.id)
		"blood_moon": blood_moon,
		"shark_owned": shark_owned.duplicate(),
		"shark_on": shark_on.duplicate(),
	}

## Sigue una partida guardada (después de reset; ver World._load_game).
static func load_state(d: Dictionary) -> void:
	xp = d.get("xp", xp)
	devotion = clampf(d.get("energy", devotion), 0.0, DEVOTION_MAX)
	offerings = d.get("offerings", offerings)
	sacrifices = d.get("sacrifices", 0)
	expansion_points = d.get("expansion_points", expansion_points)
	_points_earned = d.get("points_earned", _points_earned)
	var unlocks: Dictionary = d["unlocked"] if d.has("unlocked") else _old_unlocks(d)
	for power in Power.all():
		if not power.always:
			power.unlocked = unlocks.get(power.id, false)
	blood_moon = d.get("blood_moon", false)
	var owned: Array = d.get("shark_owned", [])
	var on: Array = d.get("shark_on", [])
	for i in mini(shark_owned.size(), mini(owned.size(), on.size())):
		shark_owned[i] = owned[i]
		shark_on[i] = owned[i] and on[i]
		if shark_on[i]:
			events.shark_changed.emit(i, true)
	events.expansion_points_changed.emit(expansion_points)
	events.loaded.emit()
	events.changed.emit()

## Las partidas de antes (formato 1, ver SaveSlots.VERSION) guardaban cada poder con su propia clave,
## y los de Charm y Miracle en listas por tipo.
static func _old_unlocks(d: Dictionary) -> Dictionary:
	var unlocks := {}
	for power_id: String in ["gun", "lightning", "meteor", "tornado", "storm", "plague", "spore", "cure"]:
		unlocks[power_id] = d.get(power_id, false)
	var by_kind := {"charms": ["cupid", "discord", "friendship"], "miracles": ["resurrect", "shield", "vaccine"]}
	for list: String in by_kind:
		var ids: Array = by_kind[list]
		var saved: Array = d.get(list, [])
		for i in mini(saved.size(), ids.size()):
			unlocks[ids[i]] = saved[i]
	return unlocks
