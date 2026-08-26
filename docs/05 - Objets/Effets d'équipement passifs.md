---
aliases: ["A.4.4", "Annexe A.4.4", "Effets d'équipement", "Effets passifs", "grant_tag", "Règle de retrait"]
tags: [objets, équipement, données, décidé]
domaine: objets
statut: décidé
etape: 3
---

Les quatre cibles possibles d'un effet passif d'équipement — dont le tag comportemental, le mécanisme le plus puissant : zéro code par objet.

Un objet porté peut avoir une liste d'**effets passifs** (champ `effects`, schéma [[Schéma objet et recette]]), appliqués tant qu'il est équipé. Chaque effet est un modificateur data-driven ciblant :

1. **Stat** : `{"target": "stat", "id": "perception", "add": 2}` (ou `"mult"`)
2. **Compétence** : `{"target": "skill", "id": "meditation", "add": 5}` — niveaux **effectifs** : comptent dans `skill_factor()` et dans toutes les formules (y compris les capacités maximales : mana_max, santé max, capacité de poids), mais ne génèrent pas d'XP et n'entrent PAS dans les niveaux dérivés ([[Double niveau combat et général]]).

**Règle de retrait (jauges maximales) :** quand retirer un objet fait baisser un maximum (santé max, mana max...), la valeur **courante** est clampée au nouveau max, avec un **plancher de 1** pour la santé (retirer un anneau de +PV alors qu'on a moins de PV que le bonus laisse à 1 PV, jamais 0 — on ne meurt pas en se déshabillant). Pour la capacité de poids : dépasser la capacité après retrait applique simplement le malus de surcharge ([[Armures et poids porté]]), rien n'est jeté.

3. **Mécanique** : `{"target": "mechanic", "id": "faim_vitesse", "mult": 0.8}` — ids de mécaniques exposés par les systèmes (`capacite_poids`, `surchauffe_mult`, `vitesse_deplacement`...)
4. **Tag comportemental** : `{"target": "grant_tag", "id": "detection_filons"}` — le porteur gagne un tag auquel les autres systèmes réagissent (mécanisme le plus puissant, zéro code par objet)

**Règles :** les `add` s'additionnent, les `mult` se multiplient entre tous les objets portés ; la **qualité** de l'objet multiplie les valeurs numériques (`add × qualité`, arrondi). Les objets craftés simples n'ont **pas** d'effets par défaut — les effets apparaissent sur le loot généré (donjons, marchands).

**Extension future — Enchantement :** la Table d'enchantement ([[Stations de transformation]]) permettra d'ajouter des effets à un objet existant. Non spécifié pour l'instant ; le champ `effects` est conçu pour l'accueillir sans refonte (l'enchantement = ajouter des entrées à la liste, avec coût en matériaux `conducteur_mana` et compétence Enchantement).

**Pools de génération :** [[Effets d'équipement types]].

**Résolution :** tous ces effets passent par le résolveur unique [[Résolveur de modificateurs]].

## Liens
- **Dépend de** : [[Schéma objet et recette]], [[Qualité d'artisanat]], [[Data-driven design]]
- **Alimente** : [[Effets d'équipement types]], [[Loot — affixes, gemmes et rareté]], [[Trésors et artefacts]], [[Monstres rares]], [[Mana]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Double niveau combat et général]], [[Armures et poids porté]], [[Stations de transformation]], [[Cinq accès au cycle]]
