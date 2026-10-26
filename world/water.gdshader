shader_type canvas_item;

// El mar. Trabaja en coordenadas globales (como waterline.gdshader) y Sea (sea.gd) le pasa
// cada cuadro el color del cielo, dónde está el sol o la luna, la forma de la isla y los
// anillos de lo que cae al agua.
// - Lejos es claro y refleja el cielo (de tarde se pone naranja); adelante es hondo.
// - Perspectiva: todo se ve chiquito y apretado en el horizonte y crece hacia adelante.
// - Crestas: manchas claras con borde de espuma que avanzan y cambian de forma.
// - Debajo del astro, su reflejo: una columna de rayitas que titilan (larga y naranja
//   con el sol bajo). Y destellos sueltos por todo el mar.
// - Alrededor de la isla, la laguna turquesa, la espuma de la orilla y olitas que salen.

uniform vec4 far_color    : source_color = vec4(0.45, 0.84, 1.0, 1.0);   // En el horizonte
uniform vec4 deep_color   : source_color = vec4(0.02, 0.36, 0.78, 1.0);  // Adelante
uniform vec4 crest_color  : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform vec4 lagoon_color : source_color = vec4(0.3, 0.92, 0.88, 1.0);
uniform vec4 foam_color   : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float horizon_y = 408.0;
uniform float depth = 262.0;         // Del horizonte al borde de abajo del mar (px)
uniform float vanish_x = 576.0;      // Hacia dónde se achica todo
uniform float far_scale = 0.22;      // Qué tan chiquito se ve todo en el horizonte (1 = adelante)
uniform float squash = 0.42;         // El piso visto desde arriba: un círculo se ve así de aplastado

// Los pasa Sea cada cuadro
uniform vec3 sky_color = vec3(0.035, 0.627, 1.0);   // Ya compensado por el tinte de la noche
uniform vec2 glint_pos = vec2(928.0, 109.0);
uniform vec3 glint_color = vec3(1.0, 0.92, 0.6);
uniform float glint = 0.0;           // 0 = no hay astro, 1 = el reflejo a pleno
uniform vec2 isle_center = vec2(588.0, 480.0);
uniform float isle_r[72];            // Radio de la orilla (px de piso) cada 5°, empezando en -180°
uniform vec4 ripples[8];             // xy = centro, z = edad (s), w = tamaño (0 = libre)

const int BINS = 72;                 // Igual que Sea.BINS
const float RIPPLE_LIFE = 1.8;       // Igual que Sea.RIPPLE_LIFE

varying vec2 world_pos;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0 -> 1 cuando f pasa de negativo a positivo, con el borde suavizado (1 px de pantalla)
float edge(float f) {
    return clamp(f / max(fwidth(f), 1e-4) + 0.5, 0.0, 1.0);
}

// 1 donde f cruza el cero, en una raya de w px de pantalla
float line(float f, float w) {
    float px = abs(f) / max(fwidth(f), 1e-4);
    return 1.0 - smoothstep(w * 0.5 - 0.5, w * 0.5 + 0.5, px);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    float t = TIME;
    float v = clamp((world_pos.y - horizon_y) / depth, 0.0, 1.0);   // 0 = horizonte, 1 = adelante
    float s = mix(far_scale, 1.0, v);                                // Tamaño aparente
    // Posición sobre el piso del mar (px de piso): lo lejano queda estirado
    vec2 P = vec2((world_pos.x - vanish_x) / s, depth / (1.0 - far_scale) * log(s) / squash);
    // Más adelante del borde de abajo de siempre (se ve con el zoom alejado) ya no se achica:
    // el piso sigue de a 1 px de pantalla
    P.y += max(world_pos.y - horizon_y - depth, 0.0) / squash;

    // Color base: lejos refleja el cielo (más claro cerca del horizonte), adelante es hondo
    vec3 sky = mix(sky_color, vec3(1.0), 0.3);
    vec3 col = mix(mix(far_color.rgb, sky, 0.55), deep_color.rgb, pow(v, 0.7));

    // Mar de fondo: ondas largas que vienen hacia adelante
    float swell = sin(P.y * 0.03 - t * 1.3 + sin(P.x * 0.006 + t * 0.25) * 2.0);
    col *= 1.0 + swell * 0.05 * smoothstep(0.0, 0.25, v);

    // Crestas: dos capas de ruido que se mueven distinto, así cambian de forma
    vec2 q = P * vec2(1.0 / 120.0, 1.0 / 46.0);
    float n = noise(q + vec2(t * 0.04, -t * 0.2)) * 0.6
            + noise(q * 1.8 + vec2(-t * 0.06, -t * 0.32) + 3.7) * 0.4;
    float far_fade = smoothstep(0.02, 0.3, v);   // En el horizonte no se distinguen
    col = mix(col, crest_color.rgb, edge(n - 0.6) * far_fade * 0.3);
    float broken = smoothstep(0.35, 0.6, noise(q * 0.7 + vec2(11.0, t * 0.05)));
    col = mix(col, foam_color.rgb, line(n - 0.6, 1.3) * broken * far_fade * 0.5);

    // Distancia a la orilla (px de piso), del radio de la isla en esa dirección
    vec2 g = (world_pos - isle_center) * vec2(1.0, 1.0 / squash);
    float fi = (atan(g.y, g.x) / TAU + 0.5) * float(BINS);
    int i0 = int(floor(fi)) % BINS;
    int i1 = (i0 + 1) % BINS;
    float R = mix(isle_r[i0], isle_r[i1], fract(fi));
    float dR = (isle_r[i1] - isle_r[i0]) * float(BINS) / TAU;
    float shore = (length(g) - R) * R / sqrt(R * R + dR * dR);   // Corregido si la orilla va en diagonal

    // Laguna: dos escalones de turquesa con el borde que ondula
    float wob = (noise(g / 40.0 + vec2(t * 0.15, 0.0)) - 0.5) * 12.0;
    float lagoon = (1.0 - edge(shore + wob - 72.0)) * 0.32 + (1.0 - edge(shore + wob * 0.6 - 30.0)) * 0.3;
    col = mix(col, lagoon_color.rgb, lagoon);

    // Reflejo del astro: adelante se rompe en rayitas; pegado al horizonte es una raya
    // llena, pero esa solo con el astro bajo (alto, el reflejo de lejos casi no se ve)
    float dx = world_pos.x - glint_pos.x;
    float half_w = mix(5.0, 44.0, v) * (0.6 + glint * 0.5);
    float column = exp(-dx * dx / (half_w * half_w));
    float row = P.y / 15.0;
    float rnd = hash(vec2(floor(row), 7.0));
    float len = half_w * (0.3 + 0.7 * (0.5 + 0.5 * sin(t * (1.5 + rnd * 2.5) + rnd * 40.0)));
    float off = sin(t * 1.1 + rnd * 17.0) * half_w * 0.45;
    float stroke = (1.0 - smoothstep(len * 0.5, len, abs(dx - off))) * line(fract(row) - 0.5, mix(1.0, 2.5, v));
    float path = mix(column * glint, stroke, smoothstep(0.0, 0.25, v));
    col = mix(col, glint_color, clamp(path * glint, 0.0, 1.0) * 0.9);

    // Destellos sueltos: cada celda tiene uno que se prende de golpe y se apaga
    vec2 cell = vec2(34.0, 28.0);
    vec2 ci = floor(P / cell);
    vec2 h = vec2(hash(ci), hash(ci + 19.3));
    vec2 sd = (P - (ci + 0.2 + 0.6 * h) * cell) * vec2(s, s * squash);   // A px de pantalla
    float pulse = pow(max(0.0, sin(t * (1.0 + h.x * 2.0) + h.y * 60.0)), 10.0);
    float spark = max(0.0, 1.0 - (abs(sd.x) + abs(sd.y) * 1.8) / (2.6 * pulse + 0.01));
    spark *= step(0.45, hash(ci + 5.1)) * smoothstep(0.08, 0.35, v) * glint * (0.45 + 1.5 * column);
    col = mix(col, mix(vec3(1.0), glint_color, 0.4), clamp(spark, 0.0, 1.0));

    // Espuma de la orilla, que respira, y olitas que salen de la isla
    float foam = 1.0 - edge(shore - 5.0 - 4.0 * noise(g / 14.0 + vec2(0.0, t * 0.8)));
    for (int k = 0; k < 2; k++) {
        float ph = fract(t * 0.2 + float(k) * 0.5);
        float dashes = smoothstep(0.3, 0.55, noise(g / 24.0 + float(k) * 7.0 + vec2(t * 0.1, 0.0)));
        float a = (1.0 - ph) * smoothstep(0.0, 0.15, ph) * dashes;
        foam = max(foam, line(shore - mix(8.0, 50.0, ph), 2.0) * a * 0.8);
    }

    // Anillos donde cae algo
    for (int i = 0; i < 8; i++) {
        vec4 rp = ripples[i];
        if (rp.w <= 0.0) {
            continue;
        }
        float k = clamp(rp.z / RIPPLE_LIFE, 0.0, 1.0);
        float r = (10.0 + 80.0 * (1.0 - (1.0 - k) * (1.0 - k))) * rp.w;
        float d = length((world_pos - rp.xy) * vec2(1.0, 1.0 / squash));
        float a = pow(1.0 - k, 1.5) * smoothstep(0.0, 0.05, k);
        foam = max(foam, (line(d - r, 2.0) + line(d - r * 0.6, 1.5) * 0.6) * a);
    }
    col = mix(col, foam_color.rgb, clamp(foam, 0.0, 1.0) * 0.85);

    // Horizonte: bruma del color del cielo y una raya clara
    float hz = world_pos.y - horizon_y;
    col = mix(col, sky, (1.0 - smoothstep(0.0, 26.0, hz)) * 0.4);
    col = mix(col, mix(sky, vec3(1.0), 0.45), 1.0 - smoothstep(0.0, 2.0, hz));

    COLOR = vec4(col, 1.0);
}
