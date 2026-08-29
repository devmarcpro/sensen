---
aliases: ["F.6", "Annexe F.6", "Meubles", "16 meubles", "Mobilier"]
tags: [contenu, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 7
---

Les 16 meubles de départ — requis pour l'habitat et pour le graphe de POI du niveau logique.

*Tous sculptables (table meubles, [[Tables de sculpture]]) ou craftables via recettes simples ([[Fabrication d'outils]]) ; requis pour l'habitat ([[Habitat des PNJ]]) et les POI du graphe [[LOD de simulation]].*

Lit (dormir, assignation PNJ) · Lit de paille (idem, malus humeur −3) · Table · Chaise · Coffre (stockage 30 slots) · Grand coffre (60) · Garde-manger (stock nourriture PNJ, [[Faim des PNJ]]) · Étal de vente (boutique passive [[Commerce et boutiques]], 12 slots) · Torchère (luminosité 80, fixe) · Lanterne de cristal (luminosité 95) · Cheminée (chaleur : annule malus de froid dans la pièce) · Bibliothèque (stocke les livres, +5 % réussite de lecture à proximité) · Râtelier d'armes (stockage + déco) · Tapis (humeur +2 dans la pièce) · Trophée (tête de créature vaincue, humeur/prestige) · Autel domestique (résurrection [[Compagnons]] à domicile, coût ×1.5)

**Meilleure chambre ([[Habitat des PNJ]]) :** +1 humeur par **type de meuble distinct** dans la pièce (max +10), +5 si volume ≥ 27 blocs. Les meubles à bonus propres (tapis, trophée) s'ajoutent.

**Condition de pièce habitable ([[Détection de pièces]]) :** au moins **un meuble** (n'importe lequel) dans le volume clos.

**Cheminée et température ([[Météo]]) :** *annule le malus de froid dans la pièce* — l'une des sources de chaleur locales contre la température ressentie.

**Sommeil ([[Cycle jour-nuit et sommeil]]) :** lit requis pour dormir ; le vote de saut de nuit exige que tous soient dans un lit ou hors combat.

**Respawn ([[Mort et pénalité]]) :** au dernier **lit**/claim activé.

**Statue 1:1 ([[Créatures]]) :** drop rare universel — un meuble décoratif posable, généré automatiquement, recolorisé en pierre. Trophée de chasse ultime.

**Le râtelier ([[Cinq accès au cycle]]) :** le râtelier d'armes est l'ancrage matériel de la voie du guerrier vers le cycle Wu Xing.

> [!success] Précisé le 2026-08-28
> Sculpture abandonnée ([[Tables de sculpture]]) : les meubles viennent de recettes, pas d'un éditeur.

> [!success] Codé le 2026-08-28 — `data/meubles/` (les 16 + la statue), objets `meuble_<id>`, recettes à l'Établi
> Un meuble est un **contenu de tuile** (`meuble`, ou `meuble_sol` pour le tapis, franchissable) portant l'id de sa fiche — pas une entité (tranché : [[Grille continue]] fait foi sur [[Détection de pièces]]). Fiche : `type_meuble`, `bloque_passage`, `dormir`, `capacite_slots`, `luminosite`, `bonus_humeur`, `couleur`. Recettes plates à l'Établi en planches, pierre taillée, tissu, lingots, gemmes taillées (`data/recipes/meuble_*`) ; le trophée attend le dépeçage (recette provisoire en planches), la statue reste un drop. **Coffre** = un contenant de tuile de `capacite_slots` (30 / 60) : `ranger` (un objet du sac dans un coffre adjacent), `prendre` (tout le coffre), ou R dessus. **Lit** : `dormir` ([[Cycle jour-nuit et sommeil]]) et **point de respawn** ([[Mort et pénalité]]). Humeur, PNJ et garde-manger automatique attendent les PNJ (étape 9).

> [!success] Codé (vérifié le 2026-08-28)
> Les 16 meubles de la note sont dans `data/meubles/` (24 avec l'enclos, le rucher, le terrarium, le vivarium, la clayette, le bassin, le hall de guilde, l'autel domestique et la tourelle ajoutés aux étapes 9-10).

> [!success] Codé le 2026-08-29 — le trophée demande enfin une dépouille
> `recipes/meuble_trophee` : **2 planches + 1 peau** (entrée par objet, la peau vient de la dépouille d'une bête) au lieu de deux planches sèches — un trophée de chasse se gagne à la chasse. Le **tapis** demande de même **1 peau** en plus de son tissu.

## Liens
- **Dépend de** : [[Construction cadrée]], [[Tables de sculpture]], [[Fabrication d'outils]]
- **Alimente** : [[Habitat des PNJ]], [[Détection de pièces]], [[LOD de simulation]], [[Commerce et boutiques]], [[Boutique passive]]
- **Voir aussi** : [[Faim des PNJ]], [[Compagnons]], [[Cycle jour-nuit et sommeil]], [[Météo]], [[Grimoires et manuels]], [[Créatures]], [[Mort et pénalité]], [[Cinq accès au cycle]], [[Application des stats de matériau]]
