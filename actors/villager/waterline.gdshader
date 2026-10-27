shader_type canvas_item;

// Cómo es cada aldeano (ver Villager.set_looks): la piel un poco más clara u oscura (y más
// amarilla o rojiza) y el pelo de otro color. La piel son los marrones anaranjados no muy
// saturados (así la pintura roja de la cara y las hojas no cambian) y el pelo, lo casi negro y
// sin color (también se tiñen un poco las pupilas, que casi no se nota).
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
uniform float skin_tone = 0.0;     // -1 más oscura .. 1 más clara
uniform float skin_warm = 0.0;     // -1 más amarilla .. 1 más rojiza
uniform vec3 hair_color = vec3(0.0);   // Lo que se le suma al negro del pelo (negro: como el dibujo)
uniform float sick = 0.0;          // Con gripe (ver Villager._update_flu): pálido y verdoso
uniform vec4 sick_color : source_color = vec4(0.78, 0.95, 0.62, 1.0);

const float GRAIN = 4.0;           // Ancho del borde que se desgrana (px)

varying vec2 world_pos;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec4 col = COLOR;
    vec3 hsv = rgb2hsv(col.rgb);
    float skin = (1.0 - smoothstep(0.075, 0.088, hsv.x)) * (1.0 - smoothstep(0.66, 0.74, hsv.y))
            * smoothstep(0.25, 0.32, hsv.y) * smoothstep(0.18, 0.26, hsv.z);
    vec3 tone = col.rgb * (1.0 + 0.22 * skin_tone) * vec3(1.0 + 0.06 * skin_warm, 1.0, 1.0 - 0.1 * skin_warm);
    col.rgb = mix(col.rgb, tone, skin);
    // Lo oscuro y sin color, de a poco (si no, el pelo con textura se ve granulado); lo casi negro,
    // aunque tenga algo de color (ahí la saturación no dice nada)
    float hair = (1.0 - smoothstep(0.0, 0.4, hsv.z)) * (1.0 - smoothstep(0.35, 0.55, hsv.y) * smoothstep(0.08, 0.2, hsv.z));
    col.rgb += hair_color * hair;
    float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
    if (sick > 0.0) {
        // Descolorido y tirando a verde (más claro, como pálido)
        col.rgb = mix(col.rgb, sick_color.rgb * (lum * 0.8 + 0.25), sick);
    }
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
