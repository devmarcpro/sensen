---
aliases: ["A.4.2", "Annexe A.4.2", "Poids porté", "Capacité de poids", "Dés d'armure"]
tags: [objets, équipement, formule, décidé]
domaine: objets
statut: décidé
etape: 3
---

La formule de capacité de poids — et la formule historique de protection par dés, remplacée par la réduction plate.

```
protection : chaque pièce contribue des DÉS de réduction (mitigation à jet, E.3.4)
  des_piece = 1dX  avec  X = round(durete_BASE * qualite * facteur_slot / 4)
             (min 1d2 ; durete_BASE avant qualité, même règle qu'en A.4.1)
  Exemple : cuirasse fer (durete 25) qualité 1.2, facteur 1.0 → 1d8
facteur_slot : torse 1.0, tête 0.6, jambes 0.7, pieds 0.3, mains 0.3
malus_vitesse_deplacement = f(poids_total_porté / capacite)
    capacite = 30 + Force * 5 (inclut inventaire ET équipement)
```

- Optionnel (à activer si le combat en a besoin) : matrice type de dégâts × matériau d'armure via les tags (contondant efficace contre matériaux rigides, perçant contre souples).

> **Note de cohérence :** la **mitigation par dés** ci-dessus est **remplacée** par la réduction plate par zone de [[Armure par zone et constructions]] — voir [[Décisions fondatrices]] : *« Armure par zone → supprime la mitigation par dés, cause structurelle de l'écrasement des dégâts »*. Le `facteur_slot` reste utilisé par [[Fonctionnalité]] (champ des armures). La formule de **capacité de poids** (`30 + Force × 5`) reste pleinement en vigueur.

**Ce que la capacité de poids finance :**
- le **râtelier** du guerrier ([[Cinq accès au cycle]]) — la capacité de port finance l'arsenal ;
- le transport des **stations portatives** ([[Stations de transformation]] : forge 80, scierie 60, établi 35, autres 40-60) ;
- le choix cape **OU** sac au slot dos ([[Équipement — 14 slots]]).

**Règle de retrait ([[Effets d'équipement passifs]]) :** dépasser la capacité après retrait d'un objet applique simplement le malus de surcharge, rien n'est jeté.

**Surcharge dans l'eau ([[Eau et liquides]]) :** le poids porté tire vers le fond — surcharge = on coule, largage d'objets possible.

**Effets de loot ([[Effets d'équipement types]]) :** `capacite_poids +10..+40` ; affixe mécanique « +[10-30] capacité ».

> [!success] Codé le 2026-08-28 — capacité et surcharge (`combat_rules.poids`)
> `capacite = 30 + Force × 5`, sac et équipement compris. Poids d'un objet : son champ `poids` s'il existe, sinon `poids_reference` de sa fonctionnalité, le poids de sa station, et pour un matériau **densité / 4 par unité** (un lingot de fer 3, une planche de chêne 1,5) ; meuble 8, armure 6, autre 1 (décision — les notes ne pèsent pas les objets). **Décision sur `f`** (jamais définie) : sans malus jusqu'à la capacité, puis `ticks de déplacement × (1 + (ratio − 1) × 2)`, plafonné ×3 — appliqué sur les ticks issus d'Athlétisme, jamais sur une stat. Dépasser après un retrait n'éjecte rien. Affiché dans l'en-tête et l'inventaire ; les affixes `capacite_poids` viennent avec le loot.

> [!success] Codé le 2026-09-01 — la charge se voit enfin dans le HUD
> Le rapport du parcours du 2026-08-30 listait dans « ce qui manque » un **retour visuel du poids porté** : le robot est passé à **126 / 55 — surcharge ×3** sans que rien à l'écran ne le dise, la seule trace étant une ligne de texte. Le HUD gagne une **cinquième barre** sous la faim : la charge, remplie jusqu'à la capacité, **rouge et clignotante au-delà** (la barre reste pleine, le chiffre dit de combien on dépasse). Elle lit `poids_de`, donc la capacité tient déjà compte de la Force et des effets. C'est un affichage : aucune règle de surcharge ne change.


## Liens
- **Dépend de** : [[Stats de personnage]], [[Qualité d'artisanat]], [[Matériaux — 13 stats]]
- **Alimente** : [[Cinq accès au cycle]], [[Stations de transformation]], [[Équipement — 14 slots]], [[Eau et liquides]]
- **Voir aussi** : [[Armure par zone et constructions]], [[Fonctionnalité]], [[Pipeline de résolution du combat]], [[Effets d'équipement passifs]], [[Décisions fondatrices]]
