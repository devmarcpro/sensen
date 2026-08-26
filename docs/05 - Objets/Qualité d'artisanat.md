---
aliases: ["A.3", "Annexe A.3", "Qualité", "Paliers de qualité", "Qualité d'artisanat"]
tags: [objets, craft, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

La formule de qualité unique du jeu, ses 8 paliers nommés, et la règle « la compétence plafonne doucement, les bonus externes repoussent la limite ».

**La qualité (objets uniquement) :**
- La qualité ne s'applique qu'aux **objets** : armes, armures, accessoires, outils, meubles, etc. — qu'ils soient craftés par le joueur, obtenus en loot (drop), ou détenus par des PNJ (marchands).
- La qualité est un **multiplicateur** allant de 0 à théoriquement l'infini, avec une difficulté croissante pour monter chaque palier supplémentaire (rendements décroissants).
- Chaque palier de qualité porte un **nom** (ex : pauvre, médiocre, correct... jusqu'à des qualités exceptionnelles).
- Pour un objet crafté, la qualité dépend du niveau de la compétence d'artisanat associée du joueur.
- **Confirmé** ([[Stats d'un objet crafté]]) : la dureté de base vient des stats fixes des matériaux ; la qualité les multiplie ensuite, **une seule fois** — ne jamais réappliquer la qualité sur une dureté déjà multipliée ([[Stats d'armes]] : ce serait un double comptage).

**Formule (A.3) :**

```
qualite_produite = clamp_min(0.1,
    (N_artisanat / (N_artisanat + 25)) * 2 * random(0.85, 1.15))
```

- Asymptote : tend vers ×2.0 pour un artisan très expérimenté, mais `random` permet des pics au-dessus.
- Niveau 25 ≈ qualité ×1.0 en moyenne. Niveau 100 ≈ ×1.6.
- **Dépassement de l'asymptote** : des bonus additifs (station de meilleure qualité, outils spéciaux, buffs, matériaux exotiques) s'ajoutent après la formule — c'est comme ça que "0 → ∞ mais de plus en plus dur" se concrétise : la compétence seule plafonne doucement, les bonus externes repoussent la limite.

**Paliers nommés (par tranches de multiplicateur) :**

| Multiplicateur | Nom |
|---|---|
| 0.1 – 0.49 | Misérable |
| 0.5 – 0.79 | Pauvre |
| 0.8 – 1.19 | Correct |
| 1.2 – 1.59 | Bon |
| 1.6 – 1.99 | Excellent |
| 2.0 – 2.99 | Chef-d'œuvre |
| 3.0 – 4.99 | Légendaire |
| 5.0+ | Mythique |

**Décision (4.2) :** *Paliers de qualité : résolu* — 8 paliers nommés, Misérable → Mythique.

**Applications de la même formule :** qualité d'un composant (sur la compétence de sa station) et jet d'assemblage ([[Stats et qualité de l'assemblage]]) · qualité d'un plat (compétence Cuisine) et d'une potion (compétence Alchimie) ([[Cuisine et alchimie]], [[Nourriture, potentiel et potions]]) · qualité d'un objet sculpté (compétence de la table utilisée, [[Tables de sculpture]]) · qualité de taille d'une gemme ([[Loot — affixes, gemmes et rareté]]).

**Localisation :** les noms de paliers sont des textes générés — une clé par langue ([[Localisation]]).

## Liens
- **Dépend de** : [[Progression par l'usage]], [[Matériaux — 13 stats]]
- **Alimente** : [[Stats d'un objet crafté]], [[Stats et qualité de l'assemblage]], [[Stats d'armes]], [[Armures et poids porté]], [[Prix suggéré]], [[Loot — affixes, gemmes et rareté]]
- **Voir aussi** : [[Cuisine et alchimie]], [[Tables de sculpture]], [[Localisation]], [[Ouvert — Interprétation dureté et qualité]]
