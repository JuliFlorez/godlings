shader_type canvas_item;

// Aldeano flotando: lo que queda debajo de la línea del agua (coords globales) no se ve.
// También la muerte por rayo (ver Villager.zap): los cuadros de rayos X (el cuerpo se vuelve
// una silueta oscura y encima se ve el esqueleto, que dibuja VillagerRig.XRay), el cuerpo
// carbonizado con brasas y el desarmarse en cenizas de la cabeza a los pies.
uniform bool cut = false;
uniform float water_y = 0.0;
uniform float wave_amp = 1.5;      // Ondulación de la línea
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 0.8);

uniform bool xray = false;
uniform vec4 xray_color : source_color = vec4(0.05, 0.08, 0.22, 1.0);
uniform float burnt = 0.0;         // 0 = normal, 1 = carbonizado
uniform float embers = 0.0;        // Brasas que titilan sobre lo carbonizado
uniform float crumble = -1.0;      // Lo que ya se hizo cenizas, medido desde la coronilla (< 0: nada)
uniform vec2 crumble_from = vec2(0.0);       // Coronilla (global)
uniform vec2 crumble_axis = vec2(0.0, 1.0);  // De la cabeza a los pies
uniform vec4 ember_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);

const float GRAIN = 4.0;           // Ancho del borde que se desgrana (px)

varying vec2 world_pos;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec4 col = COLOR;
    float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    if (xray) {
        col.rgb = xray_color.rgb + vec3(0.05, 0.1, 0.25) * lum;
    } else if (burnt > 0.0) {
        // Negro carbón; lo blanco (los ojos) se salva
        vec3 coal = vec3(0.08, 0.065, 0.055) + col.rgb * 0.12;
        vec3 b = mix(coal, col.rgb * 0.85, smoothstep(0.72, 0.88, lum));
        float speck = hash(floor(world_pos * 0.7));
        float e = step(0.95, speck) * embers * (0.55 + 0.45 * sin(TIME * 8.0 + speck * 40.0));
        b = mix(b, ember_color.rgb, e);
        col.rgb = mix(col.rgb, b, burnt);
    }
    if (crumble >= 0.0) {
        vec2 rel = world_pos - crumble_from;
        float side = dot(rel, vec2(-crumble_axis.y, crumble_axis.x));
        float edge = crumble + sin(side * 0.9) * 1.5 + sin(side * 2.3 + 1.7);
        float d = dot(rel, crumble_axis) - edge;   // < 0: ya es ceniza
        if (d < 0.0 || (d < GRAIN && hash(floor(world_pos)) > d / GRAIN)) {
            discard;
        }
        // El borde que se está deshaciendo arde
        col.rgb = mix(col.rgb, ember_color.rgb, (1.0 - smoothstep(0.0, GRAIN * 1.5, d)) * 0.9);
    }
    if (cut) {
        float line = water_y + sin(world_pos.x * 0.35 + TIME * 3.0) * wave_amp;
        float d = world_pos.y - line;
        if (d > 0.0) {
            discard;
        }
        // Espuma: franja clara justo arriba de la línea
        float foam = smoothstep(-2.5, 0.0, d);
        col.rgb = mix(col.rgb, foam_color.rgb, foam * foam_color.a);
    }
    COLOR = col;
}
