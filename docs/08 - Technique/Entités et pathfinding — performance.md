---
aliases: ["G.5", "Annexe G.5", "Entités performance", "Pathfinding performance", "Recolorisation par instance"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 9
---

Budgets d'entités, d'IA et de pathfinding — et le rendu par meshes partagés qui rend 100 villageois gratuits.

```
Budgets (E.14) : ~64 entités niveau 1 (plein). Au-delà du budget dans
une zone : les spawns s'arrêtent (pas de despawn brutal).
IA : décisions échelonnées (E.16) — jamais plus de ~6 décisions
utility/tick. Perception : requêtes spatiales via grille de hachage
(cellules 8 blocs), pas de distance N² entre entités.
Pathfinding : file globale, 2 requêtes A* résolues/tick max, résultats
cachés et partagés (deux gardes vers le même point réutilisent le
chemin). Nav-grille par chunk reconstruite PARESSEUSEMENT (au premier
besoin après invalidation), en thread.
Rendu des créatures : les parties de sprites (12) sont des ressources
PARTAGÉES (bibliothèque = ressources uniques) ; recolorisation par
palette en shader (paramètre d'instance), pas de duplication —
100 villageois = ~6 jeux de parties distincts en mémoire. Animations simples
par transform de parties (pivots 12.1), pas de skinning.
```

**Réutilisé sans coût par les monstres rares ([[Monstres rares]]) :** la teinte distincte (or/argent/prismatique) passe par le **paramètre de recolorisation par instance déjà en place** — zéro nouveau système de rendu.

**Réutilisé par le drop de statue 1:1 ([[Créatures]]) :** le modèle assemblé exact de la créature, **recolorisé en pierre** via le remapping de palette existant — zéro asset à produire.

**Coût du niveau logique ([[LOD de simulation]]) :** ~100 PNJ logiques ≈ le coût de 3 PNJ pleins.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[IA des créatures]], [[Budgets de performance]]
- **Alimente** : [[Monstres rares]], [[LOD de simulation]], [[Créatures]]
- **Voir aussi** : [[Squelette modulaire et points d'attache]], [[Palette de couleurs des matériaux]], [[Ordre de vérification]], [[Direction artistique]]
