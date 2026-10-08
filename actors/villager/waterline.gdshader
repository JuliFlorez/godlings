shader_type canvas_item;

// Aldeano flotando: lo que queda debajo de la línea del agua (coords globales) no se ve.
uniform bool cut = false;
uniform float water_y = 0.0;
uniform float wave_amp = 1.5;      // Ondulación de la línea
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 0.8);

varying vec2 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    if (cut) {
        float line = water_y + sin(world_pos.x * 0.35 + TIME * 3.0) * wave_amp;
        float d = world_pos.y - line;
        if (d > 0.0) {
            discard;
        }
        // Espuma: franja clara justo arriba de la línea
        float foam = smoothstep(-2.5, 0.0, d);
        COLOR.rgb = mix(COLOR.rgb, foam_color.rgb, foam * foam_color.a);
    }
}
