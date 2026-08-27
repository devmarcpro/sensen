---
aliases: ["4.2", "4.2 Matériaux, récolte et artisanat", "4.2 stats", "C.5", "Annexe C.5", "13 stats", "Stats des matériaux", "Matériaux"]
tags: [objets, matériaux, décidé]
domaine: objets
statut: décidé
etape: 6
---

Chaque matériau porte 13 statistiques fixes. Le choix du matériau dans un craft est un arbitrage multidimensionnel, pas seulement dureté/poids.

**Catégories de matériaux :** chaque matériau appartient à une catégorie (bois, minerai, roche, liquide, synthétique, etc.). Voir [[Catégories de matériaux]].

**Stats par matériau :** chaque matériau possède ses propres statistiques individuelles fixes, indépendamment de sa catégorie. **13 stats** (effets détaillés en [[Application des stats de matériau]], schéma en [[Schéma matériau]]) :
- `durete` — dégâts, protection, récolte
- `densite` — poids, vitesse d'arme
- `valeur_base` — économie
- `conductivite_mana` — efficacité magique (réduction des coûts en mana)
- `flammabilite` — prend feu, vitesse de combustion
- `isolation` — protection chaleur/froid
- `conductivite_electrique` — sensibilité/propagation de la foudre
- `flottabilite` — flotte ou coule (crucial pour les véhicules navals)
- `luminosite` — émet de la lumière (éclairage, visibilité/discrétion)
- `fertilite` — rendement agricole du sol ([[Agriculture et élevage]])
- `transparence` — laisse passer la lumière/le regard (fenêtres, serres)
- `elasticite` — amortit les chutes, puissance des arcs
- `friction` — surfaces glissantes (glace) ou routes rapides (pavés)

Le choix du matériau dans un craft est donc un **arbitrage multidimensionnel**, pas seulement dureté/poids.

**Rappel C.5 :** les 13 stats sont `durete`, `densite`, `valeur_base`, `conductivite_mana`, `flammabilite`, `isolation`, `conductivite_electrique`, `flottabilite`, `luminosite`, `fertilite`, `transparence`, `elasticite`, `friction`. Tags dérivés par seuils ([[Schéma matériau]]) + tags manuels : `organique`, `corrompu`.

**Important :** les matériaux bruts n'ont **pas de "qualité"** — seulement leurs stats fixes. La récolte n'améliore jamais la qualité d'un matériau, seulement la vitesse/quantité obtenue ([[Récolte]]).

**Décision :** *Stats par matériau : résolu* — 13 stats, chiffrées pour les **153 matériaux** du catalogue ([[Catalogue matériaux — Bois]] et suivants).

**Vecteur Wu Xing dérivé de la catégorie :** voir [[Wu Xing hors combat]].

> [!success] Codé le 2026-08-28 — `data/materials/` (155 fichiers), `tools/gen_materials.py`
> Les **155 lignes des 11 tables de catalogue** (la table fait foi, pas l'en-tête) sont transcrites par `tools/gen_materials.py` : 13 stats, couleur de la palette (unique, vérifiée au boot), outil/compétence de la catégorie, surcharge `wuxing` de [[Décision — Surcharges Wu Xing des matériaux]] (44 matériaux), clés `material.<id>.name` dans `locale/fr.csv`. Les gabarits paramétriques (feuilles, pousses, parties de créatures) attendent leurs sources (arbres, dépeçage). L'id est le slug du nom sans parenthèse : `aluminium`, `chrome`, `guano`.

## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Application des stats de matériau]], [[Schéma matériau]], [[Stats d'un objet crafté]], [[Récolte]], [[Craft compositionnel]]
- **Voir aussi** : [[Catégories de matériaux]], [[Wu Xing hors combat]], [[Qualité d'artisanat]], [[Catalogue matériaux — Bois]]
