shader_type canvas_item;

// Inundación del diluvio (ver Storm): el agua tapa la isla desde la orilla hacia el centro.
// Va en una copia del dibujo de la isla, encima de la arena. La orilla es la misma que usa el
// mar para la laguna (ver Sea.fit_island): rel = distancia al centro de la isla respecto a la
// orilla en esa dirección, medida en el piso (desaplastado). 1 = el borde del dibujo.

const int BINS = 72;                 // Igual que Sea.BINS

uniform vec2 isle_center = vec2(588.0, 480.0);
uniform float isle_r[72];            // Radio de la orilla (px de piso) cada 5°, empezando en -180°
uniform float squash = 0.42;
uniform float line = 1.0;            // Hasta dónde llega el agua, en rel (1 = la isla seca)
uniform float time = 0.0;
uniform vec4 shallow : source_color = vec4(0.42, 0.86, 0.9, 0.6);   // Recién mojado, en la orilla del agua
uniform vec4 deep : source_color = vec4(0.14, 0.52, 0.8, 0.92);     // Afuera, donde ya está hondo
uniform vec4 foam : source_color = vec4(1.0, 1.0, 1.0, 0.95);

varying vec2 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    float sand = texture(TEXTURE, UV).a;
    vec2 g = (world_pos - isle_center) * vec2(1.0, 1.0 / squash);
    float ang = atan(g.y, g.x);
    float fi = (ang / TAU + 0.5) * float(BINS);
    int i0 = int(floor(fi)) % BINS;
    int i1 = (i0 + 1) % BINS;
    float rel = length(g) / max(mix(isle_r[i0], isle_r[i1], fract(fi)), 1.0);

    // La orilla del agua ondula y las olas entran y salen
    float wl = line + sin(ang * 7.0 + time * 1.7) * 0.012 + sin(ang * 17.0 - time * 2.6) * 0.006;
    float px = max(fwidth(rel), 0.001);   // Un píxel, en rel
    float wet = smoothstep(wl - px, wl + px, rel);
    vec4 water = mix(shallow, deep, clamp((rel - wl) / 0.25, 0.0, 1.0));
    // Espuma en la orilla del agua, y una franja que va y viene un poco más afuera
    float shore = 1.0 - smoothstep(px, px * 3.0 + 0.008, abs(rel - wl));
    float swash = 1.0 - smoothstep(0.0, px * 2.0 + 0.006, abs(rel - wl - 0.04 - 0.025 * sin(time * 2.2 + ang * 3.0)));
    float white = max(shore, swash * 0.55 * wet);
    vec3 col = mix(water.rgb, foam.rgb, white);
    float alpha = max(wet * water.a, shore * foam.a);
    COLOR = vec4(col, alpha * sand * step(wl, 0.999));
}
