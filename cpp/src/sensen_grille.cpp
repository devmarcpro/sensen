#include "sensen_grille.h"

#include <godot_cpp/core/class_db.hpp>

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
	ClassDB::bind_method(D_METHOD("ombres", "grille", "dir", "pente", "coin", "taille", "max_pas", "unites_par_niveau"), &SensenGrille::ombres);
}

// La carte d'ombre d'une fenêtre de tuiles (Éclairage, le soleil, 2026-09-06) — transcription de Grille._ombres_gd :
// depuis chaque tuile, marcher vers le soleil (`dir`, direction dans la grille, unitaire) ; au k-ième pas, ce qui se
// dresse là (le sol, plus le bloc : hauteur_vue d'un contenu qui bloque la vue, ou les niveaux du bâtiment ×
// unites_par_niveau) fait de l'ombre s'il dépasse le sol de la tuile de plus de `pente` × k unités. Résultat : un octet
// par tuile du rectangle coin/taille, ligne par ligne, 1 = à l'ombre.
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
	uint8_t *out = res.ptrw();
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
			sn_gel("gel"), sn_occupants("occupants");
	if (grille == nullptr) {
		return false;
	}
	s.L = (int)grille->get(sn_largeur);
	s.H = (int)grille->get(sn_hauteur);
	Vector2i o = grille->get(sn_origine);
	s.ox = o.x;
	s.oy = o.y;
	int n = s.L * s.H;
	if (n <= 0) {
		return false;
	}
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
	int n = s.L * s.H;
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
				res.push_back(Vector2i(s.ox + t % s.L, s.oy + t / s.L));
			}
			return res;
		}
		int gc = g_cout[ci];
		for (int k = 0; k < 8; ++k) {
			int vx = cx + DX[k], vy = cy + DY[k];
			int cout = cout_pas(s, ci, vx, vy, volant, eviter_nage);
			if (cout < 0) {
				continue;
			}
			int vi = s.idx(vx, vy);
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
				tas_push(ouverts, { vx, vy, ng + base * distance_(Vector2i(vx, vy), arrivee) });
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
	int n = s.L * s.H;
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
		int cx = s.ox + c % s.L, cy = s.oy + c / s.L;
		for (int d = 0; d < 8; ++d) {
			int vx = cx + DX[d], vy = cy + DY[d];
			int cout = cout_pas(s, c, vx, vy, volant, eviter_nage);
			if (cout < 0) {
				continue;
			}
			int vi = s.idx(vx, vy);
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
		res[Vector2i(s.ox + t % s.L, s.oy + t / s.L)] = g_cout[t];
	}
	return res;
}

// Grille.ligne_de_vue / premier_obstacle_vue : la même ligne interpolée, les mêmes arrondis.
bool SensenGrille::ligne_de_vue_e(const Etat &s, Vector2i a, Vector2i b, Vector2i *obstacle) const {
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
	int n = s.L * s.H;
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
		int cx = s.ox + c % s.L, cy = s.oy + c / s.L;
		for (int d = 0; d < 8; ++d) {
			int vx = cx + DX[d], vy = cy + DY[d];
			if (!s.dans(vx, vy)) {
				continue;
			}
			int vi = s.idx(vx, vy);
			if (marque[vi]) {
				continue;
			}
			if (cout_pas(s, c, vx, vy, false, false) < 0) {
				continue;
			}
			marque[vi] = 1;
			file.push_back(vi);
		}
	}
	return res;
}
