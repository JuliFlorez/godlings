shader_type canvas_item;

uniform vec4 shallow_color : source_color = vec4(0.27, 0.78, 1.0, 1.0);
uniform vec4 deep_color    : source_color = vec4(0.02, 0.40, 0.80, 1.0);

uniform float wave_scale = 30.0;   // frecuencia
uniform float wave_amp   = 0.05;   // altura (subí/bajá)
uniform float wave_speed = 1.2;    // velocidad

uniform float ripple_freq = 120.0; // rayas finas
uniform float ripple_strength = 0.08;

void fragment() {
    vec2 uv = UV;
    float t = TIME * wave_speed;

    // olas grandes que desplazan el UV
    float w = 0.5*sin(uv.x*wave_scale + t) +
              0.5*sin(uv.y*wave_scale*0.8 - t*0.9);
    uv.y += w * wave_amp;

    // color base (degradé)
    vec4 base = mix(shallow_color, deep_color, uv.y);

    // ripples finas (iluminan)
    float r = sin((uv.x + uv.y*1.2)*ripple_freq - t*6.0);
    float width = fwidth(r) * 1.5;
    float stripes = 1.0 - smoothstep(0.0, width, abs(r));
    base.rgb += stripes * ripple_strength;

    COLOR = base;
}
