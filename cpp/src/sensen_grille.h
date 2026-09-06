// SensenGrille — le noyau pur de calcul de la grille (Modules de la simulation et le C++, section 3, 2026-09-06).
// Aucune règle de jeu n'y vit : les paramètres viennent de combat_rules.json (configurer), l'état reste dans la
// Grille GDScript, lue au moment de l'appel (Object::get sur ses tableaux compacts). Chaque fonction est la
// transcription littérale de son originale de grille.gd — même ordre de parcours, même tas, mêmes arrondis —
// pour rendre exactement le même résultat (test_noyau_cpp le vérifie).
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
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
	};

	// La vue d'une grille le temps d'un appel : des pointeurs sur ses tableaux (les références tiennent les tampons).
	struct Etat {
		int L = 0, H = 0, ox = 0, oy = 0;
		PackedByteArray hauteurs, occ, dangers, eau;
		PackedInt32Array contenu;
		PackedFloat64Array frottement;
		const uint8_t *h = nullptr, *o = nullptr, *d = nullptr, *e = nullptr;
		const int32_t *c = nullptr;
		const double *f = nullptr;
		bool neige = false, gel = false;
		Dictionary occupants;

		inline bool dans(int x, int y) const { return x >= ox && y >= oy && x < ox + L && y < oy + H; }
		inline int idx(int x, int y) const { return (y - oy) * L + (x - ox); }
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

protected:
	static void _bind_methods();

public:
	void configurer(const Dictionary &dep, int p_oeil, const PackedInt32Array &p_table);
	Array chemin(Object *grille, Vector2i depart, Vector2i arrivee, bool volant, const String &ignorer, bool eviter_nage, int max_noeuds);
	Dictionary atteignables(Object *grille, Vector2i depart, int budget, bool volant, bool eviter_nage);
	bool ligne_de_vue(Object *grille, Vector2i a, Vector2i b);
	Vector2i premier_obstacle_vue(Object *grille, Vector2i a, Vector2i b);
	PackedInt32Array champ_de_vue(Object *grille, Vector2i pos, int portee);
	int cout_pas_entre(Object *grille, Vector2i de, Vector2i vers, bool volant, bool eviter_nage);
	PackedInt32Array composante(Object *grille, Vector2i depart, int max_tuiles);
};

} // namespace godot
