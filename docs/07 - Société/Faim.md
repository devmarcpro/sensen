---
aliases: ["A.9", "Annexe A.9", "Faim", "Nutrition"]
tags: [société, survie, formule, décidé]
domaine: société
statut: décidé
etape: 7
---

La jauge de faim : une mécanique de survie active, mais qui ne tue jamais.

```
Jauge 0–100, départ 100. Baisse de 1 point / 90 s de jeu actif
(pauses et menus exclus). Effets :
  < 50 : -10 % régénération de santé
  < 25 : -10 % à toutes les stats, plus de régén de santé
  = 0  : perte de 1 % de santé max / 30 s (ne tue pas en dessous de 1 PV)
Manger restaure selon l'aliment (valeur nutritive en données).
```

**La nutrition est le multiplicateur ([[Cuisine et alchimie]]) :** la valeur de nutrition d'un plat remplit la faim **et** multiplie les bonus de potentiel — bien manger n'est pas de la survie, c'est de l'optimisation de croissance.

**Race Sylvide ([[Races]]) :** Photosynthèse — faim ralentie de moitié le jour.

**Effet d'équipement ([[Effets d'équipement types]]) :** `faim_vitesse ×0.7..0.9`.

**PNJ :** même jauge, mais auto-nourris — voir [[Faim des PNJ]].

**Tick ([[Boucle de tick]]) :** la faim est tickée en phase 2 de la boucle de tick, jamais par delta de frame.

**Tooltip contextuel ([[Tooltips contextuels]]) :** *faim < 60 la première fois → manger*.

## Liens
- **Dépend de** : [[Agriculture et élevage]], [[Boucle de tick]]
- **Alimente** : [[Cuisine et alchimie]], [[Nourriture, potentiel et potions]], [[Faim des PNJ]]
- **Voir aussi** : [[Nourriture]], [[Races]], [[Effets d'équipement types]], [[Tooltips contextuels]], [[Simulation du monde — performance]]
