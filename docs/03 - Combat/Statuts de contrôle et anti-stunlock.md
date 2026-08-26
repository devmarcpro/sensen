---
aliases: ["Statuts de contrôle", "Anti-stunlock", "Contrôle dur"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

Les contrôles durs se mesurent en ticks, s'affichent, et ne peuvent jamais enchaîner.

**Statuts de contrôle** : étourdissement, enracinement, **saisie** et **retard de tempo** ([[Talents de classe]]) se mesurent **en ticks**, avec la durée affichée. *Le tempo compte dans ce budget : un compteur repoussé est un contrôle dur déguisé.* Aucun contrôle dur ne dépasse **20 ticks** sur le joueur, et ne peut se réappliquer dans les **50 ticks** suivant sa fin (anti-stunlock), **joueur comme créatures**.

**Catalogue des statuts complets :** voir [[Statuts]] (14 statuts en données, `data/status_effects/`).

**Application ([[Pipeline de résolution du combat]]) :** les statuts sont appliqués par tags des modules, tickés en phase 2 de la [[Boucle de tick]].

**Statuts et modificateurs :** les statuts passent par le résolveur unifié [[Résolveur de modificateurs]] — comme les potions ([[Nourriture, potentiel et potions]]) et les buffs de modules.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Boucle de tick]]
- **Alimente** : [[Statuts]], [[Familles de capacités de la grille]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Pipeline de résolution du combat]], [[Modules]], [[Nourriture, potentiel et potions]]
