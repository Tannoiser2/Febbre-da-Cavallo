// Cavallo animato senza scheletro: le zampe, la testa e la coda si piegano nel vertex shader.
// Il modello (assets/modelli/cavallo.glb) è lungo 5 unità, testa verso -Z, zoccoli a y = 0.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 colore : source_color = vec4(0.6, 0.35, 0.2, 1.0);
uniform float galoppo = 0.0;   // 0 fermo, 1 galoppo pieno
uniform float fase = 0.0;      // sfasamento tra un cavallo e l'altro
uniform float testa = 0.0;     // 0 testa alta (Attivo), 1 testa bassa (Disattivo)
uniform float spento = 0.0;    // 0 colori pieni, 1 un po' smorti
uniform float evidenzia = 0.0; // bagliore quando il cavallo si può scegliere
uniform float seduto = 0.0;    // 1 = azzoppato: seduto sul posteriore, muso a terra

vec3 ruota_x(vec3 p, float y0, float z0, float a) {
	float dy = p.y - y0;
	float dz = p.z - z0;
	float c = cos(a);
	float s = sin(a);
	return vec3(p.x, y0 + dy * c - dz * s, z0 + dy * s + dz * c);
}

void vertex() {
	vec3 p = VERTEX;
	float t = TIME * 11.0 + fase;
	float g = galoppo;
	float lato = p.x > 0.0 ? 0.0 : 0.7;
	// zampe anteriori (spalla a y 1.75, z -0.78)
	float m_ant = (1.0 - smoothstep(0.35, 0.6, abs(p.z + 0.78))) * clamp((1.85 - p.y) / 0.7, 0.0, 1.0);
	float a_ant = g * 0.6 * sin(t + lato);
	p = mix(p, ruota_x(p, 1.75, -0.78, a_ant * m_ant), step(0.001, m_ant));
	// zampe posteriori (anca a y 2.0, z 1.6)
	float m_post = (1.0 - smoothstep(0.4, 0.65, abs(p.z - 1.6))) * clamp((2.05 - p.y) / 0.8, 0.0, 1.0);
	float a_post = g * 0.55 * sin(t + 3.14159 + lato);
	p = mix(p, ruota_x(p, 2.0, 1.6, a_post * m_post), step(0.001, m_post));
	// testa e collo (attaccatura a y 2.35, z -1.05)
	float m_testa = smoothstep(-0.95, -1.35, p.z) * smoothstep(1.4, 2.0, p.y);
	float a_testa = -(testa * 0.95) - seduto * 0.25 + g * 0.1 * sin(2.0 * t);
	p = mix(p, ruota_x(p, 2.35, -1.05, a_testa * m_testa), step(0.001, m_testa));
	// coda
	float m_coda = smoothstep(2.0, 2.45, p.z) * smoothstep(1.9, 2.3, p.y);
	p.x += m_coda * (0.18 * sin(TIME * 2.0 + fase) + g * 0.25 * sin(t * 0.5));
	p.y += m_coda * g * 0.15;
	// il corpo va su e giù col galoppo
	p.y += g * 0.18 * (0.5 + 0.5 * sin(2.0 * t));
	p = ruota_x(p, 1.8, 0.0, g * 0.05 * sin(2.0 * t + 1.0));
	// azzoppato: il posteriore scende a terra (si siede), le zampe dietro si piegano sotto
	p = ruota_x(p, 0.0, -0.8, seduto * 0.22);
	p.y -= seduto * 1.15;
	p.y = mix(p.y, max(p.y, 0.06 + 0.1 * smoothstep(0.0, 1.5, p.z)), seduto);
	VERTEX = p;
}

void fragment() {
	vec3 c = colore.rgb;
	float grigio = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(0.5 + grigio * 0.15), spento * 0.92);
	ALBEDO = c;
	ROUGHNESS = 0.5;
	SPECULAR = 0.4;
	EMISSION = c * evidenzia * (0.35 + 0.25 * sin(TIME * 6.0));
}
