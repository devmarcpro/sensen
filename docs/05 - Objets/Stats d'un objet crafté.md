---
aliases: ["A.4", "Annexe A.4", "Stats d'un objet crafté", "Stats craft/sculpture"]
tags: [objets, craft, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : « comptage de voxels » corrigé en **comptage de pixels** — la formule de moyenne pondérée est inchangée.

La règle de base : moyenne pondérée des matériaux, puis qualité appliquée une seule fois.

```
stat_finale = stat_base_materiaux * qualite_produite

stat_base_materiaux (craft simple) = moyenne pondérée des stats des matériaux
    selon les quantités de la recette
stat_base_materiaux (sculpture)   = moyenne pondérée des stats des matériaux
    selon le nombre de pixels de chaque matériau dans le modèle
```

- La sculpture n'ajoute **aucun bonus de stats** (déjà décidé : la forme est cosmétique) ; elle donne juste un contrôle exact de la pondération via la composition en pixels ([[Tables de sculpture]]).

**Décision (4.2) :** *Formule dureté/qualité : résolu* — dureté de base = moyenne pondérée des matériaux, **qualité appliquée une seule fois**.

**Garde-fou anti-double-comptage ([[Stats d'armes]]) :** `durete_BASE` = moyenne pondérée des matériaux **AVANT** qualité. La qualité n'est appliquée qu'**UNE** fois ; ne jamais utiliser la dureté finale déjà multipliée.

**Les 13 stats ne sont pas multipliées par la qualité ([[Application des stats de matériau]]) :** ce sont des propriétés physiques, pas des performances — seule la dureté → dégâts/protection passe par la qualité.

**Craft compositionnel :** pour les objets assemblés depuis des composants, la formule est remplacée par celle de [[Stats et qualité de l'assemblage]] (somme pondérée par poids de slot).

> [!success] Précisé le 2026-08-28
> Sculpture abandonnée ([[Tables de sculpture]]) : la pondération par nombre de pixels n'existe plus ; seules restent la moyenne pondérée des quantités de recette (craft simple) et les poids de slots (craft compositionnel).

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Qualité d'artisanat]]
- **Alimente** : [[Stats d'armes]], [[Armures et poids porté]], [[Stats et qualité de l'assemblage]], [[Tables de sculpture]]
- **Voir aussi** : [[Application des stats de matériau]], [[Éditeur de sculpture]], [[Schéma objet et recette]]
