extends RefCounted
class_name VillagerSounds
## Los sonidos del aldeano que no están grabados (el "¡wow!" al agarrarlo sí, ver Villager.WOW):
## se sintetizan (ver Synth) la primera vez que hacen falta y quedan guardados.

static var _babbles: Array[AudioStreamWAV] = []
static var _sneeze: AudioStreamWAV
static var _groan: AudioStreamWAV
static var _bite: AudioStreamWAV
static var _cough: AudioStreamWAV
static var _burst: AudioStreamWAV

## Un bla-bla al azar de los que hay (son varios, así no suenan todos iguales).
static func babble() -> AudioStreamWAV:
	if _babbles.is_empty():
		for i in 6:
			_babbles.append(_make_babble())
	return _babbles.pick_random()

static func sneeze() -> AudioStreamWAV:
	if _sneeze == null:
		_sneeze = _make_sneeze()
	return _sneeze

static func groan() -> AudioStreamWAV:
	if _groan == null:
		_groan = _make_groan()
	return _groan

static func bite() -> AudioStreamWAV:
	if _bite == null:
		_bite = _make_bite()
	return _bite

static func cough() -> AudioStreamWAV:
	if _cough == null:
		_cough = _make_cough()
	return _cough

static func burst() -> AudioStreamWAV:
	if _burst == null:
		_burst = _make_burst()
	return _burst

# ---- Cómo suenan ----
## "Bla-bla-bla": unas sílabas cortitas con la vocal que sube y baja de tono.
static func _make_babble() -> AudioStreamWAV:
	var rate := 22050
	var buf := PackedFloat32Array()
	var ph := 0.0
	for s in randi_range(4, 7):
		var n := int(rate * randf_range(0.05, 0.085))
		var f0 := randf_range(200.0, 300.0)
		var f1 := f0 * randf_range(0.8, 1.25)
		var bright := randf_range(0.2, 0.6)
		for i in n:
			var k := float(i) / n
			ph += TAU * lerpf(f0, f1, k) / rate
			var env := minf(1.0, k * 10.0) * minf(1.0, (1.0 - k) * 6.0)
			buf.append((sin(ph) + bright * sin(ph * 2.0) + 0.25 * sin(ph * 3.0)) * env * 0.3)
		for i in int(rate * randf_range(0.02, 0.045)):   # Pausita entre sílabas
			buf.append(0.0)
	return Synth.wav(buf, rate, 0.9)

## "Aaa... ¡chís!": una vocal que sube y un soplido de ruido.
static func _make_sneeze() -> AudioStreamWAV:
	var rate := 22050
	var vowel := int(rate * 0.24)
	var burst := int(rate * 0.2)
	var buf := PackedFloat32Array()
	buf.resize(vowel + burst)
	var ph := 0.0
	for i in vowel:
		var k := float(i) / vowel
		ph += TAU * lerpf(230.0, 360.0, k * k) / rate
		var env := minf(1.0, k * 12.0) * (0.55 + 0.45 * k)
		buf[i] = (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0)) * env * 0.35
	var prev := 0.0
	var hp := 0.0
	for i in burst:
		var k := float(i) / burst
		var noise := randf_range(-1.0, 1.0)
		hp = 0.85 * (hp + noise - prev)   # Pasa-altos: la "ch" y la "s"
		prev = noise
		var env := minf(1.0, k * 40.0) * pow(1.0 - k, 2.0)
		buf[vowel + i] = (hp * 0.8 + sin(ph + TAU * 420.0 * i / rate) * 0.25 * (1.0 - k)) * env
	return Synth.wav(buf, rate, 0.9)

## "Uuurgh": una vocal grave y ronca que baja.
static func _make_groan() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * Villager.GROAN_TIME)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(125.0, 80.0, k) * (1.0 + 0.03 * sin(k * 40.0)) / rate
		var saw := 0.0
		for h in range(1, 7):
			saw += sin(ph * h) / h
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)   # Aire
		var growl := 0.6 + 0.4 * sin(TAU * 28.0 * i / rate)   # Ronco
		var env := minf(1.0, k * 6.0) * pow(1.0 - k, 0.8)
		buf[i] = (saw * 0.4 * growl + lp * 0.5) * env
	return Synth.wav(buf, rate, 0.8)

## Mordida: un golpe sordo y un crujido.
static func _make_bite() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.22)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := 0.0
	var prev := 0.0
	var hp := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(160.0, 60.0, k) / rate
		var noise := randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + noise - prev)   # Pasa-altos: el crujido
		prev = noise
		var crunch := hp * (0.5 + 0.5 * signf(sin(k * 90.0)))   # A golpecitos
		buf[i] = (sin(ph) * 0.9 * pow(1.0 - k, 3.0) + crunch * 0.6 * pow(1.0 - k, 1.5)) * minf(1.0, k * 60.0)
	return Synth.wav(buf, rate, 0.9)

## "¡Cof, cof!": dos soplidos roncos.
static func _make_cough() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.42)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var k := fmod(t, 0.2) / 0.2   # Cada "cof" dura 0.2 s
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		ph += TAU * 170.0 / rate
		var loud := 1.0 if t < 0.2 else (0.7 if t < 0.4 else 0.0)
		var env := minf(1.0, k * 30.0) * pow(1.0 - k, 2.5) * loud
		buf[i] = (lp * 0.9 + sin(ph) * 0.3) * env
	return Synth.wav(buf, rate, 0.9)

## El tallo que revienta: un "¡pfuum!" sordo que se va apagando.
static func _make_burst() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerpf(lp, randf_range(-1.0, 1.0), lerpf(0.4, 0.05, k))   # Lo agudo se apaga primero
		ph += TAU * lerpf(140.0, 45.0, sqrt(k)) / rate
		var env := minf(1.0, k * 80.0) * pow(1.0 - k, 2.0)
		buf[i] = (lp * 1.6 + sin(ph) * 0.8 * pow(1.0 - k, 4.0)) * env
	return Synth.wav(buf, rate, 0.9)
