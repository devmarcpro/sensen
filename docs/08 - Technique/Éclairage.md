---
aliases: ["G.3", "Annexe G.3", "Éclairage", "Lumière", "Transparence rendu"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Réécrit en propagation **2D sur la grille** ([[Risques majeurs]]). Le flood fill 3D d'origine est archivé (GDD source, historique git).

Propagation incrémentale de la lumière en 2D sur la grille, et un cycle jour/nuit qui ne coûte rien.

```
Propagation 0-15 par flood fill 2D INCRÉMENTAL sur les tuiles : les mises
à jour de lumière sont des deltas locaux (pose/destruction d'une tuile ou
d'une source), jamais un recalcul de chunk complet ; file dédiée, budget
par tick, en thread. Les murs (contenu de tuile) bloquent la propagation ;
la transparence (A.4.5 : transparence >= 50) la laisse passer.
Lumière du jour : les tuiles de surface sont éclairées par l'ambiante ;
les intérieurs (pièces détectées, E.5) et les donjons ne reçoivent que
les sources locales. Le cycle jour/nuit (E.21) module en SHADER (uniform
global), pas en re-propagation — changer l'heure ne coûte rien.
```

**Usages ([[Risques majeurs]]) :** visibilité nocturne, donjons, ambiance. La transparence devient un simple tri de rendu.

**Échelle de lumière ([[Application des stats de matériau]]) :** `niveau = luminosite / 100 × 15` (échelle 0-15). Un objet lumineux porté éclaire mais **augmente la détection par les ennemis** — malus de Discrétion.

**Détection modulée par la lumière ([[IA des créatures]]) :** le cône de vision est modulé par la lumière locale.

**Enjeu de construction ([[Cycle jour-nuit et sommeil]]) :** la nuit, seules les sources locales comptent — l'éclairage de la base devient un vrai enjeu.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Application des stats de matériau]], [[Risques majeurs]]
- **Alimente** : [[Cycle jour-nuit et sommeil]], [[IA des créatures]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Meubles]], [[Direction artistique]], [[Budgets de performance]], [[Détection de pièces]]
