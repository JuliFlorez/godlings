extends RefCounted
class_name VillagerStats
## Las estadísticas: cómo es cada uno, de 0 a 100. Por ahora solo el carisma: qué tan bien cae y
## cuánto convence. Los carismáticos charlan mejor (ver Relations.chat_delta), así que juntan más
## amigos; y charlando, cada uno le contagia al otro lo que cree en vos, más cuanto más carisma
## tiene (ver exchange). El más aceptado de la isla es el líder de la tribu (ver Tribe), que
## convence mucho más. Cada uno nace con el suyo y no cambia; los bebés salen parecidos a sus
## padres (ver inherit). Se ve en el carnet y se guarda con la partida.
## Es una parte del aldeano (Villager la crea en _init): v es él. Desde afuera se usa lo que el
## aldeano reenvía (charisma, persuasion...).

const CHARISMA_MEAN := 50.0             # La mayoría, cerca del medio
const CHARISMA_SPREAD := 18.0
const CHARISMA_MIN := 5.0
const INHERIT_SPREAD := 12.0            # Lo que se aleja el bebé del promedio de sus padres
const PERSUADE := 0.15                  # De lo que los separa en la fe, lo que convence uno con carisma 100 en una charla

var charisma := CHARISMA_MEAN

var v: Villager

func _init(villager: Villager) -> void:
	v = villager
	charisma = roll(CHARISMA_MEAN, CHARISMA_SPREAD)   # Las partidas guardadas y los bebés traen el suyo

## Un carisma al azar alrededor de mean.
static func roll(mean: float, spread: float) -> float:
	return clampf(randfn(mean, spread), CHARISMA_MIN, 100.0)

## Para la partida guardada (ver Villager.to_dict).
func to_dict() -> Dictionary:
	return {"charisma": charisma}

func from_dict(d: Dictionary) -> void:
	charisma = d.get("charisma", charisma)   # Las partidas de antes no lo traen: queda el que le tocó

## Bebé de a y b: sale parecido a ellos.
func inherit(a: Villager, b: Villager) -> void:
	charisma = roll((a.charisma + b.charisma) * 0.5, INHERIT_SPREAD)

## Cuánto convence: de 0 a 1 por su carisma, y si es el líder de la tribu, varias veces más.
func sway() -> float:
	return charisma / 100.0 * (Tribe.LEADER_WEIGHT if Tribe.is_leader(v) else 1.0)

## Cuánta fe le cambiaría a o por charlar (bien) con él: la fe de o se acerca a la suya, más
## cuanto más convence (ver sway).
func persuasion(o: Villager) -> float:
	return (v.faith - o.faith) * minf(1.0, PERSUADE * sway())

## a y b terminaron de charlar bien: cada uno le contagia al otro lo que cree en vos (los dos
## desde lo que creían antes de charlar).
static func exchange(a: Villager, b: Villager) -> void:
	var to_b := a.persuasion(b)
	var to_a := b.persuasion(a)
	b.add_faith(to_b)
	a.add_faith(to_a)
