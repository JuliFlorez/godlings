extends RefCounted
class_name Synth
## Sonidos sintetizados (el trueno del rayo, el meteorito): de muestras a un AudioStreamWAV.

## Muestras en -1..1 (se multiplican por gain y se recortan) a un WAV mono de 16 bits.
static func wav(samples: PackedFloat32Array, rate: int, gain := 1.0) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
