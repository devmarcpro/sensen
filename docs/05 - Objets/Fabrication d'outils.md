---
aliases: ["Fabrication d'outils", "Craft simple", "Recette plate"]
tags: [objets, craft, décidé]
domaine: objets
statut: décidé
etape: 6
---

La voie de base du craft : une recette qui demande des catégories de matériaux, pas des matériaux précis.

**Fabrication d'outils (4.2) :**
- Un outil peut être fabriqué avec **n'importe quel matériau**, tant que les matériaux utilisés correspondent aux **catégories** requises par la recette (ex : une pioche demande "du bois" — n'importe lequel — et "du minerai" — n'importe lequel).
- Ce craft simple par recette est la **voie de base**, disponible pour tous types d'objets (outils compris) sans passer par une table de sculpture.

**Ce qui reste de la recette plate ([[Stations de transformation]]) :** *les objets finaux s'assemblent désormais depuis des composants ([[Craft compositionnel]]) — les recettes plates ne subsistent que pour les **transformations de matériaux** et les **consommables**.*

**Format de données :** [[Schéma objet et recette]] (bloc `recipe` avec `station`, `craft_skill`, `inputs` par catégorie).

**Trois voies de fabrication au total :**
1. **Craft simple par recette** (cette note) — transformations et consommables ;
2. **Craft compositionnel** ([[Craft compositionnel]]) — armes, outils, armures, véhicules ;
3. **Sculpture** ([[Tables de sculpture]]) — option de personnalisation, jamais obligatoire.

**Objets craftés simples et effets ([[Effets d'équipement passifs]]) :** les objets craftés simples n'ont **pas** d'effets par défaut — les effets apparaissent sur le loot généré.

> [!success] Codé à l'étape 6 — trace ajoutée le 2026-09-04
> Les outils sont des objets assemblés comme les armes (`items/outil/`, tête d'outil `tete_outil` à matériau libre + manche) ; la pioche, la pelle, la faucille, le seau existent et leurs verbes sont dans `combat_rules.outils_verbes`.

## Liens
- **Dépend de** : [[Catégories de matériaux]], [[Qualité d'artisanat]], [[Stations de transformation]]
- **Alimente** : [[Schéma objet et recette]], [[Stats d'un objet crafté]]
- **Voir aussi** : [[Craft compositionnel]], [[Tables de sculpture]], [[Effets d'équipement passifs]], [[Récolte]]
