shader_type canvas_item;

// Tiburón: la línea del agua (igual que waterline.gdshader) y la boca que se abre.
// La mandíbula gira alrededor de la comisura (con sus dientes del dibujo); entre los dientes se ve el fondo
// y solo queda un rincón oscuro en la comisura.
// Las medidas de la boca van en píxeles del dibujo (que mira a la izquierda).
uniform bool cut = false;
uniform float water_y = 0.0;
uniform float wave_amp = 1.5;      // Ondulación de la línea
uniform vec4 foam_color : source_color = vec4(0.85, 0.95, 1.0, 0.8);

uniform float jaw = 0.0;                   // Apertura en radianes (0 = cerrada)
uniform sampler2D jaw_mask : filter_nearest;   // Blanco: la mandíbula de abajo, con sus dientes; gris: se borra (la arma shark.gd)
uniform vec2 hinge = vec2(170.0, 176.0);   // Comisura: la mandíbula gira acá
uniform vec2 snout = vec2(40.0, 170.0);    // Punta del hocico, arriba de la boca
uniform float cheek = 40.0;                // Hasta dónde llega lo oscuro desde la comisura
uniform float jaw_rigid = 0.45;   // Ángulo bajo la línea hasta donde la mandíbula gira entera (rad)
uniform float jaw_skin = 2.0;     // Más abajo la papada se comprime, hasta quedar quieta acá
uniform vec4 mouth_color : source_color = vec4(0.30, 0.03, 0.06, 1.0);
uniform vec4 throat_color : source_color = vec4(0.07, 0.0, 0.02, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.05, 0.08, 1.0);

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

// 0 = cabeza, 0.5 = se borra con la boca abierta, 1 = mandíbula
float mask_at(vec2 p, vec2 size) {
    if (any(lessThan(p, vec2(0.0))) || any(greaterThanEqual(p, size))) {
        return 0.0;
    }
    return texture(jaw_mask, p / size).r;
}

// "a" encima de "b" (colores sin premultiplicar).
vec4 over(vec4 a, vec4 b) {
    float alpha = a.a + b.a * (1.0 - a.a);
    if (alpha <= 0.0) {
        return vec4(0.0);
    }
    return vec4((a.rgb * a.a + b.rgb * b.a * (1.0 - a.a)) / alpha, alpha);
}

// De abajo hacia arriba: el hueco de la boca, la cabeza (con los dientes de arriba) y la
// mandíbula (con los suyos), que gira entera. La papada de abajo se comprime hasta la comisura,
// así el contorno de la panza no se corta.
vec4 open_mouth(sampler2D tex, vec2 uv, vec4 col, vec2 size) {
    vec2 p = uv * size;
    vec2 ax = normalize(snout - hinge);    // De la comisura hacia la punta
    vec2 down = vec2(ax.y, -ax.x);
    vec2 rel = p - hinge;
    float r = length(rel);
    float ang = atan(dot(rel, down), dot(rel, ax));    // Bajo la línea de la boca: positivo

    // Papada: entre la mandíbula y jaw_skin se aprieta
    if (ang > jaw_rigid + jaw && ang < jaw_skin) {
        float k = jaw / (jaw_skin - jaw_rigid);
        float src = (ang - k * jaw_skin) / (1.0 - k);
        vec2 q2 = hinge + r * (cos(src) * ax + sin(src) * down);
        if (all(greaterThanEqual(q2, vec2(0.0))) && all(lessThan(q2, size))) {
            return texture(tex, q2 / size) * tint;
        }
        return vec4(0.0);
    }

    // El hueco: solo un rincón oscuro en la comisura, entre las dos mandíbulas.
    // Más adelante la boca abierta queda transparente (se ve el fondo entre los dientes).
    vec2 q = hinge + rotate(rel, jaw);    // Punto de la boca cerrada que, abierta, cae acá
    float lift = -dot(q - hinge, down);   // Altura sobre la mandíbula
    vec4 c = vec4(0.0);
    if (ang > -0.2 && lift > 0.0 && r < cheek) {
        c = ink;
        if (cheek - r >= LINE) {
            c = mix(throat_color, mouth_color, smoothstep(0.0, cheek, r));   // Más oscuro hacia la garganta
        }
        c *= tint;
    }
    if (mask_at(p, size) < 0.25) {
        c = over(col, c);
    }
    if (ang - jaw <= jaw_rigid && mask_at(q, size) > 0.75) {
        c = over(texture(tex, q / size) * tint, c);
    }
    return c;
}

void fragment() {
    vec4 col = COLOR;
    // La malla sobra por debajo del dibujo (para la mandíbula abierta): ahí no hay nada
    if (UV.y > 1.0) {
        col = vec4(0.0);
    }
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
