#include "sensen_grille.h"

#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/rect2i.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {

const int INF = 1 << 30;
// Les huit directions, dans l'ordre de Grille.DIRS (l'ordre d'exploration décide du chemin retenu à coût égal).
const int DX[8] = { 1, -1, 0, 0, 1, 1, -1, -1 };
const int DY[8] = { 0, 0, 1, -1, 1, -1, 1, -1 };

inline int roundi_(double x) { return (int)std::round(x); }
inline int distance_(Vector2i a, Vector2i b) { return std::max(std::abs(a.x - b.x), std::abs(a.y - b.y)); }

struct Noeud {
	int x, y, z;
};

// Le tas binaire minimal sur z de Grille._tas_push / _tas_pop, transcrit tel quel : le même ordre de sortie.
void tas_push(std::vector<Noeud> &tas, Noeud v) {
	tas.push_back(v);
	size_t i = tas.size() - 1;
	while (i > 0) {
		size_t parent = (i - 1) / 2;
		if (tas[parent].z <= tas[i].z) {
			break;
		}
		std::swap(tas[parent], tas[i]);
		i = parent;
	}
}

Noeud tas_pop(std::vector<Noeud> &tas) {
	Noeud racine = tas[0];
	Noeud dernier = tas.back();
	tas.pop_back();
	if (tas.empty()) {
		return racine;
	}
	tas[0] = dernier;
	size_t i = 0;
	size_t n = tas.size();
	while (true) {
		size_t gauche = 2 * i + 1;
		size_t droite = gauche + 1;
		size_t plus_petit = i;
		if (gauche < n && tas[gauche].z < tas[plus_petit].z) {
			plus_petit = gauche;
		}
		if (droite < n && tas[droite].z < tas[plus_petit].z) {
			plus_petit = droite;
		}
		if (plus_petit == i) {
			break;
		}
		std::swap(tas[i], tas[plus_petit]);
		i = plus_petit;
	}
	return racine;
}

inline const uint8_t *octets_ou_nul(const PackedByteArray &tab, int n) {
	return tab.size() >= n ? tab.ptr() : nullptr;
}

inline const double *reels_ou_nul(const PackedFloat64Array &tab, int n) {
	return tab.size() >= n ? tab.ptr() : nullptr;
}

} // namespace

void SensenGrille::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurer", "dep", "oeil", "table"), &SensenGrille::configurer);
	ClassDB::bind_method(D_METHOD("chemin", "grille", "depart", "arrivee", "volant", "ignorer", "eviter_nage", "max_noeuds"), &SensenGrille::chemin);
	ClassDB::bind_method(D_METHOD("atteignables", "grille", "depart", "budget", "volant", "eviter_nage"), &SensenGrille::atteignables);
	ClassDB::bind_method(D_METHOD("ligne_de_vue", "grille", "a", "b"), &SensenGrille::ligne_de_vue);
	ClassDB::bind_method(D_METHOD("premier_obstacle_vue", "grille", "a", "b"), &SensenGrille::premier_obstacle_vue);
	ClassDB::bind_method(D_METHOD("champ_de_vue", "grille", "pos", "portee"), &SensenGrille::champ_de_vue);
	ClassDB::bind_method(D_METHOD("cout_pas_entre", "grille", "de", "vers", "volant", "eviter_nage"), &SensenGrille::cout_pas_entre);
	ClassDB::bind_method(D_METHOD("composante", "grille", "depart", "max_tuiles"), &SensenGrille::composante);
	ClassDB::bind_method(D_METHOD("regions_cellule", "grille", "origine", "n", "classes"), &SensenGrille::regions_cellule);
	ClassDB::bind_method(D_METHOD("morceau", "grille", "coin", "taille_morceau", "p"), &SensenGrille::morceau);
	ClassDB::bind_method(D_METHOD("visibles", "grille", "vue", "tout_vu", "zj", "vide_ci", "jp", "rayon", "bat_j", "positions"), &SensenGrille::visibles);
	ClassDB::bind_method(D_METHOD("brouillard", "grille", "vue", "tout_vu", "zj", "vide_ci", "jp", "rayon", "origine_dessin", "tw", "th", "hstep", "niveau_u", "bat_j", "mur_coupe_u", "voile", "col_sil"), &SensenGrille::brouillard);
	ClassDB::bind_method(D_METHOD("toits", "grille", "vue", "tout_vu", "zj", "vide_ci", "jp", "rayon", "origine_dessin", "tw", "th", "hstep", "niveau_u", "bat_j", "bat_couleurs", "bat_styles", "pente_t", "haut_toit", "ombre_min", "soleil_h", "soleil_ok", "soleil_force", "uv_haut"), &SensenGrille::toits);
	ClassDB::bind_method(D_METHOD("ombres", "grille", "dir", "pente", "coin", "taille", "max_pas", "unites_par_niveau"), &SensenGrille::ombres);
	ClassDB::bind_method(D_METHOD("propager_lumiere", "grille", "sources_idx", "sources_niv", "ambiante", "bloque_par_contenu"), &SensenGrille::propager_lumiere);
	ClassDB::bind_method(D_METHOD("carte_lumiere", "grille", "ciel", "locale", "teinte_locale", "force_locale", "dir", "pente", "max_pas", "unites_par_niveau", "ombre_portee", "coin", "taille"), &SensenGrille::carte_lumiere);
	ClassDB::bind_method(D_METHOD("sol_cellule", "taille", "bord", "pas", "bloc_sol", "bloc_mer", "mer_h", "hauteurs"), &SensenGrille::sol_cellule);
	ClassDB::bind_method(D_METHOD("vegetation_cellule", "rng", "taille", "pas", "sol_keys", "eau", "reserve", "bloc_biome", "bloc_veg", "bloc_res", "bloc_danger", "biomes", "seuils", "filons_seuil", "filons_densite", "tiers"), &SensenGrille::vegetation_cellule);
}

// La génération d'une cellule de surface, première passe (Surface.generer_cellule, étape 1 — transcription de
// Surface._sol_gd, file 109) : chaque tuile hors bord est du sol, prend le matériau de sol de son bloc de `pas` tuiles,
// et la mer (le bloc sous le niveau de la mer) la couvre à mer_h. Rend {sol, bord, sols, eau, hauteurs}, dans l'ordre
// des tuiles — les dictionnaires ont le même ordre d'insertion que le GDScript.
Dictionary SensenGrille::sol_cellule(int taille, bool bord, int pas, const PackedStringArray &bloc_sol, const PackedByteArray &bloc_mer, int mer_h, const PackedByteArray &hauteurs) {
	Dictionary sol, bordd, sols, eau;
	PackedByteArray h = hauteurs;
	int nb = (pas > 0) ? (taille + pas - 1) / pas : 1;
	if (pas <= 0) {
		pas = 1;
	}
	for (int y = 0; y < taille; ++y) {
		for (int x = 0; x < taille; ++x) {
			int i = y * taille + x;
			if (bord && (x == 0 || y == 0 || x == taille - 1 || y == taille - 1)) {
				bordd[i] = true;
				continue;
			}
			sol[i] = true;
			int bk = (y / pas) * nb + (x / pas);
			if (bk < bloc_sol.size()) {
				sols[i] = bloc_sol[bk];
			}
			if (bk < bloc_mer.size() && bloc_mer[bk]) {
				eau[i] = true;
				if (i < h.size()) {
					h.set(i, (uint8_t)mer_h);
				}
			}
		}
	}
	Dictionary res;
	res["sol"] = sol;
	res["bord"] = bordd;
	res["sols"] = sols;
	res["eau"] = eau;
	res["hauteurs"] = h;
	return res;
}

namespace {
struct EntreeBiome {
	String id;
	double density;
};
struct BiomeCompile {
	std::vector<EntreeBiome> vegetation, plantes, cueillette, rochers;
	double filons_mult = 1.0;
	bool montagne = false;
};
void lire_entrees(const Array &liste, std::vector<EntreeBiome> &out) {
	for (int i = 0; i < liste.size(); ++i) {
		Array paire = liste[i];
		if (paire.size() >= 2) {
			out.push_back({ paire[0], (double)paire[1] });
		}
	}
}
} // namespace

// La troisième passe (Surface._vegetation_gd) : pour chaque tuile de sol (dans l'ordre des clés de e.sol, hors réserve
// et hors eau), UN tirage du RNG de la cellule décide, aux seuils cumulés, d'un arbre, d'une plante, d'une cueillette,
// d'un rocher ou d'un filon (un second tirage choisit le minerai dans les paliers jusqu'au tier du danger). Le RNG est
// celui du GDScript (RandomNumberGenerator), consommé dans le même ordre : la cellule est la même au bit près.
Dictionary SensenGrille::vegetation_cellule(Object *rng_o, int taille, int pas, const PackedInt32Array &sol_keys, const Dictionary &eau, Rect2i reserve,
		const PackedInt32Array &bloc_biome, const PackedFloat64Array &bloc_veg, const PackedFloat64Array &bloc_res, const PackedFloat64Array &bloc_danger,
		const Array &biomes, const PackedFloat64Array &seuils, double filons_seuil, double filons_densite, const Array &tiers) {
	Dictionary arbres, plantes, cueillette, rochers, filons, res;
	RandomNumberGenerator *rng = Object::cast_to<RandomNumberGenerator>(rng_o);
	if (rng == nullptr || pas <= 0) {
		return res;
	}
	std::vector<BiomeCompile> table;
	for (int b = 0; b < biomes.size(); ++b) {
		Dictionary d = biomes[b];
		BiomeCompile bc;
		lire_entrees(d.get("vegetation", Array()), bc.vegetation);
		lire_entrees(d.get("plantes", Array()), bc.plantes);
		lire_entrees(d.get("cueillette", Array()), bc.cueillette);
		lire_entrees(d.get("rochers", Array()), bc.rochers);
		bc.filons_mult = (double)d.get("filons_mult", 1.0);
		bc.montagne = (bool)d.get("montagne", false);
		table.push_back(bc);
	}
	std::vector<PackedStringArray> paliers;
	for (int t = 0; t < tiers.size(); ++t) {
		paliers.push_back(tiers[t]);
	}
	int nb = (taille + pas - 1) / pas;
	const int32_t *cles = sol_keys.ptr();
	for (int n = 0; n < sol_keys.size(); ++n) {
		int i = cles[n];
		int x = i % taille, y = i / taille;
		if (reserve.has_point(Vector2i(x, y)) || eau.has(i)) {
			continue;
		}
		int bk = (y / pas) * nb + (x / pas);
		if (bk >= bloc_biome.size() || bloc_biome[bk] < 0 || bloc_biome[bk] >= (int)table.size()) {
			continue;
		}
		const BiomeCompile &b = table[bloc_biome[bk]];
		double veg = bloc_veg[bk];
		double ress = bloc_res[bk];
		double tire = rng->randf();
		bool pose = false;
		double seuil = 0.0;
		for (const EntreeBiome &v : b.vegetation) {
			seuil += v.density * veg * 2.0;
			if (tire < seuil) {
				arbres[i] = v.id;
				pose = true;
				break;
			}
		}
		if (pose) {
			continue;
		}
		for (const EntreeBiome &pl : b.plantes) {
			seuil += pl.density * veg * 2.0;
			if (tire < seuil) {
				plantes[i] = pl.id;
				pose = true;
				break;
			}
		}
		if (pose) {
			continue;
		}
		for (const EntreeBiome &cu : b.cueillette) {
			seuil += cu.density * veg * 2.0;
			if (tire < seuil) {
				cueillette[i] = cu.id;
				pose = true;
				break;
			}
		}
		if (pose) {
			continue;
		}
		for (const EntreeBiome &r : b.rochers) {
			if (tire < r.density * (1.0 - ress)) {
				rochers[i] = r.id;
				pose = true;
				break;
			}
		}
		if (pose) {
			continue;
		}
		if (ress > filons_seuil && tire < filons_densite * b.filons_mult) {
			double danger = bloc_danger[bk] * 100.0;
			int tier = 1;
			for (int k = 1; k < seuils.size(); ++k) {
				if (danger >= seuils[k] || (k == 1 && b.montagne)) {
					tier = k + 1;
				}
			}
			PackedStringArray pool;
			for (int t = 1; t <= tier; ++t) {
				if (t - 1 < (int)paliers.size()) {
					pool.append_array(paliers[t - 1]);
				}
			}
			if (pool.size() > 0) {
				filons[i] = pool[rng->randi_range(0, pool.size() - 1)];
			}
		}
	}
	res["arbres"] = arbres;
	res["plantes"] = plantes;
	res["cueillette"] = cueillette;
	res["rochers"] = rochers;
	res["filons"] = filons;
	return res;
}

// La carte d'ombre d'une fenêtre de tuiles (Éclairage, le soleil, 2026-09-06) — transcription de Grille._ombres_gd :
// depuis chaque tuile, marcher vers le soleil (`dir`, direction dans la grille, unitaire) ; au k-ième pas, ce qui se
// dresse là (le sol, plus le bloc : hauteur_vue d'un contenu qui bloque la vue, ou les niveaux du bâtiment ×
// unites_par_niveau) fait de l'ombre s'il dépasse le sol de la tuile de plus de `pente` × k unités. Résultat : un octet
// par tuile du rectangle coin/taille, ligne par ligne, 1 = à l'ombre.
void SensenGrille::ombres_e(const Etat &s, const uint8_t *nv, Vector2 dir, double pente, Vector2i coin, Vector2i taille, int max_pas, int unites_par_niveau, uint8_t *out) const {
	for (int ly = 0; ly < taille.y; ++ly) {
		for (int lx = 0; lx < taille.x; ++lx) {
			int tx = coin.x + lx, ty = coin.y + ly;
			uint8_t ombre = 0;
			if (s.dans(tx, ty)) {
				int h0 = (int)s.h[s.idx(tx, ty)];
				for (int k = 1; k <= max_pas; ++k) {
					int qx = tx + roundi_((double)dir.x * k);
					int qy = ty + roundi_((double)dir.y * k);
					if (!s.dans(qx, qy)) {
						break;
					}
					int qi = s.idx(qx, qy);
					int fl = drapeaux(s, qi);
					int hv = (fl & F_BLOQUE_VUE) ? ((fl >> 8) & 0xFF) : 0;
					int n = nv ? (int)nv[qi] : 0;
					if (n > 0) {
						hv = std::max(hv, n * unites_par_niveau);
					}
					if ((double)((int)s.h[qi] + hv - h0) > pente * k) {
						ombre = 1;
						break;
					}
				}
			}
			out[ly * taille.x + lx] = ombre;
		}
	}
}

PackedByteArray SensenGrille::ombres(Object *grille, Vector2 dir, double pente, Vector2i coin, Vector2i taille, int max_pas, int unites_par_niveau) {
	PackedByteArray res;
	Etat s;
	if (taille.x <= 0 || taille.y <= 0 || !charger(grille, s)) {
		return res;
	}
	static const StringName sn_niv("niveaux_bat");
	PackedByteArray niv = grille->get(sn_niv);
	const uint8_t *nv = octets_ou_nul(niv, s.L * s.H);
	res.resize(taille.x * taille.y);
	ombres_e(s, nv, dir, pente, coin, taille, max_pas, unites_par_niveau, res.ptrw());
	return res;
}


// La propagation 0-15 de la lumière (Simulation._recalculer_lumiere_gd, Éclairage) : la carte part à `ambiante`, chaque
// source y pose son niveau, puis la lumière descend d'un niveau par tuile vers les huit voisines — une tuile dont le
// contenu bloque la lumière (bloque_par_contenu[contenu]) n'en laisse rien passer, sauf si sa matière est transparente
// (Grille.transparent_a) ou qu'un meuble y est posé. La carte finale est le maximum, sur toutes les sources, de
// niveau − distance : elle ne dépend pas de l'ordre — on propage donc par SEAUX de niveau décroissant, chaque tuile
// traitée une fois, là où la file du GDScript la relaxait plusieurs fois. Le même résultat, test_noyau_cpp le vérifie.
PackedByteArray SensenGrille::propager_lumiere(Object *grille, const PackedInt32Array &sources_idx, const PackedByteArray &sources_niv, int ambiante,
		const PackedByteArray &bloque_par_contenu) {
	PackedByteArray res;
	Etat s;
	if (!charger(grille, s)) {
		return res;
	}
	int n = s.n;
	res.resize(n);
	uint8_t *carte = res.ptrw();
	for (int i = 0; i < n; ++i) {
		carte[i] = (uint8_t)ambiante;
	}
	static const StringName sn_transp("transparent_a"), sn_meubles("meubles");
	PackedByteArray transp = grille->get(sn_transp);
	const uint8_t *tr = octets_ou_nul(transp, n);
	std::vector<uint8_t> passe(n, 0);   // 1 : la tuile laisse passer quoi qu'en dise son contenu (verre, meuble)
	if (tr) {
		for (int i = 0; i < n; ++i) {
			passe[i] = tr[i];
		}
	}
	Dictionary meubles = grille->get(sn_meubles);
	Array cles_m = meubles.keys();
	for (int k = 0; k < cles_m.size(); ++k) {
		int i = (int)cles_m[k];
		if (i >= 0 && i < n) {
			passe[i] = 1;
		}
	}
	std::vector<std::vector<int>> seaux(16);
	for (int k = 0; k < sources_idx.size() && k < sources_niv.size(); ++k) {
		int gi = sources_idx[k];
		int niv = sources_niv[k];
		if (gi >= 0 && gi < n && niv > carte[gi] && niv <= 15) {
			carte[gi] = (uint8_t)niv;
			seaux[niv].push_back(gi);
		}
	}
	int nbc = bloque_par_contenu.size();
	for (int niv = 15; niv >= 2; --niv) {
		std::vector<int> &seau = seaux[niv];
		for (size_t k = 0; k < seau.size(); ++k) {
			int gi = seau[k];
			if ((int)carte[gi] != niv) {
				continue;   // relevée depuis par une source plus forte : déjà propagée à son niveau
			}
			int32_t ci = s.c[gi];
			bool bloque = (ci > 0 && ci < nbc) ? bloque_par_contenu[ci] != 0 : false;
			if (bloque && !passe[gi]) {
				continue;   // un mur est éclairé mais ne laisse rien passer — sauf s'il est de verre ou porte un meuble
			}
			int px = s.px(gi), py = s.py(gi);
			for (int d = 0; d < 8; ++d) {
				int qx = px + DX[d], qy = py + DY[d];
				if (!s.dans(qx, qy)) {
					continue;
				}
				int qi = s.idx(qx, qy);
				if (niv - 1 > (int)carte[qi]) {
					carte[qi] = (uint8_t)(niv - 1);
					seaux[niv - 1].push_back(qi);
				}
			}
		}
	}
	return res;
}

// La lumière de chaque tuile (Éclairage, designer 2026-09-06 : « une tuile n'est pas juste éclairée ou pas, c'est une
// échelle et une teinte ») — transcription de Grille._carte_lumiere_gd : le ciel (niveau et teinte de l'heure), assombri
// de ombre_portee sur les tuiles à l'ombre du rectangle coin/taille (au-delà, pas d'ombre), plus la lumière locale
// (`locale` : 0-15 par tuile, torches et meubles propagés par la simulation) × force à sa teinte, le tout borné à 1.
// Trois octets par tuile (RGB), pour la texture que le shader multiplie.
PackedByteArray SensenGrille::carte_lumiere(Object *grille, Color ciel, const PackedByteArray &locale, Color teinte_locale, double force_locale,
		Vector2 dir, double pente, int max_pas, int unites_par_niveau, double ombre_portee, Vector2i coin, Vector2i taille) {
	PackedByteArray res;
	Etat s;
	if (!charger(grille, s)) {
		return res;
	}
	int n = s.L * s.H;
	std::vector<uint8_t> ombre;
	bool avec_ombre = ombre_portee > 0.0 && max_pas > 0 && taille.x > 0 && taille.y > 0;
	if (avec_ombre) {
		static const StringName sn_niv("niveaux_bat");
		PackedByteArray niv = grille->get(sn_niv);
		const uint8_t *nv = octets_ou_nul(niv, n);
		ombre.assign(taille.x * taille.y, 0);
		ombres_e(s, nv, dir, pente, coin, taille, max_pas, unites_par_niveau, ombre.data());
	}
	const uint8_t *loc = octets_ou_nul(locale, n);
	res.resize(n * 3);
	uint8_t *out = res.ptrw();
	for (int i = 0; i < n; ++i) {
		int x = s.ox + i % s.L, y = s.oy + i / s.L;
		double r = ciel.r, g = ciel.g, b = ciel.b;
		if (avec_ombre) {
			int lx = x - coin.x, ly = y - coin.y;
			if (lx >= 0 && ly >= 0 && lx < taille.x && ly < taille.y && ombre[ly * taille.x + lx]) {
				r *= (1.0 - ombre_portee);
				g *= (1.0 - ombre_portee);
				b *= (1.0 - ombre_portee);
			}
		}
		double l = loc ? (double)loc[i] / 15.0 * force_locale : 0.0;
		r = std::min(1.0, r + teinte_locale.r * l);
		g = std::min(1.0, g + teinte_locale.g * l);
		b = std::min(1.0, b + teinte_locale.b * l);
		out[i * 3] = (uint8_t)roundi_(r * 255.0);
		out[i * 3 + 1] = (uint8_t)roundi_(g * 255.0);
		out[i * 3 + 2] = (uint8_t)roundi_(b * 255.0);
	}
	return res;
}

// Les règles de déplacement, lues comme Grille.cout_pas les lit (les nombres du JSON sont des flottants).
void SensenGrille::configurer(const Dictionary &dep, int p_oeil, const PackedInt32Array &p_table) {
	cout_base = (int)dep.get("cout_base", 10);
	montee_1 = (int)dep.get("montee_1", cout_base);
	montee_2 = (int)dep.get("montee_2", cout_base);
	descente = (int)dep.get("descente", cout_base);
	falaise_delta = (int)dep.get("falaise_delta", 3);
	chute_delta = (int)dep.get("chute_delta", 3);
	neige_surcout = (int)dep.get("neige_surcout", 1);
	Dictionary np = dep.get("nage_progressive", Dictionary());
	Variant tpt = np.get("ticks_par_tuile", Variant());
	if (tpt.get_type() == Variant::NIL) {
		nage_ticks = (double)(int)dep.get("nage", cout_base * 2);
	} else {
		nage_ticks = (double)tpt;
	}
	Dictionary esc = dep.get("escalade", Dictionary());
	escalade_ticks_par_niveau = (double)esc.get("ticks_par_niveau", 14);
	oeil = p_oeil;
	table.assign(p_table.ptr(), p_table.ptr() + p_table.size());
}

// Lit les tableaux de la Grille GDScript. Un miroir absent ou trop court vaut zéro partout (une grille virtuelle).
bool SensenGrille::charger(Object *grille, Etat &s) const {
	static const StringName sn_largeur("largeur"), sn_hauteur("hauteur_grille"), sn_origine("origine"), sn_hauteurs("hauteurs"),
			sn_contenu("contenu"), sn_occ("occ"), sn_dangers("danger_a"), sn_eau("eau_a"), sn_frott("frott_a"), sn_neige("neige"),
			sn_gel("gel"), sn_occupants("occupants"), sn_couches("couches"), sn_lien("lien_a");
	if (grille == nullptr) {
		return false;
	}
	s.L = (int)grille->get(sn_largeur);
	s.H = (int)grille->get(sn_hauteur);
	Vector2i o = grille->get(sn_origine);
	s.ox = o.x;
	s.oy = o.y;
	s.n0 = s.L * s.H;
	if (s.n0 <= 0) {
		return false;
	}
	Variant vc = grille->get(sn_couches);
	s.couches = (vc.get_type() == Variant::INT) ? std::max(1, (int)vc) : 1;
	s.n = s.n0 * s.couches;
	int n = s.n;
	s.hauteurs = grille->get(sn_hauteurs);
	s.contenu = grille->get(sn_contenu);
	if (s.hauteurs.size() < n || s.contenu.size() < n) {
		return false;
	}
	s.h = s.hauteurs.ptr();
	s.c = s.contenu.ptr();
	s.occ = grille->get(sn_occ);
	s.dangers = grille->get(sn_dangers);
	s.eau = grille->get(sn_eau);
	s.frottement = grille->get(sn_frott);
	s.o = octets_ou_nul(s.occ, n);
	s.d = octets_ou_nul(s.dangers, n);
	s.e = octets_ou_nul(s.eau, n);
	s.f = reels_ou_nul(s.frottement, n);
	s.neige = (bool)grille->get(sn_neige);
	s.gel = (bool)grille->get(sn_gel);
	s.occupants = grille->get(sn_occupants);
	s.lien = grille->get(sn_lien);
	s.li = (s.lien.size() >= n) ? s.lien.ptr() : nullptr;
	return true;
}

// Grille.niveau_liquide : 8 pour une source, le niveau mémorisé (1 par défaut sur un écoulement), 0 sinon.
// eau_a mémorise niveau + 1 (0 = aucune entrée dans niveau_eau).
int SensenGrille::niveau_liquide(const Etat &s, int i) const {
	int fl = drapeaux(s, i);
	if ((fl & F_SOURCE) && (fl & F_LIQUIDE)) {
		return 8;
	}
	int memo = s.e ? (int)s.e[i] : 0;
	if (fl & F_ECOULEMENT) {
		return memo > 0 ? memo - 1 : 1;
	}
	return memo > 0 ? memo - 1 : 0;
}

bool SensenGrille::nageable(const Etat &s, int i) const {
	if (s.gel) {
		return false;
	}
	return (drapeaux(s, i) & F_NAGE) != 0 || niveau_liquide(s, i) > 0;
}

// Grille.cout_pas sans facteurs (le chemin et les atteignables n'en passent jamais) : -1 = infranchissable.
int SensenGrille::cout_pas(const Etat &s, int de_i, int vx, int vy, bool volant, bool eviter_nage) const {
	if (!s.dans(vx, vy)) {
		return -1;
	}
	int vi = s.idx(vx, vy);
	int fl = drapeaux(s, vi);
	if (fl & F_BLOQUE_PASSAGE) {
		if (fl & F_FERMEE) {
			return cout_base * 2;
		}
		return -1;
	}
	int base = cout_base;
	if (volant) {
		return base;
	}
	bool nage_vers = nageable(s, vi);
	if (eviter_nage && nage_vers && !nageable(s, de_i)) {
		return -1;
	}
	if (nage_vers) {
		return std::max(1, roundi_(nage_ticks / 1.0)) + (s.neige ? neige_surcout : 0);
	}
	int dh = (int)s.h[vi] - (int)s.h[de_i];
	if (dh >= falaise_delta) {
		double t_esc = escalade_ticks_par_niveau * (double)(dh * dh);
		return std::max(1, roundi_(t_esc / 1.0));
	}
	if (dh <= -chute_delta) {
		return -1;
	}
	int sur = s.neige ? neige_surcout : 0;
	int brut = base + sur;
	if (dh == 2) {
		brut = montee_2 + sur;
	} else if (dh == 1) {
		brut = montee_1 + sur;
	} else if (dh < 0) {
		brut = descente + sur;
	}
	double mult = s.f ? s.f[vi] : 1.0;
	return std::max(1, roundi_((double)brut / mult));
}

int SensenGrille::cout_pas_entre(Object *grille, Vector2i de, Vector2i vers, bool volant, bool eviter_nage) {
	Etat s;
	if (!charger(grille, s) || !s.dans(de.x, de.y)) {
		return -1;
	}
	return cout_pas(s, s.idx(de.x, de.y), vers.x, vers.y, volant, eviter_nage);
}

// Grille.chemin : A* 8 directions, le même tas, le même ordre de voisins, la même heuristique — le même chemin.
Array SensenGrille::chemin(Object *grille, Vector2i depart, Vector2i arrivee, bool volant, const String &ignorer, bool eviter_nage, int max_noeuds) {
	Array vide;
	vide.set_typed(Variant::VECTOR2I, StringName(), Variant());
	Etat s;
	if (depart == arrivee || !charger(grille, s) || !s.dans(arrivee.x, arrivee.y) || !s.dans(depart.x, depart.y)) {
		return vide;
	}
	int n = s.n;
	g_cout.assign(n, INF);
	vient_de.assign(n, -1);
	std::vector<Noeud> ouverts;
	ouverts.reserve(256);
	ouverts.push_back({ depart.x, depart.y, 0 });
	int i_dep = s.idx(depart.x, depart.y);
	g_cout[i_dep] = 0;
	int base = cout_base;
	int explores = 0;
	bool ignorer_vide = ignorer.is_empty();
	while (!ouverts.empty()) {
		explores += 1;
		if (max_noeuds > 0 && explores > max_noeuds) {
			return vide;
		}
		Noeud c3 = tas_pop(ouverts);
		int cx = c3.x, cy = c3.y;
		int ci = s.idx(cx, cy);
		if (cx == arrivee.x && cy == arrivee.y) {
			std::vector<int> pas;
			int c = ci;
			while (c != i_dep) {
				pas.push_back(c);
				c = vient_de[c];
			}
			Array res;
			res.set_typed(Variant::VECTOR2I, StringName(), Variant());
			for (size_t k = pas.size(); k > 0; --k) {
				int t = pas[k - 1];
				res.push_back(Vector2i(s.px(t), s.py(t)));
			}
			return res;
		}
		int gc = g_cout[ci];
		// Les huit pas, et — depuis l'escalier où l'on se tient (le départ) — son autre bout, au coût de base.
		bool depuis_escalier = (ci == i_dep && s.li && s.li[ci] >= 0);
		for (int k = 0; k < (depuis_escalier ? 9 : 8); ++k) {
			int vi, cout;
			if (k == 8) {
				vi = s.li[ci];
				cout = cout_base;
			} else {
				int vx = cx + DX[k], vy = cy + DY[k];
				cout = cout_pas(s, ci, vx, vy, volant, eviter_nage);
				if (cout < 0) {
					continue;
				}
				vi = s.idx(vx, vy);
				if (s.li && s.li[vi] >= 0) {
					vi = s.li[vi];   // un escalier ne se tient pas : y poser le pied, c'est arriver à l'autre bout
				}
			}
			int vx = s.px(vi), vy = s.py(vi);
			bool est_arrivee = (vx == arrivee.x && vy == arrivee.y);
			if (s.o && s.o[vi] && !est_arrivee) {
				// Occupée : on passe seulement si l'occupant est celui qu'on ignore.
				if (ignorer_vide) {
					continue;
				}
				String occ = s.occupants.get(vi, String());
				if (occ != ignorer) {
					continue;
				}
			}
			if (s.d && s.d[vi] && !est_arrivee) {
				continue;
			}
			int ng = gc + cout;
			if (ng < g_cout[vi]) {
				g_cout[vi] = ng;
				vient_de[vi] = ci;
				tas_push(ouverts, { vx, vy, ng + base * distance_(Vector2i(vx, vy - Etat::z_de(vy) * BANDE_Z), Vector2i(arrivee.x, arrivee.y - Etat::z_de(arrivee.y) * BANDE_Z)) });
			}
		}
	}
	return vide;
}

// Grille.atteignables : Dijkstra borné, le dictionnaire dans l'ordre d'insertion de l'original.
Dictionary SensenGrille::atteignables(Object *grille, Vector2i depart, int budget, bool volant, bool eviter_nage) {
	Dictionary res;
	Etat s;
	if (!charger(grille, s) || !s.dans(depart.x, depart.y)) {
		res[depart] = 0;
		return res;
	}
	int n = s.n;
	g_cout.assign(n, INF);
	std::vector<int> ordre;
	std::vector<int> file;
	int i_dep = s.idx(depart.x, depart.y);
	g_cout[i_dep] = 0;
	ordre.push_back(i_dep);
	file.push_back(i_dep);
	while (!file.empty()) {
		size_t k = 0;
		for (size_t i = 0; i < file.size(); ++i) {
			if (g_cout[file[i]] < g_cout[file[k]]) {
				k = i;
			}
		}
		int c = file[k];
		file.erase(file.begin() + k);
		int cx = s.px(c), cy = s.py(c);
		bool depuis_escalier = (c == i_dep && s.li && s.li[c] >= 0);
		for (int d = 0; d < (depuis_escalier ? 9 : 8); ++d) {
			int vi, cout;
			if (d == 8) {
				vi = s.li[c];
				cout = cout_base;
			} else {
				int vx = cx + DX[d], vy = cy + DY[d];
				cout = cout_pas(s, c, vx, vy, volant, eviter_nage);
				if (cout < 0) {
					continue;
				}
				vi = s.idx(vx, vy);
				if (s.li && s.li[vi] >= 0) {
					vi = s.li[vi];   // l'escalier mène à l'autre bout
				}
			}
			if (s.o && s.o[vi]) {
				continue;
			}
			int nc = g_cout[c] + cout;
			if (nc <= budget && nc < g_cout[vi]) {
				if (g_cout[vi] == INF) {
					ordre.push_back(vi);
				}
				g_cout[vi] = nc;
				file.push_back(vi);
			}
		}
	}
	for (int t : ordre) {
		res[Vector2i(s.px(t), s.py(t))] = g_cout[t];
	}
	return res;
}

// Grille.ligne_de_vue / premier_obstacle_vue : la même ligne interpolée, les mêmes arrondis.
bool SensenGrille::ligne_de_vue_e(const Etat &s, Vector2i a, Vector2i b, Vector2i *obstacle) const {
	if (Etat::z_de(a.y) != Etat::z_de(b.y)) {
		return false;   // une autre couche : hors de vue (l'escalier ne se voit pas au travers)
	}
	double ha = (double)((int)s.h[s.idx(a.x, a.y)] + oeil);
	double hb = (double)((int)s.h[s.idx(b.x, b.y)] + oeil);
	int n = std::max(std::abs(b.x - a.x), std::abs(b.y - a.y));
	for (int i = 1; i < n; ++i) {
		double t = (double)i / (double)n;
		int px = roundi_((double)a.x + ((double)b.x - (double)a.x) * t);
		int py = roundi_((double)a.y + ((double)b.y - (double)a.y) * t);
		double hv = (double)hauteur_vue(s, s.idx(px, py));
		if (hv > ha + (hb - ha) * t) {
			if (obstacle) {
				*obstacle = Vector2i(px, py);
			}
			return false;
		}
	}
	return true;
}

bool SensenGrille::ligne_de_vue(Object *grille, Vector2i a, Vector2i b) {
	if (a == b) {
		return true;
	}
	Etat s;
	if (!charger(grille, s) || !s.dans(a.x, a.y) || !s.dans(b.x, b.y)) {
		return false;
	}
	return ligne_de_vue_e(s, a, b, nullptr);
}

Vector2i SensenGrille::premier_obstacle_vue(Object *grille, Vector2i a, Vector2i b) {
	Vector2i aucun(-1, -1);
	if (a == b) {
		return aucun;
	}
	Etat s;
	if (!charger(grille, s) || !s.dans(a.x, a.y) || !s.dans(b.x, b.y)) {
		return aucun;
	}
	Vector2i obstacle = aucun;
	ligne_de_vue_e(s, a, b, &obstacle);
	return obstacle;
}

// Le champ de vue de Simulation.maj_vision : les index des tuiles vues depuis pos à portée (Tchebychev),
// dans l'ordre du balayage original (dy puis dx).
PackedInt32Array SensenGrille::champ_de_vue(Object *grille, Vector2i pos, int portee) {
	PackedInt32Array res;
	Etat s;
	if (!charger(grille, s) || !s.dans(pos.x, pos.y)) {
		return res;
	}
	for (int dy = -portee; dy <= portee; ++dy) {
		for (int dx = -portee; dx <= portee; ++dx) {
			int tx = pos.x + dx, ty = pos.y + dy;
			if (!s.dans(tx, ty)) {
				continue;
			}
			if ((dx == 0 && dy == 0) || ligne_de_vue_e(s, pos, Vector2i(tx, ty), nullptr)) {
				res.push_back(s.idx(tx, ty));
			}
		}
	}
	return res;
}

// Les régions closes d'une cellule (SimTerritoire.pieces_de_cellule, « Détection de pièces », l'extérieur d'abord),
// transcrites telles quelles : `classes` donne la classe de chaque index de contenu (0 franchissable, 1 mur, 2 porte,
// 3 bloquant — un mur, sauf si un meuble y est posé) ; l'extérieur est inondé depuis le bord de la cellule (4 directions,
// une pile, le même ordre de graines et de voisins), puis chaque tuile franchissable non visitée fonde une région, dont
// la première porte rencontrée dans le parcours est notée. Retourne {"tuiles": [PackedInt32Array par région, index
// locaux dans l'ordre du parcours], "portes": PackedInt32Array (index local de la porte, -1 sans), "region": PackedInt32Array
// (par tuile locale : -1 extérieur, 0 mur/porte/non visité, k ≥ 1)}. Les règles (porte obligatoire, meubles, surface)
// restent en GDScript.
Dictionary SensenGrille::regions_cellule(Object *grille, Vector2i origine, int n, const PackedInt32Array &classes) {
	Dictionary res;
	Array tuiles_par_region;
	PackedInt32Array portes;
	PackedInt32Array region;
	Etat s;
	if (n <= 0 || !charger(grille, s) || !s.dans(origine.x, origine.y) || !s.dans(origine.x + n - 1, origine.y + n - 1)) {
		res["tuiles"] = tuiles_par_region;
		res["portes"] = portes;
		res["region"] = region;
		return res;
	}
	static const StringName sn_meubles("meubles");
	Dictionary meubles = grille->get(sn_meubles);
	int nn = n * n;
	std::vector<uint8_t> classe(nn, 0), meuble_ici(nn, 0);
	// Les meubles de la cellule : on parcourt le dictionnaire (quelques centaines d'entrées), pas les tuiles.
	Array cles = meubles.keys();
	for (int i = 0; i < cles.size(); ++i) {
		int gi = (int)cles[i];
		int gx = s.ox + gi % s.L, gy = s.oy + gi / s.L;
		int lx = gx - origine.x, ly = gy - origine.y;
		if (lx >= 0 && ly >= 0 && lx < n && ly < n) {
			meuble_ici[ly * n + lx] = 1;
		}
	}
	int nc = classes.size();
	const int32_t *cl = classes.ptr();
	for (int ly = 0; ly < n; ++ly) {
		for (int lx = 0; lx < n; ++lx) {
			int gi = s.idx(origine.x + lx, origine.y + ly);
			int32_t ci = s.c[gi];
			int c = 0;
			if (ci > 0) {
				c = (ci < nc) ? cl[ci] : 0;
				if (c == 3) {
					c = meuble_ici[ly * n + lx] ? 0 : 1;
				}
			}
			classe[ly * n + lx] = (uint8_t)c;
		}
	}
	std::vector<int32_t> reg(nn, 0);
	std::vector<int> pile;
	pile.reserve(1024);
	const int DXC[4] = { 1, -1, 0, 0 };
	const int DYC[4] = { 0, 0, 1, -1 };
	for (int i = 0; i < n; ++i) {
		int graines[4] = { i, (n - 1) * n + i, i * n, i * n + n - 1 };
		for (int g4 = 0; g4 < 4; ++g4) {
			int li = graines[g4];
			if (classe[li] == 0 && reg[li] == 0) {
				reg[li] = -1;
				pile.push_back(li);
			}
		}
	}
	while (!pile.empty()) {
		int li = pile.back();
		pile.pop_back();
		int lx = li % n, ly = li / n;
		for (int d = 0; d < 4; ++d) {
			int vx = lx + DXC[d], vy = ly + DYC[d];
			if (vx < 0 || vy < 0 || vx >= n || vy >= n) {
				continue;
			}
			int vi = vy * n + vx;
			if (classe[vi] == 0 && reg[vi] == 0) {
				reg[vi] = -1;
				pile.push_back(vi);
			}
		}
	}
	int k = 0;
	for (int li0 = 0; li0 < nn; ++li0) {
		if (classe[li0] != 0 || reg[li0] != 0) {
			continue;
		}
		k += 1;
		PackedInt32Array tuiles;
		int porte = -1;
		reg[li0] = k;
		pile.clear();
		pile.push_back(li0);
		while (!pile.empty()) {
			int li = pile.back();
			pile.pop_back();
			int lx = li % n, ly = li / n;
			tuiles.push_back(li);
			for (int d = 0; d < 4; ++d) {
				int vx = lx + DXC[d], vy = ly + DYC[d];
				if (vx < 0 || vy < 0 || vx >= n || vy >= n) {
					continue;
				}
				int vi = vy * n + vx;
				if (classe[vi] == 2 && porte == -1) {
					porte = vi;
				} else if (classe[vi] == 0 && reg[vi] == 0) {
					reg[vi] = k;
					pile.push_back(vi);
				}
			}
		}
		tuiles_par_region.push_back(tuiles);
		portes.push_back(porte);
	}
	region.resize(nn);
	int32_t *rp = region.ptrw();
	for (int i = 0; i < nn; ++i) {
		rp[i] = reg[i];
	}
	res["tuiles"] = tuiles_par_region;
	res["portes"] = portes;
	res["region"] = region;
	return res;
}


// La composante connexe des tuiles franchissables (à pied, sans nage forcée) autour de depart, en 8 directions :
// les index visités dans l'ordre de la vague, la tuile de départ d'abord ; s'arrête à max_tuiles (0 = sans borne).
PackedInt32Array SensenGrille::composante(Object *grille, Vector2i depart, int max_tuiles) {
	PackedInt32Array res;
	Etat s;
	if (!charger(grille, s) || !s.dans(depart.x, depart.y)) {
		return res;
	}
	int n = s.n;
	marque.assign(n, 0);
	std::vector<int> file;
	int i0 = s.idx(depart.x, depart.y);
	marque[i0] = 1;
	file.push_back(i0);
	size_t tete = 0;
	while (tete < file.size()) {
		int c = file[tete++];
		res.push_back(c);
		if (max_tuiles > 0 && (int)res.size() >= max_tuiles) {
			break;
		}
		int cx = s.px(c), cy = s.py(c);
		for (int d = 0; d < 8; ++d) {
			int vx = cx + DX[d], vy = cy + DY[d];
			if (!s.dans(vx, vy)) {
				continue;
			}
			int vi = s.idx(vx, vy);
			if (cout_pas(s, c, vx, vy, false, false) < 0) {
				continue;
			}
			if (s.li && s.li[vi] >= 0) {
				vi = s.li[vi];   // l'escalier : la composante continue à l'autre bout
			}
			if (marque[vi]) {
				continue;
			}
			marque[vi] = 1;
			file.push_back(vi);
		}
	}
	return res;
}


// ---------------------------------------------------------------- les passes de dessin (file 114, 2026-09-06)
// Transcription de PassesGD (scenes/demo/passes_gd.gd) : le brouillard et les toits en tableaux de triangles que le
// client soumet d'un coup (canvas_item_add_triangle_array). Les mêmes boucles, le même éventail de triangles par
// polygone (0, i, i+1), les mêmes couleurs — test_noyau_cpp compare les tableaux.

namespace {

struct Triangles {
	PackedVector2Array points;
	PackedColorArray couleurs;
	PackedVector2Array uvs;

	void poly(const Vector2 *pts, int n, const Color &col, const Vector2 *uv) {
		for (int i = 1; i < n - 1; ++i) {
			points.push_back(pts[0]);
			points.push_back(pts[i]);
			points.push_back(pts[i + 1]);
			couleurs.push_back(col);
			couleurs.push_back(col);
			couleurs.push_back(col);
			if (uv) {
				uvs.push_back(uv[0]);
				uvs.push_back(uv[i]);
				uvs.push_back(uv[i + 1]);
			} else {
				uvs.push_back(Vector2());
				uvs.push_back(Vector2());
				uvs.push_back(Vector2());
			}
		}
	}

	Dictionary vers(const PackedInt32Array &veg_vus, const PackedInt32Array &veg_voiles) const {
		Dictionary res;
		PackedInt32Array indices;
		indices.resize(points.size());
		int32_t *w = indices.ptrw();
		for (int i = 0; i < points.size(); ++i) {
			w[i] = i;
		}
		res["points"] = points;
		res["couleurs"] = couleurs;
		res["uvs"] = uvs;
		res["indices"] = indices;
		res["veg_vus"] = veg_vus;
		res["veg_voiles"] = veg_voiles;
		return res;
	}
};

// Une tuile est-elle vue (PassesGD.voit) : dans `vue`, ou — depuis un étage — l'air au-dessus d'elle.
inline bool voit_e(const SensenGrille::Etat &s, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, int x, int y) {
	if (tout_vu) {
		return true;
	}
	if (vue.has(s.idx(x, y))) {
		return true;
	}
	if (zj > 0 && SensenGrille::Etat::z_de(y) == 0) {
		int ya = y + zj * SensenGrille::BANDE_Z;
		if (!s.dans(x, ya)) {
			return false;
		}
		int ia = s.idx(x, ya);
		return vue.has(ia) && s.c[ia] == vide_ci;
	}
	return false;
}

inline Vector2 ecran_e(int x, int y, int h, Vector2i od, double tw, double th, double hstep) {
	int lx = x - od.x, ly = y - od.y;
	return Vector2((real_t)((lx - ly) * tw * 0.5), (real_t)((lx + ly) * th * 0.5 - h * hstep));
}

} // namespace

// PassesGD.hauteur_bloc : la hauteur dessinée du bloc d'une tuile, en unités.
static int hauteur_bloc_e(const SensenGrille::Etat &s, const uint8_t *nv, const int32_t *bd, int fl, int i, int x, int y, int bat_j, const Rect2i &rect_j, int niveau_u, int mur_coupe_u) {
	if (!(fl & SensenGrille::F_BLOQUE_PASSAGE) && !(fl & SensenGrille::F_PORTE)) {
		return 0;
	}
	if (fl & SensenGrille::F_VEGETATION) {
		return 0;
	}
	int n = nv ? (int)nv[i] : 0;
	if (n > 0 && (fl & (SensenGrille::F_MUR | SensenGrille::F_PORTE))) {
		if (bat_j > 0 && bd && bd[i] == bat_j && (y == rect_j.position.y + rect_j.size.y - 1 || x == rect_j.position.x + rect_j.size.x - 1)) {
			return mur_coupe_u;
		}
		return n * niveau_u;
	}
	return (fl & SensenGrille::F_SANS_HAUTEUR_VUE) ? 3 : ((fl >> 8) & 0xFF);
}

Dictionary SensenGrille::brouillard(Object *grille, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, Vector2i jp, int rayon, Vector2i origine_dessin,
		double tw, double th, double hstep, int niveau_u, int bat_j, int mur_coupe_u, Color voile, Color col_sil) {
	Triangles tr;
	PackedInt32Array veg_vus, veg_voiles;
	Etat s;
	if (!charger(grille, s)) {
		return tr.vers(veg_vus, veg_voiles);
	}
	static const StringName sn_decouvert("decouvert"), sn_niv("niveaux_bat"), sn_bat("bat_de"), sn_bats("batiments_liste"), sn_rect("rect");
	Dictionary decouvert = grille->get(sn_decouvert);
	PackedByteArray niv = grille->get(sn_niv);
	const uint8_t *nv = octets_ou_nul(niv, s.n);
	PackedInt32Array bat = grille->get(sn_bat);
	const int32_t *bd = (bat.size() >= s.n) ? bat.ptr() : nullptr;
	Rect2i rect_j;
	if (bat_j > 0) {
		Array bats = grille->get(sn_bats);
		if (bat_j <= bats.size()) {
			Dictionary info = bats[bat_j - 1];
			rect_j = info.get(sn_rect, Rect2i());
		} else {
			bat_j = 0;
		}
	}
	int x0 = std::max(s.ox, jp.x - rayon), x1 = std::min(s.ox + s.L - 1, jp.x + rayon);
	int y0 = std::max(s.oy, jp.y - rayon), y1 = std::min(s.oy + s.H - 1, jp.y + rayon);
	double tw2 = tw * 0.5, th2 = th * 0.5;
	Color sil_a = col_sil.darkened(0.35), sil_b = col_sil.darkened(0.5);
	for (int sd = x0 + y0; sd <= x1 + y1; ++sd) {
		for (int x = std::max(x0, sd - y1); x <= std::min(x1, sd - y0); ++x) {
			int y = sd - x;
			int i = s.idx(x, y);
			if (!decouvert.has(i)) {
				continue;
			}
			int fl = drapeaux(s, i);
			bool vegetal = (fl & F_VEGETATION) != 0;
			if (voit_e(s, vue, tout_vu, zj, vide_ci, x, y)) {
				if (vegetal) {
					veg_vus.push_back(i);
				}
				continue;
			}
			Vector2 c = ecran_e(x, y, (int)s.h[i], origine_dessin, tw, th, hstep);
			if (vegetal) {
				veg_voiles.push_back(i);
			} else if ((fl & F_BLOQUE_PASSAGE) && !(fl & F_PORTE)) {
				double hm = hauteur_bloc_e(s, nv, bd, fl, i, x, y, bat_j, rect_j, niveau_u, mur_coupe_u) * hstep;
				if (hm > 0) {
					Vector2 a[4] = { c + Vector2(-tw2, 0), c + Vector2(0, th2), c + Vector2(0, th2 - hm), c + Vector2(-tw2, -hm) };
					Vector2 b[4] = { c + Vector2(0, th2), c + Vector2(tw2, 0), c + Vector2(tw2, -hm), c + Vector2(0, th2 - hm) };
					Vector2 d[4] = { c + Vector2(-tw2, -hm), c + Vector2(0, -th2 - hm), c + Vector2(tw2, -hm), c + Vector2(0, th2 - hm) };
					tr.poly(a, 4, sil_a, nullptr);
					tr.poly(b, 4, sil_b, nullptr);
					tr.poly(d, 4, col_sil, nullptr);
				}
				continue;
			}
			Vector2 v[4] = { c + Vector2(-tw2, 0), c + Vector2(0, -th2), c + Vector2(tw2, 0), c + Vector2(0, th2) };
			tr.poly(v, 4, voile, nullptr);
		}
	}
	return tr.vers(veg_vus, veg_voiles);
}

Dictionary SensenGrille::toits(Object *grille, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, Vector2i jp, int rayon, Vector2i origine_dessin,
		double tw, double th, double hstep, int niveau_u, int bat_j, const PackedColorArray &bat_couleurs, const PackedFloat32Array &bat_styles,
		double pente_t, double haut_toit, double ombre_min, Vector2 soleil_h, bool soleil_ok, double soleil_force, double uv_haut) {
	Triangles tr;
	PackedInt32Array rien;
	Etat s;
	if (!charger(grille, s)) {
		return tr.vers(rien, rien);
	}
	static const StringName sn_decouvert("decouvert"), sn_niv("niveaux_bat"), sn_bat("bat_de"), sn_bats("batiments_liste"), sn_rect("rect");
	Array bats = grille->get(sn_bats);
	int nb = bats.size();
	if (nb == 0) {
		return tr.vers(rien, rien);
	}
	Dictionary decouvert = grille->get(sn_decouvert);
	PackedByteArray niv = grille->get(sn_niv);
	const uint8_t *nv = octets_ou_nul(niv, s.n);
	PackedInt32Array bat = grille->get(sn_bat);
	const int32_t *bd = (bat.size() >= s.n) ? bat.ptr() : nullptr;
	if (!nv || !bd) {
		return tr.vers(rien, rien);
	}
	std::vector<Rect2i> rects(nb);
	for (int b = 0; b < nb; ++b) {
		Dictionary info = bats[b];
		rects[b] = info.get(sn_rect, Rect2i());
	}
	int x0 = std::max(s.ox, jp.x - rayon), x1 = std::min(s.ox + s.L - 1, jp.x + rayon);
	int y0 = std::max(s.oy, jp.y - rayon), y1 = std::min(s.oy + s.H - 1, jp.y + rayon);
	std::vector<uint8_t> vus(nb, 0);
	for (int b = 0; b < nb; ++b) {
		const Rect2i &r = rects[b];
		int ex = r.position.x + r.size.x, ey = r.position.y + r.size.y;
		if (r.position.x > x1 || ex <= x0 || r.position.y > y1 || ey <= y0) {
			continue;
		}
		bool vu = false;
		for (int y = 0; y < r.size.y && !vu; ++y) {
			for (int x = 0; x < r.size.x; ++x) {
				if (voit_e(s, vue, tout_vu, zj, vide_ci, r.position.x + x, r.position.y + y)) {
					vu = true;
					break;
				}
			}
		}
		vus[b] = vu ? 1 : 0;
	}
	for (int sd = x0 + y0; sd <= x1 + y1; ++sd) {
		for (int x = std::max(x0, sd - y1); x <= std::min(x1, sd - y0); ++x) {
			int y = sd - x;
			int i = s.idx(x, y);
			int n = (int)nv[i];
			if (n == 0 || !decouvert.has(i)) {
				continue;
			}
			int b = bd[i];
			if (b == bat_j || b <= 0 || b > bat_couleurs.size()) {
				continue;
			}
			Color col = bat_couleurs[b - 1];
			double st = (b - 1 < bat_styles.size()) ? (double)bat_styles[b - 1] : 0.0;
			if (!vus[b - 1]) {
				col = col.darkened(0.55);
			}
			const Rect2i &r = rects[b - 1];
			int ex = r.position.x + r.size.x, ey = r.position.y + r.size.y;
			double base_px = (double)s.h[i] * hstep + (double)(n * niveau_u) * hstep;
			int cx[4] = { x, x + 1, x + 1, x };
			int cy[4] = { y, y, y + 1, y + 1 };
			Vector2 pts[4];
			double eleves[4];
			for (int k = 0; k < 4; ++k) {
				int d = std::min(std::min(cx[k] - r.position.x, ex - cx[k]), std::min(cy[k] - r.position.y, ey - cy[k]));
				double eleve = std::min((double)d, pente_t) / pente_t * haut_toit;
				eleves[k] = eleve;
				int lx = cx[k] - origine_dessin.x, ly = cy[k] - origine_dessin.y;
				pts[k] = Vector2((real_t)((lx - ly) * tw * 0.5), (real_t)((lx + ly) * th * 0.5 - th * 0.5 - base_px - eleve));
			}
			Color col_v = col;
			if (soleil_ok) {
				double gx = (eleves[1] + eleves[2] - eleves[0] - eleves[3]) * 0.5;
				double gy = (eleves[2] + eleves[3] - eleves[0] - eleves[1]) * 0.5;
				if (std::abs(gx) + std::abs(gy) > 0.01) {
					Vector2 dehors = Vector2((real_t)-gx, (real_t)-gy).normalized();
					Vector2 n_ecran = Vector2((real_t)((dehors.x - dehors.y) / std::sqrt(2.0)), (real_t)((dehors.x + dehors.y) / std::sqrt(2.0)));
					double lambert = std::min(1.0, std::max(0.0, (double)n_ecran.dot(soleil_h)));
					double f = 1.0 + ((ombre_min + (1.0 - ombre_min) * lambert) - 1.0) * soleil_force;   // lerp(1, lerp(ombre_min, 1, lambert), force)
					col_v = col * (real_t)f;
					col_v.a = col.a;
				}
			}
			int lx0 = x - origine_dessin.x, ly0 = y - origine_dessin.y;
			Vector2 uv[4] = { Vector2((real_t)(st + lx0), (real_t)(uv_haut + ly0)), Vector2((real_t)(st + lx0 + 1), (real_t)(uv_haut + ly0)),
				Vector2((real_t)(st + lx0 + 1), (real_t)(uv_haut + ly0 + 1)), Vector2((real_t)(st + lx0), (real_t)(uv_haut + ly0 + 1)) };
			tr.poly(pts, 4, col_v, uv);
		}
	}
	return tr.vers(rien, rien);
}


// PassesGD.visibles : pour chaque être (sa position), ce que le client en montre — bit 1 : à portée du joueur (distance
// au sol ≤ rayon) et dans son champ de vue ; bit 2 : et pas sous le toit d'un autre bâtiment (ni d'un autre étage du sien).
// Un appel par image pour tous les êtres, à la place de trois fonctions par être en GDScript (file 114, 2026-09-06).
PackedByteArray SensenGrille::visibles(Object *grille, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, Vector2i jp, int rayon, int bat_j, const PackedVector2Array &positions) {
	PackedByteArray res;
	res.resize(positions.size());
	uint8_t *w = res.ptrw();
	Etat s;
	if (!charger(grille, s)) {
		for (int k = 0; k < positions.size(); ++k) {
			w[k] = 0;
		}
		return res;
	}
	static const StringName sn_bat("bat_de");
	PackedInt32Array bat = grille->get(sn_bat);
	const int32_t *bd = (bat.size() >= s.n) ? bat.ptr() : nullptr;
	int jz = SensenGrille::Etat::z_de(jp.y);
	int jpx = jp.x, jpy = jp.y - jz * BANDE_Z;
	for (int k = 0; k < positions.size(); ++k) {
		int x = (int)positions[k].x, y = (int)positions[k].y;
		int z = SensenGrille::Etat::z_de(y);
		int py = y - z * BANDE_Z;
		uint8_t f = 0;
		if (std::max(std::abs(x - jpx), std::abs(py - jpy)) <= rayon && s.dans(x, y) && voit_e(s, vue, tout_vu, zj, vide_ci, x, y)) {
			f = 1;
			int b = bd ? bd[s.idx(x, y)] : 0;
			if (!(b > 0 && (b != bat_j || z != jz))) {
				f |= 2;
			}
		}
		w[k] = f;
	}
	return res;
}


// ---------------------------------------------------------------- les morceaux de terrain (PassesGD.morceau, file 114)
// Transcription de PassesGD._tuile / _bloc / _porte : les triangles d'un morceau de 8 × 8 tuiles découvertes, dans
// l'ordre des diagonales, avec les COUPURES (à tel nombre de points, telle tuile demande une commande que les triangles
// ne portent pas : la traverse d'une porte, un contenant, un sprite) et les végétaux. Les tables (couleur et grain par
// matériau, par meuble, par contenu ; les matériaux des bâtiments) viennent du client dans `p`.

namespace {

struct Morceau {
	Triangles tr;
	PackedInt32Array coupures, vegetaux;
	// les tables
	Dictionary mat_col, mat_st, meuble_col, meuble_emprise, sols, materiaux, meubles, stations, decouvert;
	PackedColorArray contenu_col;
	PackedStringArray bat_mur_id, bat_pierre_id, bat_bois_id;
	std::vector<Rect2i> rects;
	String materiau_defaut, materiau_mur_defaut;
	Vector2i od;
	double tw = 40, th = 20, hstep = 8, uv_haut = 4096, uv_so = -1000, uv_se = -2000, uv_pas_face = 32;
	int niveau_u = 6, bloc_u = 2, porte_u = 4, mur_coupe_u = 1, bat_j = 0;
	const uint8_t *nv = nullptr;
	const int32_t *bd = nullptr;

	void coupure(int idx, int genre) {
		coupures.push_back(tr.points.size());
		coupures.push_back(idx);
		coupures.push_back(genre);
	}
	Vector2 uv_h(int x, int y, double dx, double dy, double st) const {
		int lx = x - od.x, ly = y - od.y;
		return Vector2((real_t)(st + lx + dx), (real_t)(uv_haut + ly + dy));
	}
	Vector2 uv_o(int x, int y, double dx, double hh, double st) const {
		int lx = x - od.x, ly = y - od.y;
		return Vector2((real_t)(st + lx + dx), (real_t)(uv_so - (ly * uv_pas_face + hh)));
	}
	Vector2 uv_e(int x, int y, double dy, double hh, double st) const {
		int lx = x - od.x, ly = y - od.y;
		return Vector2((real_t)(st + ly + dy), (real_t)(uv_se - (lx * uv_pas_face + hh)));
	}
	bool couleur_mat(const String &id, Color *out) const {
		Variant v = mat_col.get(id, Variant());
		if (v.get_type() != Variant::COLOR) {
			return false;
		}
		*out = v;
		return true;
	}
	double style(const String &id) const {
		Variant v = mat_st.get(id, Variant());
		return (v.get_type() == Variant::FLOAT || v.get_type() == Variant::INT) ? (double)v : 0.0;
	}
	String chaine(const Dictionary &d, int i, const String &defaut) const {
		Variant v = d.get(i, Variant());
		return (v.get_type() == Variant::STRING) ? (String)v : defaut;
	}
	bool mur_coupe(int x, int y, int i) const {
		if (bat_j <= 0 || bat_j > (int)rects.size() || !bd || bd[i] != bat_j) {
			return false;
		}
		const Rect2i &r = rects[bat_j - 1];
		return y == r.position.y + r.size.y - 1 || x == r.position.x + r.size.x - 1;
	}
};

} // namespace

// PassesGD._bloc
static void bloc_e(Morceau &m, const SensenGrille::Etat &s, const SensenGrille *k, int x, int y, Vector2 c, Color teinte, int base_u, int plafond_u) {
	int i = s.idx(x, y);
	int fl = k->drapeaux_public(s, i);
	int n_bat = m.nv ? (int)m.nv[i] : 0;
	bool mur_bat = n_bat > 0 && (fl & (SensenGrille::F_MUR | SensenGrille::F_PORTE));
	int hv = (fl & SensenGrille::F_SANS_HAUTEUR_VUE) ? 3 : ((fl >> 8) & 0xFF);
	int hm = (int)((mur_bat ? n_bat * m.niveau_u : hv) * m.hstep);
	if (plafond_u > 0) {
		hm = std::min(hm, (int)(plafond_u * m.hstep));
	}
	Color haut_bloc(0.5f, 0.47f, 0.44f);
	String mat_id = m.chaine(m.materiaux, i, m.materiau_defaut);
	int b_idx = m.bd ? m.bd[i] : 0;
	if (mur_bat && (fl & SensenGrille::F_PORTE) && b_idx > 0 && b_idx <= m.bat_mur_id.size()) {
		mat_id = m.bat_mur_id[b_idx - 1];
	}
	Color col_mat;
	bool a_mat = m.couleur_mat(mat_id, &col_mat);
	double emprise = 1.0;
	Variant v_meuble = m.meubles.get(i, Variant());
	if ((fl & SensenGrille::F_MEUBLE) && v_meuble.get_type() == Variant::STRING) {
		String mid = v_meuble;
		Variant vc = m.meuble_col.get(mid, Variant());
		if (vc.get_type() == Variant::COLOR) {
			haut_bloc = vc;
		}
		Variant ve = m.meuble_emprise.get(mid, Variant());
		emprise = (ve.get_type() == Variant::FLOAT || ve.get_type() == Variant::INT) ? (double)ve : 0.6;
		hm = (int)std::round((double)hm * emprise);
	} else if ((fl & SensenGrille::F_COULEUR) && !mur_bat) {
		haut_bloc = m.contenu_col[s.c[i]];
	} else if (fl & SensenGrille::F_ARBRE) {
		haut_bloc = Color(0.22f, 0.45f, 0.18f).lerp(a_mat ? col_mat : haut_bloc, 0.2f);
	} else if (a_mat) {
		haut_bloc = haut_bloc.lerp(col_mat, (m.materiaux.has(i) || mur_bat) ? 0.55f : 0.35f);
	}
	haut_bloc = haut_bloc * teinte;
	String mat_bloc = mat_id.is_empty() ? m.materiau_mur_defaut : mat_id;
	double st_bloc = m.style(mat_bloc);
	double tw = m.tw * 0.5 * emprise, th = m.th * 0.5 * emprise;
	int h0 = (int)(base_u * m.hstep);
	auto hauteur_voisin = [&](int vx, int vy, bool *ok) -> double {
		*ok = false;
		if (!s.dans(vx, vy)) {
			return 0.0;
		}
		int vi = s.idx(vx, vy);
		if (!m.decouvert.has(vi)) {
			return 0.0;
		}
		*ok = true;
		Rect2i rect_j;
		if (m.bat_j > 0 && m.bat_j <= (int)m.rects.size()) {
			rect_j = m.rects[m.bat_j - 1];
		}
		return hauteur_bloc_e(s, m.nv, m.bd, k->drapeaux_public(s, vi), vi, vx, vy, m.bat_j, rect_j, m.niveau_u, m.mur_coupe_u) * m.hstep;
	};
	bool ok_s = false, ok_e = false;
	double hvs = hauteur_voisin(x, y + 1, &ok_s), hve = hauteur_voisin(x + 1, y, &ok_e);
	bool face_so = !(ok_s && hvs >= hm);
	bool face_se = !(ok_e && hve >= hm);
	int bande = mur_bat ? (int)(m.bloc_u * m.hstep) : hm;
	int yy = h0;
	Color col_haut = haut_bloc;
	double st_haut = st_bloc;
	while (yy < hm) {
		int y1 = std::min(hm, yy + bande);
		Color col_b = haut_bloc;
		double st_b = st_bloc;
		if (mur_bat) {
			int bloc_k = yy / (int)(m.bloc_u * m.hstep);
			String bois = (b_idx > 0 && b_idx <= m.bat_bois_id.size()) ? m.bat_bois_id[b_idx - 1] : String();
			String mat_b = (bloc_k > 0 && !bois.is_empty()) ? bois : ((b_idx > 0 && b_idx <= m.bat_pierre_id.size()) ? m.bat_pierre_id[b_idx - 1] : String());
			if (mat_b.is_empty()) {
				mat_b = mat_id;
			}
			Color cm;
			if (m.couleur_mat(mat_b, &cm)) {
				col_b = Color(0.5f, 0.47f, 0.44f).lerp(cm, 0.65f) * teinte;
			}
			st_b = m.style(mat_b);
		}
		double fy = (double)yy / m.hstep, fy1 = (double)y1 / m.hstep;
		if (face_so) {
			Vector2 q[4] = { c + Vector2((real_t)-tw, (real_t)-yy), c + Vector2(0, (real_t)(th - yy)), c + Vector2(0, (real_t)(th - y1)), c + Vector2((real_t)-tw, (real_t)-y1) };
			Vector2 uv[4] = { m.uv_o(x, y, 0, fy, st_b), m.uv_o(x, y, 1, fy, st_b), m.uv_o(x, y, 1, fy1, st_b), m.uv_o(x, y, 0, fy1, st_b) };
			m.tr.poly(q, 4, col_b.darkened(0.35f), uv);
		}
		if (face_se) {
			Vector2 q[4] = { c + Vector2(0, (real_t)(th - yy)), c + Vector2((real_t)tw, (real_t)-yy), c + Vector2((real_t)tw, (real_t)-y1), c + Vector2(0, (real_t)(th - y1)) };
			Vector2 uv[4] = { m.uv_e(x, y, 0, fy, st_b), m.uv_e(x, y, 1, fy, st_b), m.uv_e(x, y, 1, fy1, st_b), m.uv_e(x, y, 0, fy1, st_b) };
			m.tr.poly(q, 4, col_b.darkened(0.5f), uv);
		}
		col_haut = col_b;
		st_haut = st_b;
		yy = y1;
	}
	Vector2 q[4] = { c + Vector2((real_t)-tw, (real_t)-hm), c + Vector2(0, (real_t)(-th - hm)), c + Vector2((real_t)tw, (real_t)-hm), c + Vector2(0, (real_t)(th - hm)) };
	Vector2 uv[4] = { m.uv_h(x, y, 0, 1, st_haut), m.uv_h(x, y, 0, 0, st_haut), m.uv_h(x, y, 1, 0, st_haut), m.uv_h(x, y, 1, 1, st_haut) };
	m.tr.poly(q, 4, col_haut, uv);
}

// PassesGD._porte
static void porte_e(Morceau &m, const SensenGrille::Etat &s, const SensenGrille *k, int x, int y, Vector2 c, int fl, Color teinte) {
	int i = s.idx(x, y);
	Color bois = m.contenu_col[s.c[i]] * teinte;
	auto bloque = [&](int vx, int vy) -> bool {
		if (!s.dans(vx, vy)) {
			return false;
		}
		return (k->drapeaux_public(s, s.idx(vx, vy)) & SensenGrille::F_BLOQUE_PASSAGE) != 0;
	};
	bool mur_x = bloque(x + 1, y) || bloque(x - 1, y);
	Vector2 demi = mur_x ? Vector2((real_t)(m.tw * 0.25), (real_t)(m.th * 0.25)) : Vector2((real_t)(m.tw * 0.25), (real_t)(-m.th * 0.25));
	Vector2 a = c - demi, b = c + demi;
	int n_bat = m.nv ? (int)m.nv[i] : 0;
	int hv = (fl & SensenGrille::F_SANS_HAUTEUR_VUE) ? 2 : ((fl >> 8) & 0xFF);
	Vector2 haut(0, (real_t)(-(double)(n_bat > 0 ? m.porte_u : hv) * m.hstep));
	Vector2 uvp = m.uv_h(x, y, 0.5, 0.5, 0.0);
	Vector2 uv[4] = { uvp, uvp, uvp, uvp };
	Vector2 montants[2] = { a, b };
	for (int j = 0; j < 2; ++j) {
		Vector2 mm = montants[j];
		Vector2 q[4] = { mm + Vector2(-1.5f, 0), mm + Vector2(1.5f, 0), mm + Vector2(1.5f, 0) + haut, mm + Vector2(-1.5f, 0) + haut };
		m.tr.poly(q, 4, bois.darkened(0.45f), uv);
	}
	bool ferme = (fl & SensenGrille::F_FERMEE) != 0;
	Vector2 p0 = ferme ? a : a.lerp(b, 0.68f);
	Vector2 p1 = b;
	Vector2 q1[4] = { p0, p1, p1 + haut, p0 + haut };
	m.tr.poly(q1, 4, bois, uv);
	Vector2 q2[4] = { p0, p1, p1 + haut * 0.08f, p0 + haut * 0.08f };
	m.tr.poly(q2, 4, bois.darkened(0.3f), uv);
	m.coupure(i, 1);
}

// PassesGD._tuile
static void tuile_e(Morceau &m, const SensenGrille::Etat &s, const SensenGrille *k, int x, int y) {
	int i = s.idx(x, y);
	int h = (int)s.h[i];
	Vector2 c = ecran_e(x, y, h, m.od, m.tw, m.th, m.hstep);
	Color teinte(1, 1, 1, 1);
	int ci = s.c[i];
	int fl = k->drapeaux_public(s, i);
	bool vide_def = ci <= 0;
	double tw = m.tw, th = m.th;
	if (fl & SensenGrille::F_LIQUIDE) {
		Color col_eau = m.contenu_col[ci];
		if (fl & SensenGrille::F_ECOULEMENT) {
			col_eau = col_eau.lerp(Color(0.6f, 0.8f, 0.95f), (real_t)(1.0 - (double)k->niveau_liquide_public(s, i) / 8.0));
		}
		if (s.gel) {
			col_eau = col_eau.lerp(Color(0.85f, 0.92f, 1.0f), 0.7f);
		}
		double st_eau = m.style("eau");
		Vector2 q[4] = { c + Vector2(0, (real_t)(-th * 0.5)), c + Vector2((real_t)(tw * 0.5), 0), c + Vector2(0, (real_t)(th * 0.5)), c + Vector2((real_t)(-tw * 0.5), 0) };
		Vector2 uv[4] = { m.uv_h(x, y, 0, 0, st_eau), m.uv_h(x, y, 1, 0, st_eau), m.uv_h(x, y, 1, 1, st_eau), m.uv_h(x, y, 0, 1, st_eau) };
		m.tr.poly(q, 4, col_eau * teinte, uv);
		return;
	}
	if (s.neige) {
		teinte = teinte.lerp(Color(1.4f, 1.4f, 1.5f), 0.5f);
	}
	bool bloque = (fl & SensenGrille::F_BLOQUE_PASSAGE) != 0;
	bool porte = (fl & SensenGrille::F_PORTE) != 0;
	if (bloque && !(fl & SensenGrille::F_VEGETATION) && !porte) {
		bloc_e(m, s, k, x, y, c, teinte, 0, m.mur_coupe(x, y, i) ? m.mur_coupe_u : 0);
		if (m.meubles.has(i) || m.stations.has(i)) {
			m.coupure(i, 3);
		}
		return;
	}
	double kk = std::min(1.0, std::max(0.0, (h - 4) / 12.0));
	Color col = Color(0.20f, 0.34f, 0.18f).lerp(Color(0.62f, 0.66f, 0.42f), (real_t)kk);
	String sol_id = m.chaine(m.sols, i, String());
	Color cs;
	if (!sol_id.is_empty() && m.couleur_mat(sol_id, &cs)) {
		col = cs.lerp(Color(0.35f, 0.5f, 0.25f), sol_id.begins_with("terre") ? 0.35f : 0.0f).darkened((real_t)(0.25 - kk * 0.3));
	}
	col = col * teinte;
	double st_sol = m.style(sol_id);
	{
		Vector2 q[4] = { c + Vector2(0, (real_t)(-th * 0.5)), c + Vector2((real_t)(tw * 0.5), 0), c + Vector2(0, (real_t)(th * 0.5)), c + Vector2((real_t)(-tw * 0.5), 0) };
		Vector2 uv[4] = { m.uv_h(x, y, 0, 0, st_sol), m.uv_h(x, y, 1, 0, st_sol), m.uv_h(x, y, 1, 1, st_sol), m.uv_h(x, y, 0, 1, st_sol) };
		m.tr.poly(q, 4, col, uv);
	}
	Color flanc = col.darkened(0.35f);
	int hs = s.dans(x, y + 1) ? (int)s.h[s.idx(x, y + 1)] : 0;
	if (hs < h) {
		double d = (h - hs) * m.hstep;
		Vector2 q[4] = { c + Vector2((real_t)(-tw * 0.5), 0), c + Vector2(0, (real_t)(th * 0.5)), c + Vector2(0, (real_t)(th * 0.5 + d)), c + Vector2((real_t)(-tw * 0.5), (real_t)d) };
		Vector2 uv[4] = { m.uv_o(x, y, 0, h, st_sol), m.uv_o(x, y, 1, h, st_sol), m.uv_o(x, y, 1, hs, st_sol), m.uv_o(x, y, 0, hs, st_sol) };
		m.tr.poly(q, 4, flanc, uv);
	}
	int he = s.dans(x + 1, y) ? (int)s.h[s.idx(x + 1, y)] : 0;
	if (he < h) {
		double d2 = (h - he) * m.hstep;
		Vector2 q[4] = { c + Vector2(0, (real_t)(th * 0.5)), c + Vector2((real_t)(tw * 0.5), 0), c + Vector2((real_t)(tw * 0.5), (real_t)d2), c + Vector2(0, (real_t)(th * 0.5 + d2)) };
		Vector2 uv[4] = { m.uv_e(x, y, 0, h, st_sol), m.uv_e(x, y, 1, h, st_sol), m.uv_e(x, y, 1, he, st_sol), m.uv_e(x, y, 0, he, st_sol) };
		m.tr.poly(q, 4, flanc.darkened(0.15f), uv);
	}
	bool meuble = (fl & SensenGrille::F_MEUBLE) != 0;
	if (!vide_def && !bloque && !porte && ((fl & SensenGrille::F_COULEUR) || meuble)) {
		Color cf = m.contenu_col[ci];
		if (meuble) {
			String mid = m.chaine(m.meubles, i, "tapis");
			Variant vc = m.meuble_col.get(mid, Variant());
			cf = (vc.get_type() == Variant::COLOR) ? (Color)vc : Color(1, 1, 1, 1);
		}
		Vector2 q[4] = { c + Vector2(0, (real_t)(-th * 0.35)), c + Vector2((real_t)(tw * 0.35), 0), c + Vector2(0, (real_t)(th * 0.35)), c + Vector2((real_t)(-tw * 0.35), 0) };
		Vector2 uv[4] = { m.uv_h(x, y, 0.15, 0.15, 0), m.uv_h(x, y, 0.85, 0.15, 0), m.uv_h(x, y, 0.85, 0.85, 0), m.uv_h(x, y, 0.15, 0.85, 0) };
		m.tr.poly(q, 4, cf * teinte, uv);
		if (m.meubles.has(i) || m.stations.has(i)) {
			m.coupure(i, 3);
		}
	}
	if (porte) {
		if (m.mur_coupe(x, y, i)) {
			Color cs2 = m.contenu_col[ci] * teinte;
			Vector2 q[4] = { c + Vector2(0, (real_t)(-th * 0.35)), c + Vector2((real_t)(tw * 0.35), 0), c + Vector2(0, (real_t)(th * 0.35)), c + Vector2((real_t)(-tw * 0.35), 0) };
			Vector2 uv[4] = { m.uv_h(x, y, 0.15, 0.15, 0), m.uv_h(x, y, 0.85, 0.15, 0), m.uv_h(x, y, 0.85, 0.85, 0), m.uv_h(x, y, 0.15, 0.85, 0) };
			m.tr.poly(q, 4, cs2, uv);
		} else {
			porte_e(m, s, k, x, y, c, fl, teinte);
			if (m.nv && m.nv[i] > 0) {
				bloc_e(m, s, k, x, y, c, teinte, m.porte_u, 0);
			}
		}
	}
	if (fl & SensenGrille::F_CONTENANT) {
		m.coupure(i, 2);
	}
}

Dictionary SensenGrille::morceau(Object *grille, Vector2i coin, int taille_morceau, const Dictionary &p) {
	Morceau m;
	Etat s;
	Dictionary res;
	if (!charger(grille, s)) {
		res = m.tr.vers(PackedInt32Array(), PackedInt32Array());
		res["coupures"] = m.coupures;
		res["vegetaux"] = m.vegetaux;
		return res;
	}
	static const StringName sn_decouvert("decouvert"), sn_niv("niveaux_bat"), sn_bat("bat_de"), sn_bats("batiments_liste"), sn_rect("rect"),
			sn_sols("sols"), sn_materiaux("materiaux"), sn_meubles("meubles"), sn_stations("stations_fixes"), sn_defaut("materiau_defaut");
	m.decouvert = grille->get(sn_decouvert);
	m.sols = grille->get(sn_sols);
	m.materiaux = grille->get(sn_materiaux);
	m.meubles = grille->get(sn_meubles);
	m.stations = grille->get(sn_stations);
	m.materiau_defaut = grille->get(sn_defaut);
	PackedByteArray niv = grille->get(sn_niv);
	m.nv = octets_ou_nul(niv, s.n);
	PackedInt32Array bat = grille->get(sn_bat);
	m.bd = (bat.size() >= s.n) ? bat.ptr() : nullptr;
	Array bats = grille->get(sn_bats);
	for (int b = 0; b < bats.size(); ++b) {
		Dictionary info = bats[b];
		m.rects.push_back(info.get(sn_rect, Rect2i()));
	}
	m.mat_col = p.get("mat_col", Dictionary());
	m.mat_st = p.get("mat_st", Dictionary());
	m.meuble_col = p.get("meuble_col", Dictionary());
	m.meuble_emprise = p.get("meuble_emprise", Dictionary());
	m.contenu_col = p.get("contenu_col", PackedColorArray());
	m.bat_mur_id = p.get("bat_mur_id", PackedStringArray());
	m.bat_pierre_id = p.get("bat_pierre_id", PackedStringArray());
	m.bat_bois_id = p.get("bat_bois_id", PackedStringArray());
	m.materiau_mur_defaut = p.get("materiau_mur_defaut", String());
	m.od = p.get("origine_dessin", Vector2i());
	m.tw = (double)p.get("tw", 40.0);
	m.th = (double)p.get("th", 20.0);
	m.hstep = (double)p.get("hstep", 8.0);
	m.uv_haut = (double)p.get("uv_haut", 4096.0);
	m.uv_so = (double)p.get("uv_so", -1000.0);
	m.uv_se = (double)p.get("uv_se", -2000.0);
	m.uv_pas_face = (double)p.get("uv_pas_face", 32.0);
	m.niveau_u = (int)p.get("niveau_u", 6);
	m.bloc_u = (int)p.get("bloc_u", 2);
	m.porte_u = (int)p.get("porte_u", 4);
	m.mur_coupe_u = (int)p.get("mur_coupe_u", 1);
	m.bat_j = (int)p.get("bat_j", 0);
	if (m.contenu_col.size() < (int)table.size()) {
		m.contenu_col.resize(table.size());
	}
	int x0 = s.ox + coin.x * taille_morceau, y0 = s.oy + coin.y * taille_morceau;
	int x1 = std::min(s.ox + s.L - 1, x0 + taille_morceau - 1), y1 = std::min(s.oy + s.H - 1, y0 + taille_morceau - 1);
	for (int sd = x0 + y0; sd <= x1 + y1; ++sd) {
		for (int x = std::max(x0, sd - y1); x <= std::min(x1, sd - y0); ++x) {
			int y = sd - x;
			int i = s.idx(x, y);
			if (!m.decouvert.has(i)) {
				continue;
			}
			tuile_e(m, s, this, x, y);
			if (drapeaux(s, i) & F_VEGETATION) {
				m.vegetaux.push_back(i);
			}
		}
	}
	res = m.tr.vers(PackedInt32Array(), PackedInt32Array());
	res["coupures"] = m.coupures;
	res["vegetaux"] = m.vegetaux;
	return res;
}
