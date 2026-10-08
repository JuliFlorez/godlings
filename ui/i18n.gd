extends RefCounted
class_name I18n
## Traducciones. El juego está escrito en español: cada clave es el texto original
## tal cual aparece en el código (incluidos los %d y los saltos de línea).
## Para agregar un idioma: otro diccionario igual y registrarlo en register().

const EN := {
	# HUD
	"Devoción": "Devotion",
	"Aldeanos": "Villagers",
	"Isla": "Island",
	"Puntos": "Points",
	"Ofrendas": "Offerings",
	"Tienda": "Shop",
	"Máx": "Max",
	"Invocar aldeano\n−%d devoción": "Summon villager\n−%d devotion",
	"Isla al máximo\n—": "Island maxed\n—",
	"Expandir isla\n1 punto": "Expand island\n1 point",
	"Expandir isla\n%d puntos": "Expand island\n%d points",
	"Sacar o guardar la pistola [G]": "Draw or holster the gun [G]",
	"Desbloqueala en la tienda (%d ofrendas)": "Unlock it in the shop (%d offerings)",
	"Click en la isla para colocar · click derecho o Esc para terminar.": "Click the island to place · right click or Esc to finish.",
	"Click para disparar · click derecho, Esc o G para guardarla.": "Click to shoot · right click, Esc or G to holster it.",
	"Isla llena: sacrificá aldeanos para ganar puntos y expandirla.": "Island full: sacrifice villagers to earn points and expand it.",
	"Devoción insuficiente: se recarga con el tiempo.": "Not enough devotion: it refills over time.",
	"¡Tocá un orbe + en la isla para expandirla!": "Tap a + orb on the island to expand it!",
	"+1 punto de expansión": "+1 expansion point",
	"¡Pistola desbloqueada! Sacala con G": "Gun unlocked! Draw it with G",
	"¡Luna de Sangre desbloqueada! De noche, tocá la luna 5 veces": "Blood Moon unlocked! At night, tap the moon 5 times",
	"¡Tiburón suelto en el agua!": "A shark is loose in the water!",
	"EN LA TIENDA": "IN THE SHOP",
	"PRÓXIMAMENTE": "COMING SOON",
	"Pistola": "Gun",
	"Rayo": "Lightning",
	"Meteorito": "Meteor",
	"Tornado": "Tornado",
	"Diluvio": "Flood",
	"Fulminá aldeanos desde el cielo": "Strike villagers down from the sky",
	"Un meteorito que deja un cráter en la isla": "A meteor that leaves a crater on the island",
	"Un tornado que levanta aldeanos por el aire": "A tornado that lifts villagers into the air",
	"Una tormenta que inunda la orilla": "A storm that floods the shore",
	# Tienda
	"Ganás ofrendas con cada sacrificio y cuando tus aldeanos rezan.": "You earn offerings with every sacrifice and when your villagers pray.",
	"Decoración para la isla": "Island decorations",
	"Cielo": "Sky",
	"Armas y poderes": "Weapons and powers",
	"Tiburones (máx. %d)": "Sharks (max %d)",
	"Tiburón %d": "Shark %d",
	"Luna de Sangre": "Blood Moon",
	"Sol de Sangre": "Blood Sun",
	"De noche, tocá la luna 5 veces. Soltale aldeanos encima para alimentarla.": "At night, tap the moon 5 times. Drop villagers on it to feed it.",
	"Colocar": "Place",
	"Desbloquear": "Unlock",
	"Desbloqueada": "Unlocked",
	"Próximamente": "Coming soon",
	"Comprar": "Buy",
	"Activo": "Active",
	"Apagado": "Off",
	"Activar": "Turn on",
	"Desactivar": "Turn off",
	"Palmera": "Palm tree",
	"Arbusto": "Bush",
	"Flores": "Flowers",
	"Roca": "Rock",
	"Antorcha": "Torch",
	# Mundo
	"+%d ofrendas": "+%d offerings",
	"Desbloqueá la pistola en la tienda": "Unlock the gun in the shop",
	"Solo sobre la isla": "Only on the island",
	"No te alcanzan las ofrendas": "Not enough offerings",
	"¡La isla está llena!": "The island is full!",
	"¡La isla creció! Capacidad: %d aldeanos": "The island grew! Capacity: %d villagers",
	# Menú de pausa
	"Pausa": "Paused",
	"Volumen general": "Master volume",
	"Música": "Music",
	"Idioma": "Language",
	"Continuar": "Resume",
	"Salir del juego": "Quit game",
	# Consola de trucos (F1)
	"Consola de trucos": "Cheat console",
	"escribí [b]ayuda[/b] o [b]help[/b]. F1 para cerrar.": "type [b]help[/b] or [b]ayuda[/b]. F1 to close.",
	"Comando (ayuda para ver la lista)": "Command (help for the list)",
	"Esta lista": "This list",
	"Suma ofrendas (por defecto 99999)": "Adds offerings (99999 by default)",
	"Llena la devoción": "Fills devotion",
	"Prende/apaga ofrendas y devoción infinitas": "Toggles infinite offerings and devotion",
	"Suma puntos de expansión (por defecto los que faltan para el máximo)": "Adds expansion points (by default, enough to max out)",
	"Pone la isla en ese nivel (por defecto el máximo)": "Sets the island to that level (max by default)",
	"Invoca aldeanos gratis (por defecto hasta llenar la isla)": "Summons free villagers (by default, until the island is full)",
	"Pistola, Luna de Sangre y todos los tiburones": "Gun, Blood Moon and every shark",
	"Todo lo anterior junto": "All of the above at once",
	"Borra la consola": "Clears the console",
	"+%d ofrendas (total %d)": "+%d offerings (total %d)",
	"Devoción llena": "Devotion full",
	"Ofrendas y devoción infinitas: %s": "Infinite offerings and devotion: %s",
	"SÍ": "ON",
	"NO": "OFF",
	"+%d puntos de expansión": "+%d expansion points",
	"Isla en nivel %d / %d": "Island at level %d / %d",
	"+%d aldeanos": "+%d villagers",
	"Desbloqueado: pistola, Luna de Sangre y %d tiburones": "Unlocked: gun, Blood Moon and %d sharks",
	"No conozco \"%s\". Escribí ayuda (o help).": "Unknown command \"%s\". Type help (or ayuda).",
}

static var _registered := false

static func register() -> void:
	if _registered:
		return
	_registered = true
	var en := Translation.new()
	en.locale = "en"
	# El español también se registra (cada texto se traduce a sí mismo): si no,
	# Godot cae al idioma de respaldo (inglés) para cualquier clave que encuentre.
	var es := Translation.new()
	es.locale = "es"
	for k: String in EN:
		en.add_message(k, EN[k])
		es.add_message(k, k)
	TranslationServer.add_translation(en)
	TranslationServer.add_translation(es)
