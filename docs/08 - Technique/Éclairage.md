---
aliases: ["G.3", "Annexe G.3", "Éclairage", "Lumière", "Transparence rendu"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

Propagation incrémentale de la lumière, et un cycle jour/nuit qui ne coûte rien.

```
Propagation 0-15 par flood fill INCRÉMENTAL : les mises à jour de
lumière sont des deltas locaux (pose/destruction de bloc ou de source),
jamais un recalcul de chunk complet ; file dédiée, budget par tick,
en thread avec le meshing (la lumière est cuite dans les vertex).
Lumière du jour : colonne skylight précalculée à la génération,
propagée pareil. Le cycle jour/nuit (E.21) module en SHADER (uniform
global), pas en re-propagation — changer l'heure ne coûte rien.
Transparence : passe séparée, triée par chunk seulement (pas par face).
```

**Échelle de lumière ([[Application des stats de matériau]]) :** `niveau = luminosite / 100 × 15` (échelle 0-15). Un objet lumineux porté éclaire mais **augmente la détection par les ennemis** — malus de Discrétion.

**Simplification par la direction tactique ([[Risques majeurs]]) :** propagation en **2D sur la grille** (bien plus simple qu'en volume), utilisée pour la visibilité nocturne, les donjons et l'ambiance. La transparence devient un simple tri de rendu.

**Détection modulée par la lumière ([[IA des créatures]]) :** le cône de vision est modulé par la lumière locale.

**Enjeu de construction ([[Cycle jour-nuit et sommeil]]) :** la nuit, seules les sources locales comptent — l'éclairage de la base devient un vrai enjeu.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Voxels — mémoire et meshing]], [[Application des stats de matériau]]
- **Alimente** : [[Cycle jour-nuit et sommeil]], [[IA des créatures]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Meubles]], [[Risques majeurs]], [[Direction artistique]], [[Budgets de performance]]
