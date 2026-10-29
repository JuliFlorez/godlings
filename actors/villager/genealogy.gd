extends RefCounted
class_name Genealogy
## Quién es (o fue) cada aldeano, para el árbol genealógico (ver FamilyTree). Los que se mueren
## dejan la isla pero quedan anotados acá como eran: su nombre, su género, sus padres, su pareja
## y su piel y su pelo, con las canas que tenían (para la foto). De los vivos se toma lo que
## tienen ahora. Se guarda con la partida (los que se murieron antes de que esto existiera no
## están: salen como desconocidos).

static var _gone := {}   # carnet -> {first, last, gender, parents, partner, looks}

## Sin nadie (al arrancar el mundo, antes de cargar una partida).
static func clear() -> void:
	_gone.clear()

## Se murió (ver Villager._grant_sacrifice_xp): queda anotado como era, con su pareja.
static func remember(v: Villager) -> void:
	_gone[v.id_number] = {
		"first": v.first_name,
		"last": v.last_name,
		"gender": v.gender,
		"parents": Array(v.parents),
		"partner": Relations.partner_id(v),
		"looks": [v.skin_tone, v.skin_warm, v.hair_color, v.greyness()],
	}

## Lo que se sabe de alguien: {id, first, last, gender, parents, partner, looks, dead, villager
## (el aldeano, si todavía está en la isla)}. Vacío si no se sabe nada.
static func person(tree: SceneTree, id: int) -> Dictionary:
	for node in tree.get_nodes_in_group("villager"):
		var v := node as Villager
		if v and v.id_number == id and not v.is_queued_for_deletion():
			var dead := v.dead or v.eaten
			if dead and _gone.has(id):
				break   # Su cadáver todavía está, pero lo anotado al morirse tiene su pareja
			return {"id": id, "first": v.first_name, "last": v.last_name, "gender": v.gender,
					"parents": Array(v.parents), "partner": 0 if dead else Relations.partner_id(v),
					"looks": [v.skin_tone, v.skin_warm, v.hair_color, v.greyness()], "dead": dead, "villager": null if dead else v}
	if _gone.has(id):
		var p: Dictionary = _gone[id].duplicate()
		p.id = id
		p.dead = true
		p.villager = null
		return p
	return {}

## Sus hijos (vivos o muertos), del más grande al más chico.
static func children_of(tree: SceneTree, id: int) -> Array[int]:
	var out: Array[int] = []
	for node in tree.get_nodes_in_group("villager"):
		var v := node as Villager
		if v and id in v.parents and not v.is_queued_for_deletion() and not out.has(v.id_number):
			out.append(v.id_number)
	for k: int in _gone:
		if id in _gone[k].parents and not out.has(k):
			out.append(k)
	out.sort()
	return out

## Para la partida guardada: [carnet, nombre, apellido, género, padres, pareja, piel y pelo].
static func save_state() -> Array:
	var rows := []
	for k: int in _gone:
		var p: Dictionary = _gone[k]
		rows.append([k, p.first, p.last, p.gender, p.parents, p.partner, p.looks])
	return rows

static func load_state(rows: Array) -> void:
	_gone.clear()
	for r: Array in rows:
		if r.size() >= 7:
			_gone[r[0]] = {"first": r[1], "last": r[2], "gender": r[3], "parents": r[4], "partner": r[5], "looks": r[6]}
