shader_type canvas_item;

// Tiburón: la línea del agua (igual que waterline.gdshader) y la boca que se abre.
// La mandíbula gira alrededor de la comisura y en el hueco se ve la boca por dentro, con dientes.
// Las medidas de la boca van en píxeles del dibujo (que mira a la izquierda).
uniform bool cut = false;
uniform float water_y = 0.0;
uniform float wave_amp = 1.5;      // Ondulación de la línea
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 0.8);

uniform float jaw = 0.0;                   // Apertura en radianes (0 = cerrada)
uniform vec2 hinge = vec2(170.0, 176.0);   // Comisura: la mandíbula gira acá
uniform vec2 snout = vec2(40.0, 170.0);    // Punta del hocico, arriba de la boca
uniform float lip = 112.0;                 // Distancia de la comisura a la punta del labio de abajo
uniform vec4 mouth_color : source_color = vec4(0.30, 0.02, 0.05, 1.0);
uniform vec4 tongue_color : source_color = vec4(0.80, 0.27, 0.32, 1.0);
uniform vec4 tooth_color : source_color = vec4(1.0, 0.97, 0.86, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.08, 1.0);

const float TOOTH_W = 16.0;
const float TOOTH_H = 14.0;
const float LINE = 3.0;            // Grosor del contorno

varying vec2 world_pos;
varying vec4 tint;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    tint = COLOR;
}

vec2 rotate(vec2 v, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// > 0 adentro de un diente. along: distancia desde la comisura; depth: cuánto se mete en la boca.
float tooth(float along, float depth, float phase) {
    float tri = 1.0 - abs(fract(along / TOOTH_W + phase) - 0.5) * 2.0;
    return TOOTH_H * smoothstep(10.0, 40.0, along) * tri - depth;
}

vec4 open_mouth(sampler2D tex, vec2 uv, vec4 col, vec2 size) {
    vec2 p = uv * size;
    vec2 ax = normalize(snout - hinge);    // De la comisura hacia la punta
    vec2 down = vec2(ax.y, -ax.x);
    float len = length(snout - hinge);

    // Punto de la mandíbula cerrada que, con la boca abierta, cae acá
    vec2 q = hinge + rotate(p - hinge, jaw);
    float q_along = dot(q - hinge, ax);
    float q_down = dot(q - hinge, down);
    // (Lo que está más adelante que el labio de abajo es el diente de arriba que cuelga: no se mueve)
    if (q_along > 0.0 && q_along < lip + 4.0 && q_down > 0.0 && all(greaterThanEqual(q, vec2(0.0))) && all(lessThan(q, size))) {
        vec4 jaw_px = texture(tex, q / size) * tint;
        if (jaw_px.a > 0.01) {
            return jaw_px;
        }
    }

    float p_along = dot(p - hinge, ax);
    float p_down = dot(p - hinge, down);
    if (p_along <= 0.0 || p_down <= 0.0 || (p_along > lip + 4.0 && col.a > 0.01)) {
        return col;    // Cabeza y cuerpo: quedan donde están
    }
    // Donde estaba la mandíbula: el hueco de la boca, o nada.
    // Adelante lo cierra una línea de la punta del hocico a la punta del labio de abajo.
    float lift = -q_down;    // Altura sobre la mandíbula
    float front = mix(len, lip, p_down / max(p_down + lift, 0.001)) - length(p - hinge);
    if (q_down >= 0.0 || front < 0.0) {
        return vec4(0.0);
    }
    float edge = min(min(p_down, lift), front);
    float t = max(tooth(p_along, p_down, 0.0), tooth(q_along, lift, 0.5)) - smoothstep(14.0, 0.0, front) * TOOTH_H;
    vec4 c;
    if (t > 0.0) {
        c = t < LINE ? ink : tooth_color;
    } else if (edge < LINE) {
        c = ink;
    } else {
        float tongue = smoothstep(16.0, 4.0, lift) * smoothstep(25.0, 55.0, q_along) * smoothstep(len - 5.0, len - 35.0, q_along);
        c = mix(mouth_color, tongue_color, tongue);
        c.rgb *= mix(0.6, 1.0, smoothstep(0.0, 50.0, p_along));    // Más oscuro hacia la garganta
    }
    return c * tint;
}

void fragment() {
    vec4 col = COLOR;
    if (jaw > 0.001) {
        col = open_mouth(TEXTURE, UV, col, 1.0 / TEXTURE_PIXEL_SIZE);
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
