---
aliases: ["Trésors et artefacts", "Artefacts", "Trésors"]
tags: [monde, objets, loot, décidé]
domaine: monde
statut: décidé
etape: 3
---

Une catégorie d'objets à part : très rares, non craftables, non sculptables, trouvables uniquement en donjon.

**Trésors et artefacts :** catégorie d'objets à part — très rares, non craftables/non sculptables, trouvables uniquement en donjon. Générés aléatoirement (pas d'exemplaire unique par objet), mais avec un taux d'apparition très faible. Lien naturel avec la guilde Chasseurs de trésor ([[Quêtes et guildes]]).

**Décision :**
- **Trésors/artefacts :** mécaniquement = objets à **effets d'équipement ([[Effets d'équipement passifs]]) tirés des pools [[Effets d'équipement types]] avec un budget supérieur** (2-3 effets, valeurs au-dessus des fourchettes normales) + stats de base hors normes fixées à la génération ; jamais craftables ni sculptables.

**Dans la grille de rareté ([[Loot — affixes, gemmes et rareté]]) :**
```
· artefact : effets uniques hors pools, NI sertissable NI
    infusable (fini par nature).
```

**Placement :** réservés à la salle boss/trésor des **donjons majeurs** ([[Donjons — structure et intégration]], [[Génération de donjon]] : artefact garanti si donjon majeur).

> [!success] Codé le 2026-08-28
> Rareté **`artefact`** dans `loot_rules.raretes` : 2-3 affixes (les « très rares » autorisés), **budget 1** (toujours le meilleur tiers) et **dépassement ×1,25** de la fourchette dans le bon sens — « au-dessus des fourchettes normales » —, **aucune sertissure**, `fini: true` (ni sertir ni infuser), nom généré, prix ×10. Jamais tiré par la grille des étages : seulement à la mort du **boss** d'un donjon — **garanti si le donjon est majeur** (décision : `etages ≥ 4`, `loot_rules.drops.artefact.etages_majeur`), sinon une chance sur quatre. Les « effets uniques hors pools » attendent : ce sont pour l'instant les pools d'affixes poussés au-delà de leurs bornes.

> [!success] Codé le 2026-08-28 — trois effets uniques hors pools
> Gabarits `affixes/unique_*.json`, tag **`artefact_seulement`** : le générateur ne les tire que pour la rareté `artefact` (jamais sur un objet commun, même « très rare »). **Second souffle** (toute pièce) : une fois par combat, quand un coup laisse le porteur sous 20 % de PV, il regagne 30 % de ses PV max (réarmé à l'engagement). **Vol de mana** (arme) : chaque coup rend `pct` % des dégâts en mana. **Chaîne éternelle** (anneau, amulette) : la jauge de chaîne **ne décroît plus** entre deux coups. Décision : pas de fourchette poussée pour ces trois-là — l'effet *est* la rareté ; leur nombre reste petit (3 gabarits, 41 en tout) pour qu'un artefact se reconnaisse.

> [!note] Réglages — les effets uniques hors pools : `combat_rules.uniques` (`second_souffle_seuil_pct`, le seuil sous lequel Second souffle se déclenche, une fois par combat). Pointeur ajouté le 2026-09-04.

## Liens
- **Dépend de** : [[Carte du monde]], [[Donjons — structure et intégration]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Quêtes et guildes]]
- **Voir aussi** : [[Effets d'équipement passifs]], [[Effets d'équipement types]], [[Génération de donjon]], [[Monstres rares]]
