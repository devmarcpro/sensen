shader_type canvas_item;
// Textures procédurales du décor (designer 2026-09-01, points 50 et 58 — d'après Voxen).
// Aucun asset : la texture est CALCULÉE à partir de la position dans le plan de la face.
//   · les UV portent la position DANS LE PLAN (sol : coordonnées de tuile ; paroi : longueur × hauteur),
//     donc le grain suit le relief au lieu d'être plaqué à plat sur l'écran ;
//   · la couleur du matériau (venue des données) n'est jamais remplacée, seulement modulée ;
//   · un STYLE par famille de matériau (roche veinée, terre grumeleuse, bois fibré, métal brossé…),
//     encodé par le client dans la partie haute de UV.x — un canal de plus n'existe pas en 2D ;
//   · l'ORIENTATION de la face et la TUILE sont encodées dans les UV (le soleil et la lumière, designer 2026-09-06) :
//     le dessus et le sol : (style × pas_style + x, 4096 + y) en coordonnées de tuile locales à l'origine de dessin ;
//     la face sud-ouest : (style × pas_style + x, −1000 − (y × 32 + hauteur)) ; la face sud-est :
//     (style × pas_style + y, −2000 − (x × 32 + hauteur)). Sans UV (v près de 0), la matière est « plate » : ni soleil ni
//     lumière de tuile (les êtres reçoivent la leur par modulate, les voiles restent des voiles).

uniform float grains_par_tuile = 8.0;   // combien de « pixels » de grain sur le côté d'une tuile
uniform float force_grain = 0.10;       // amplitude du grain fin (0 = aplat)
uniform float force_douce = 0.07;       // amplitude de la variation basse fréquence
uniform float echelle_douce = 0.35;     // fréquence des taches douces, en tuiles
uniform float pas_style = 8192.0;       // le décalage qui encode le style dans UV.x (au-dessus de toute coordonnée locale)
uniform vec3 soleil = vec3(0.0, 0.0, 1.0);   // la direction du soleil, espace écran : x à droite, y en bas, z vers le ciel
uniform float soleil_force = 0.0;            // 0 : aucun ombrage directionnel (la nuit, ou le soleil désactivé)
uniform float ombre_min = 0.72;              // ce qu'une face qui tourne le dos au soleil garde de sa couleur
uniform float elevation_max = 65.0;          // en degrés : la hauteur du soleil à midi, où le sol vaut 1
uniform sampler2D lumiere_tex : filter_nearest, repeat_disable;   // la lumière de chaque tuile (niveau et teinte), RGB
uniform vec2 lumiere_taille = vec2(1.0, 1.0);   // la taille de la grille (la texture)
uniform vec2 lumiere_decalage = vec2(0.0, 0.0); // origine de la grille − origine de dessin, en tuiles
uniform float lumiere_active = 0.0;             // 0 : pas de lumière par tuile (arène)
uniform sampler2D matieres_tex : filter_nearest, repeat_disable;   // l'atlas des matières PEINTES : une case de tuile par ligne
uniform float matieres_n = 0.0;                 // combien de lignes dans l'atlas (0 : aucune matière peinte)
uniform float style_texture_base = 100.0;       // au-delà de ce style, UV.x ne désigne plus un motif calculé mais une LIGNE de l'atlas

const float DECALAGE_HAUT = 4096.0;
const float DECALAGE_SO = -1000.0;
const float DECALAGE_SE = -2000.0;
const float PAS_FACE = 32.0;   // les faces empilent la coordonnée de tuile × 32 et la hauteur (moins de 32 unités)

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
	float u = UV.x - style * pas_style;
	float v = UV.y;
	int face = 0;   // 0 plat (sans soleil ni lumière), 1 le dessus, 2 la face sud-ouest, 3 la face sud-est
	vec2 tuile = vec2(0.0);
	if (v > 2000.0) {
		face = 1;
		v -= DECALAGE_HAUT;
		tuile = floor(vec2(u, v));
	} else if (v < -1500.0) {
		face = 3;
		float vp = DECALAGE_SE - v;   // x × 32 + hauteur
		float tx = floor(vp / PAS_FACE);
		tuile = vec2(tx, floor(u));
		v = -(vp - tx * PAS_FACE);   // la hauteur, négative comme avant : le grain de la paroi
	} else if (v < -500.0) {
		face = 2;
		float vp = DECALAGE_SO - v;   // y × 32 + hauteur
		float ty = floor(vp / PAS_FACE);
		tuile = vec2(floor(u), ty);
		v = -(vp - ty * PAS_FACE);
	}
	vec2 uv = vec2(u, v);
	vec2 p = uv * max(grains_par_tuile, 1.0);
	float g = hache(p) - 0.5;                          // le grain commun à toutes les matières
	float t = doux(uv * max(echelle_douce, 0.01)) - 0.5;
	float k = 1.0 + g * 2.0 * force_grain + t * 2.0 * force_douce;

	// UNE MATIÈRE PEINTE (designer 2026-09-08) : son style désigne une ligne de l'atlas, et la texture REMPLACE la
	// couleur du matériau au lieu de la moduler — un sprite porte déjà ses couleurs. Le soleil et la lumière de la
	// tuile s'appliquent ensuite, comme pour une matière calculée ; le grain procédural, lui, ne s'y ajoute pas.
	if (matieres_n > 0.0 && style >= style_texture_base && style < style_texture_base + matieres_n) {
		vec2 f = fract(uv);
		COLOR.rgb = texture(matieres_tex, vec2(f.x, (style - style_texture_base + f.y) / matieres_n)).rgb;
		k = 1.0;
	} else if (style == 1.0) {   // ROCHE : des veines obliques et des éclats plus contrastés
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

	// Le soleil (designer 2026-09-06) : le dessus s'éclaire avec la hauteur du soleil (1 à midi), une paroi avec
	// l'angle entre sa normale et l'azimut du soleil — la face qui lui tourne le dos garde ombre_min de sa couleur.
	float k_soleil = 1.0;
	if (soleil_force > 0.0 && face > 0) {
		float d = 0.0;
		if (face == 1) {
			d = clamp(soleil.z / max(sin(radians(elevation_max)), 0.01), 0.0, 1.0);
		} else {
			vec2 n = (face == 2) ? normalize(vec2(-1.0, 1.0)) : normalize(vec2(1.0, 1.0));
			float lh = length(soleil.xy);
			d = lh > 0.001 ? clamp(dot(n, soleil.xy / lh), 0.0, 1.0) : 0.0;
		}
		k_soleil = mix(1.0, mix(ombre_min, 1.0, d), soleil_force);
	}
	// La lumière de la tuile (designer 2026-09-06 : « une échelle et une teinte ») : le ciel de l'heure, l'ombre portée,
	// les torches — une texture RGB par tuile de la grille, multipliée ici.
	vec3 lumiere = vec3(1.0);
	if (lumiere_active > 0.0 && face > 0) {
		vec2 g_tuile = tuile - lumiere_decalage;
		if (g_tuile.x >= 0.0 && g_tuile.y >= 0.0 && g_tuile.x < lumiere_taille.x && g_tuile.y < lumiere_taille.y) {
			lumiere = texture(lumiere_tex, (g_tuile + vec2(0.5)) / lumiere_taille).rgb;
		}
	}
	COLOR.rgb = clamp(COLOR.rgb * k * k_soleil * lumiere, vec3(0.0), vec3(1.0));
}
