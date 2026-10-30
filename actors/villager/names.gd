extends RefCounted
class_name Names
## Nombres al azar, juntando sílabas: el nombre es una del principio, a veces una del medio y una
## del final (de varón o de mujer); el apellido, igual pero con finales de apellido. Así casi
## nunca salen dos iguales, y entre los de la isla (vivos o muertos, ver Genealogy.names_taken)
## no se repite ninguno. Se los pone Villager al aparecer (los bebés llevan el apellido de los
## padres, ver Decoration._birth) y se pueden cambiar en el carnet.

const START := ["ba", "be", "bo", "bru", "ca", "ce", "co", "cla", "cri", "cha", "che", "chu", "da",
		"de", "di", "do", "dra", "fa", "fe", "fi", "flo", "ga", "go", "gre", "gu", "ja", "je", "jo", "ju",
		"la", "le", "li", "lo", "lu", "ma", "me", "mi", "mo", "na", "ne", "ni", "no", "pa", "pe", "pi",
		"pla", "pri", "ra", "re", "ri", "ro", "sa", "se", "si", "so", "ta", "te", "ti", "to", "tra", "va",
		"ve", "vi", "ya", "za", "ze"]
const MIDDLE := ["ba", "be", "bi", "ca", "co", "da", "di", "do", "fe", "ga", "gui", "la", "le", "li",
		"lo", "ma", "mi", "na", "ne", "ni", "ra", "re", "ri", "ro", "sa", "se", "ta", "te", "ti", "va",
		"vi", "lla", "ña"]
const END_MALE := ["n", "l", "r", "s", "do", "go", "lo", "mo", "no", "ro", "so", "to", "vo", "nio",
		"rio", "lio", "ran", "len", "mar", "ber", "dor", "tor", "rus", "mel"]
const END_FEMALE := ["da", "la", "ma", "na", "ra", "sa", "ta", "va", "lia", "nia", "ria", "ina", "ela",
		"isa", "lena", "rina", "mira", "bel"]
const END_LAST := ["rez", "nez", "dez", "lez", "guez", "ra", "ro", "ras", "ros", "les", "nes", "tes",
		"ni", "no", "ti", "to", "ga", "do", "da", "rra", "llo", "ño", "ña", "sen", "zar", "dal", "ral", "lar"]
const MIDDLE_FIRST := 0.5        # Probabilidad de que el nombre lleve una sílaba del medio...
const MIDDLE_LAST := 0.7         # ...y el apellido
const MAX_FIRST := 8             # Letras (así "Nombre Apellido" entra entero en las listas del carnet)
const MAX_LAST := 9
## Que no salga una mala palabra, ni metida adentro de un nombre
const BANNED := ["pene", "pedo", "pete", "pito", "teta", "caca", "caga", "culo", "pija", "poto",
		"orto", "nazi", "mierd", "verga", "coño", "puta", "puto", "chota"]

## Un nombre de varón o de mujer que no tenga nadie más en la isla.
static func first_name(tree: SceneTree, female: bool) -> String:
	return _unique(tree, END_FEMALE if female else END_MALE, MIDDLE_FIRST, MAX_FIRST)

## Un apellido que no tenga nadie más en la isla.
static func last_name(tree: SceneTree) -> String:
	return _unique(tree, END_LAST, MIDDLE_LAST, MAX_LAST)

static func _unique(tree: SceneTree, ends: Array, middle: float, max_len: int) -> String:
	var taken := Genealogy.names_taken(tree)
	var n := ""
	for i in 100:
		n = _make(ends, middle)
		if n.length() <= max_len and not taken.has(n) and _sounds_ok(n):
			break
	return n

static func _make(ends: Array, middle: float) -> String:
	var s: String = START.pick_random()
	if randf() < middle:
		s += MIDDLE.pick_random()
	s += ends.pick_random()
	return s[0].to_upper() + s.substr(1)

## Sin dos vocales iguales juntas (como "Tiina") ni malas palabras.
static func _sounds_ok(n: String) -> bool:
	var low := n.to_lower()
	for v in ["aa", "ee", "ii", "oo", "uu"]:
		if low.contains(v):
			return false
	for w: String in BANNED:
		if low.contains(w):
			return false
	return true
