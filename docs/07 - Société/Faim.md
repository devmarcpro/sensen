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

*(La photosynthèse du Sylvide est retirée avec cette race — [[Races]]. Aucune race ne modifie plus la vitesse de faim ; seuls les effets d'équipement le font.)*

**Effet d'équipement ([[Effets d'équipement types]]) :** `faim_vitesse ×0.7..0.9`.

**PNJ :** même jauge, mais auto-nourris — voir [[Faim des PNJ]].

**Tick ([[Boucle de tick]]) :** la faim est tickée en phase 2 de la boucle de tick, jamais par delta de frame.

**Tooltip contextuel ([[Tooltips contextuels]]) :** *faim < 60 la première fois → manger*.

> [!success] Codé le 2026-08-28 — `combat_rules.faim`, `Simulation._tiquer_faim`
> La jauge telle quelle : 0-100, départ 100, **−1 par 900 ticks** (90 s à 10 ticks/s d'exploration), tickée en phase 2 sur l'horloge du monde, jamais par delta d'image. Seuils : `< 50` régénération de santé −10 % (il n'y a pas encore de régénération de santé hors sommeil : l'effet est en données, sans prise), `< 25` **−10 % à toutes les stats** (appliqué dans `Etres.recalculer`, donc aussi aux maxima dérivés), `= 0` −1 % de santé max par 300 ticks, jamais sous 1 PV. `faim_vitesse` d'équipement : le multiplicateur est lu sur `e.faim_vitesse` (les affixes qui le posent viennent avec le loot). Manger : intention `manger`, valeur nutritive en données.

> [!success] Codé le 2026-08-31 — les trois paliers ont une prise, le conseil arrive à 60
> La régénération de santé hors sommeil existe désormais (effets d'équipement `regen_sante`) : sous `seuil_regen` (50) elle est × `malus_regen` (0,9), sous `seuil_stats` (25) elle s'arrête ; le malus de stats reste. Le conseil « manger » (`journal.faim_conseil`, tutoriel `premiere_faim`) part la première fois sous `tooltip_seuil` (60), avant le malus — il attendait le seuil 25.

> [!success] Décidé le 2026-09-01 — la faim tue (designer, point 52)
> « Une jauge qui ne tue jamais » n'était plus tenable : dans l'esprit de *Rogue*, la nourriture est **l'horloge qui pousse à avancer**. À jauge vide, la famine ronge les PV par paliers — `faim.degats_par_palier` PV tous les `faim.ticks_par_palier` ticks — jusqu'à la mort. Rien ne change pour les PNJ, qui gardent leur pénalité d'humeur : c'est le joueur qui reprend un compte à rebours.

## Liens
- **Dépend de** : [[Agriculture et élevage]], [[Boucle de tick]]
- **Alimente** : [[Cuisine et alchimie]], [[Nourriture, potentiel et potions]], [[Faim des PNJ]]
- **Voir aussi** : [[Nourriture]], [[Races]], [[Effets d'équipement types]], [[Tooltips contextuels]], [[Simulation du monde — performance]]
