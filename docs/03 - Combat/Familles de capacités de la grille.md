---
aliases: ["Familles de capacités", "Capacités positionnelles", "Familles de capacités que la grille rend possibles"]
tags: [combat, build, décidé]
domaine: combat
statut: décidé
etape: 0
---

Ce que le temps réel ne permettait pas de concevoir proprement, et qui devient évident sur une grille — tout est de la donnée, aucun coût de production supplémentaire.

- **Placement** : téléportation, échange de position avec un allié (le sortir d'un encerclement), bond par-dessus un obstacle, **portails appairés** (deux tuiles reliées qui modifient la topologie de la carte : les distances changent, les lignes de vue changent, toute la valeur est dans l'anticipation). C'est le talent de classe du **Passeur** ([[Talents de classe]]), qui les porte en permanence.
- **Contrôle et blocage** : poussée et attraction (sortir un ennemi de sa garde frontale, le pousser dans le vide — les chutes font des dégâts), **murs invoqués** (des tuiles surélevées temporaires qui bloquent le passage et la ligne de vue), zones de ralentissement, enracinement.
- **Invocations** : une créature invoquée **occupe une tuile** — elle est donc un mur, un bloqueur de vue et une menace de flanc autant qu'un allié. Raccord direct avec les compagnons ([[Compagnons]]) et les [[Armes fantomatiques]].
- **Glyphes et pièges** : effets persistants posés sur une tuile, déclenchés à l'entrée. Un glyphe élémentaire **pose un segment de chaîne** en se déclenchant : le Wu Xing devient positionnel ([[Jauge de chaîne Wu Xing]]).
- **Modelage du terrain** : élever ou abaisser des tuiles comme un sort — creuser une tranchée, ériger un talus, ouvrir une brèche dans un mur ([[Destruction du terrain]]).

**Rappel des dégâts de chute ([[Hauteur de terrain ±10]]) :** `−3 et plus → chute autorisée, dégâts = (hauteur − 2) × 5`. C'est ce qui rend la poussée dans le vide réellement létale.

> [!success] Codé — trace ajoutée le 2026-09-04
> Les familles décrites ici (projectiles, lignes, cônes, zones au sol, déplacements, invocations) sont toutes des combinaisons de formes, portées et noyaux du catalogue ; `test_modules.tscn` assemble et exécute chaque forme avec chaque noyau — dix mille plans, aucun refus. La note reste la lecture « par famille » du même vocabulaire.

## Liens
- **Dépend de** : [[Six types de modules et assemblage]], [[Vocabulaire des modules — six axes]], [[Hauteur de terrain ±10]]
- **Alimente** : [[Modules]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Garde en posture]], [[Jauge de chaîne Wu Xing]], [[Compagnons]], [[Armes fantomatiques]], [[Destruction du terrain]], [[Le vocabulaire des modules et l'absence d'arbre de talents]]
