shader_type canvas_item;
// Textures procédurales du décor (designer 2026-09-01, points 50 et 58 — d'après Voxen).
// Aucun asset : la texture est CALCULÉE à partir de la position dans le plan de la face.
//   · les UV portent la position DANS LE PLAN (sol : coordonnées de tuile ; paroi : longueur × hauteur),
//     donc le grain suit le relief au lieu d'être plaqué à plat sur l'écran ;
//   · la couleur du matériau (venue des données) n'est jamais remplacée, seulement modulée ;
//   · un STYLE par famille de matériau (roche veinée, terre grumeleuse, bois fibré, métal brossé…),
//     encodé par le client dans la partie haute de UV.x — un canal de plus n'existe pas en 2D.

uniform float grains_par_tuile = 8.0;   // combien de « pixels » de grain sur le côté d'une tuile
uniform float force_grain = 0.10;       // amplitude du grain fin (0 = aplat)
uniform float force_douce = 0.07;       // amplitude de la variation basse fréquence
uniform float echelle_douce = 0.35;     // fréquence des taches douces, en tuiles
uniform float pas_style = 512.0;        // le décalage qui encode le style dans UV.x

float hache(vec2 p) {   // bruit blanc déterministe : même case, même teinte, à jamais
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

float doux(vec2 p) {   // bruit de valeur interpolé : les taches larges
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hache(i);
	float b = hache(i + vec2(1.0, 0.0));
	float c = hache(i + vec2(0.0, 1.0));
	float d = hache(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float style = floor(UV.x / pas_style);
	vec2 uv = vec2(UV.x - style * pas_style, UV.y);
	vec2 p = uv * max(grains_par_tuile, 1.0);
	float g = hache(p) - 0.5;                          // le grain commun à toutes les matières
	float t = doux(uv * max(echelle_douce, 0.01)) - 0.5;
	float k = 1.0 + g * 2.0 * force_grain + t * 2.0 * force_douce;

	if (style == 1.0) {          // ROCHE : des veines obliques et des éclats plus contrastés
		float veine = doux(vec2(uv.x * 1.7 + uv.y * 0.9, uv.y * 0.4) * 3.0);
		k += (veine - 0.5) * 0.22 + g * 0.10;
	} else if (style == 2.0) {   // TERRE : grumeleuse — de larges mottes, peu de grain fin
		float motte = doux(uv * 2.2);
		k += (motte - 0.5) * 0.30 - g * 0.04;
	} else if (style == 3.0) {   // VÉGÉTAL : des touffes serrées, très haute fréquence
		float touffe = hache(p * 2.0) - 0.5;
		k += touffe * 0.18 + (doux(uv * 5.0) - 0.5) * 0.12;
	} else if (style == 4.0) {   // BOIS : des fibres qui courent dans le sens de la planche
		float fibre = doux(vec2(uv.x * 0.35, uv.y * 9.0));
		k += (fibre - 0.5) * 0.34;
	} else if (style == 5.0) {   // MÉTAL : brossé — des bandes fines, presque pas de bruit
		float bande = sin(uv.y * 46.0 + doux(uv * 1.5) * 2.0) * 0.5;
		k += bande * 0.12 - g * 0.05;
	} else if (style == 6.0) {   // GEMME / CRISTAL : des facettes nettes qui cassent la lumière
		vec2 f = floor(uv * 6.0);
		k += (hache(f) - 0.5) * 0.45;
	} else if (style == 7.0) {   // LIQUIDE : des ondulations larges, sans grain
		float onde = sin((uv.x + uv.y) * 7.0 + doux(uv * 2.0) * 3.0);
		k = 1.0 + onde * 0.06 + (doux(uv * 1.2) - 0.5) * 0.08;
	} else if (style == 8.0) {   // SABLE : un grain très fin et régulier
		k = 1.0 + (hache(p * 2.5) - 0.5) * 0.14 + t * 0.06;
	}
	COLOR.rgb = clamp(COLOR.rgb * k, vec3(0.0), vec3(1.0));
}
