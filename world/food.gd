extends Node2D
class_name Food
## Algo que se comen los aldeanos cuando tienen hambre (ver Villager.hunger): un medio coco
## (ver Coconut), el pan que les tirás (ver Manna) o una baya de un arbusto (ver
## Decoration.BerryPick). El que tiene hambre lo busca (ver Villager._seek_food), lo reserva
## (claim), camina hasta eat_spot, lo come a mordiscos (nibble) y al terminar (finish_eating)
## se le va el hambre que diga nutrition. Los que se pueden encontrar tirados en el piso están
## en el grupo "food" (ver available).

var eater: Villager              # El que viene a comérselo (null: nadie)
var nutrition := 30.0            # El hambre que le saca
var _claimed := false            # Alguien lo reservó (aunque ya no esté: ver check_eater)

func _process(_dt: float) -> void:
	check_eater()

## Dónde está (los pies del que lo come quedan a esta altura).
func point() -> Vector2:
	return global_position

## Se lo puede venir a comer alguien (si está en el piso y nadie lo reservó). Ver las subclases.
func available() -> bool:
	return false

## Nadie lo reservó.
func is_free() -> bool:
	return not _claimed

## v viene a comérselo (ver Villager.go_eat).
func claim(v: Villager) -> void:
	eater = v
	_claimed = true

## Dónde se para el aldeano (su centro) para comerlo: al costado, con los pies a su altura.
func eat_spot(v: Villager) -> Vector2:
	var side := 1.0 if v.global_position.x >= point().x else -1.0
	return point() + Vector2(side * 17.0, -Villager.BODY_BOTTOM * v.scale.y)

## progress: 0..1 de lo que lleva comiendo.
func nibble(_progress: float) -> void:
	pass

## Se lo terminó: le saca el hambre y desaparece.
func finish_eating(v: Villager) -> void:
	v.feed(nutrition)
	queue_free()

## Ya no viene nadie a comérselo (lo agarraron, se fue o se cayó de la isla).
func release_eater() -> void:
	if is_instance_valid(eater) and eater.food == self:
		eater.stop_eating()
	eater = null
	if _claimed:
		_claimed = false
		_lost_eater()

## Si el que venía a comérselo ya no viene (lo agarraron, se distrajo o ya no está), queda
## libre para otro.
func check_eater() -> void:
	if not _claimed:
		return
	if is_instance_valid(eater) and eater.food == self and eater.is_idle():
		return
	eater = null
	_claimed = false
	_lost_eater()

## Para las subclases: se quedó sin quien se lo coma.
func _lost_eater() -> void:
	pass
