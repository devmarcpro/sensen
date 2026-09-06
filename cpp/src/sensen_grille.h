// SensenGrille — le noyau pur de calcul de la grille (Modules de la simulation et le C++, section 3, 2026-09-06).
// Aucune règle de jeu n'y vit : les paramètres viennent de combat_rules.json (configurer), l'état reste dans la
// Grille GDScript, lue au moment de l'appel (Object::get sur ses tableaux compacts). Chaque fonction est la
// transcription littérale de son originale de grille.gd — même ordre de parcours, même tas, mêmes arrondis —
// pour rendre exactement le même résultat (test_noyau_cpp le vérifie).
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <cstdint>
#include <vector>

namespace godot {

class SensenGrille : public RefCounted {
	GDCLASS(SensenGrille, RefCounted)

public:
	// Les drapeaux d'un index de contenu (la table vient de Grille._table_contenus : tile_contents.json compilé).
	enum Drapeaux {
		F_BLOQUE_PASSAGE = 1,
		F_FERMEE = 2,
		F_NAGE = 4,
		F_LIQUIDE = 8,
		F_SOURCE = 16,
		F_ECOULEMENT = 32,
		F_BLOQUE_VUE = 64,
		// bits 8..15 : hauteur_vue du contenu
		F_PORTE = 1 << 16,          // tag « porte »
		F_VEGETATION = 1 << 17,     // tag « vegetation »
		F_MUR = 1 << 18,            // tag « mur »
		F_SANS_HAUTEUR_VUE = 1 << 19,   // la définition n'a pas de hauteur_vue (le dessin en prend 3)
		F_MEUBLE = 1 << 20,         // tag « meuble »
		F_CONTENANT = 1 << 21,      // tag « contenant »
		F_COULEUR = 1 << 22,        // la définition porte une couleur
		F_ARBRE = 1 << 23,          // tag « arbre »
		F_VIDE_DEF = 1 << 24,       // aucune définition (contenu 0)
	};

	// La vue d'une grille le temps d'un appel : des pointeurs sur ses tableaux (les références tiennent les tampons).
	// Les couches Z (Grille.gd, 2026-09-06) : y porte z × BANDE_Z, les index s'empilent par couche (n0 tuiles chacune).
	static const int BANDE_Z = 1 << 20;

	struct Etat {
		int L = 0, H = 0, ox = 0, oy = 0;
		int couches = 1, n0 = 0, n = 0;   // n0 : tuiles d'une couche ; n : toutes couches
		PackedByteArray hauteurs, occ, dangers, eau;
		PackedInt32Array contenu, lien;
		PackedFloat64Array frottement;
		const uint8_t *h = nullptr, *o = nullptr, *d = nullptr, *e = nullptr;
		const int32_t *c = nullptr, *li = nullptr;   // li : l'escalier de chaque tuile (−1 sans), ou nul
		const double *f = nullptr;
		bool neige = false, gel = false;
		Dictionary occupants;

		static inline int z_de(int y) { return y >= 0 ? y / BANDE_Z : 0; }
		inline bool dans(int x, int y) const {
			int z = z_de(y);
			if (z >= couches) {
				return false;
			}
			int ly = y - z * BANDE_Z;
			return x >= ox && ly >= oy && x < ox + L && ly < oy + H;
		}
		inline int idx(int x, int y) const {
			int z = z_de(y);
			return z * n0 + (y - z * BANDE_Z - oy) * L + (x - ox);
		}
		inline int px(int i) const { return ox + (i % n0) % L; }
		inline int py(int i) const { return oy + (i % n0) / L + (i / n0) * BANDE_Z; }
	};

private:
	// Les règles de déplacement (combat_rules.deplacement) et l'œil (visibilité.hauteur_oeil).
	int cout_base = 10, montee_1 = 15, montee_2 = 20, descente = 8, falaise_delta = 3, chute_delta = 3, neige_surcout = 1;
	double nage_ticks = 20.0, escalade_ticks_par_niveau = 14.0;
	int oeil = 1;
	std::vector<int32_t> table; // drapeaux par index de contenu

	// Tampons de travail réutilisés d'un appel à l'autre (pas d'allocation par chemin).
	std::vector<int32_t> g_cout, vient_de;
	std::vector<uint8_t> marque;

	bool charger(Object *grille, Etat &s) const;
	inline int drapeaux(const Etat &s, int i) const {
		int32_t ci = s.c[i];
		return (ci > 0 && ci < (int32_t)table.size()) ? table[ci] : 0;
	}
	int niveau_liquide(const Etat &s, int i) const;
	bool nageable(const Etat &s, int i) const;
	int cout_pas(const Etat &s, int de_i, int vx, int vy, bool volant, bool eviter_nage) const;
	inline int hauteur_vue(const Etat &s, int i) const {
		int fl = drapeaux(s, i);
		return (int)s.h[i] + ((fl & F_BLOQUE_VUE) ? ((fl >> 8) & 0xFF) : 0);
	}
	bool ligne_de_vue_e(const Etat &s, Vector2i a, Vector2i b, Vector2i *obstacle) const;
	void ombres_e(const Etat &s, const uint8_t *nv, Vector2 dir, double pente, Vector2i coin, Vector2i taille, int max_pas, int unites_par_niveau, uint8_t *out) const;

protected:
	static void _bind_methods();

public:
	void configurer(const Dictionary &dep, int p_oeil, const PackedInt32Array &p_table);
	inline int drapeaux_public(const Etat &s, int i) const { return drapeaux(s, i); }
	inline int niveau_liquide_public(const Etat &s, int i) const { return niveau_liquide(s, i); }
	Array chemin(Object *grille, Vector2i depart, Vector2i arrivee, bool volant, const String &ignorer, bool eviter_nage, int max_noeuds);
	Dictionary atteignables(Object *grille, Vector2i depart, int budget, bool volant, bool eviter_nage);
	bool ligne_de_vue(Object *grille, Vector2i a, Vector2i b);
	Vector2i premier_obstacle_vue(Object *grille, Vector2i a, Vector2i b);
	PackedInt32Array champ_de_vue(Object *grille, Vector2i pos, int portee);
	int cout_pas_entre(Object *grille, Vector2i de, Vector2i vers, bool volant, bool eviter_nage);
	PackedInt32Array composante(Object *grille, Vector2i depart, int max_tuiles);
	Dictionary regions_cellule(Object *grille, Vector2i origine, int n, const PackedInt32Array &classes);
	Dictionary morceau(Object *grille, Vector2i coin, int taille_morceau, const Dictionary &p);
	PackedByteArray visibles(Object *grille, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, Vector2i jp, int rayon, int bat_j, const PackedVector2Array &positions);
	Dictionary brouillard(Object *grille, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, Vector2i jp, int rayon, Vector2i origine_dessin,
			double tw, double th, double hstep, int niveau_u, int bat_j, int mur_coupe_u, Color voile, Color voile_jamais);
	Dictionary toits(Object *grille, const Dictionary &vue, bool tout_vu, int zj, int vide_ci, Vector2i jp, int rayon, Vector2i origine_dessin,
			double tw, double th, double hstep, int niveau_u, int bat_j, const PackedColorArray &bat_couleurs, const PackedFloat32Array &bat_styles,
			double pente_t, double haut_toit, double ombre_min, Vector2 soleil_h, bool soleil_ok, double soleil_force, double uv_haut, double sombre_jamais);
	PackedByteArray ombres(Object *grille, Vector2 dir, double pente, Vector2i coin, Vector2i taille, int max_pas, int unites_par_niveau);
	PackedByteArray propager_lumiere(Object *grille, const PackedInt32Array &sources_idx, const PackedByteArray &sources_niv, int ambiante,
			const PackedByteArray &bloque_par_contenu);
	PackedByteArray carte_lumiere(Object *grille, Color ciel, const PackedByteArray &locale, Color teinte_locale, double force_locale,
			Vector2 dir, double pente, int max_pas, int unites_par_niveau, double ombre_portee, Vector2i coin, Vector2i taille);
	Dictionary sol_cellule(int taille, bool bord, int pas, const PackedStringArray &bloc_sol, const PackedByteArray &bloc_mer, int mer_h, const PackedByteArray &hauteurs);
	Dictionary vegetation_cellule(Object *rng, int taille, int pas, const PackedInt32Array &sol_keys, const Dictionary &eau, Rect2i reserve,
			const PackedInt32Array &bloc_biome, const PackedFloat64Array &bloc_veg, const PackedFloat64Array &bloc_res, const PackedFloat64Array &bloc_danger,
			const Array &biomes, const PackedFloat64Array &seuils, double filons_seuil, double filons_densite, const Array &tiers);
};

} // namespace godot
