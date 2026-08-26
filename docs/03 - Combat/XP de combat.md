---
aliases: ["5.3", "5.3 XP de combat", "XP de combat", "XP = dégâts appliqués"]
tags: [combat, progression, décidé]
domaine: combat
statut: décidé
etape: 4
---

L'XP vaut les dégâts appliqués, versée à trois pistes simultanées — et l'armure gagne ce qu'elle épargne.

`xp = dégâts réellement appliqués` (après armure, après le minimum de 1), **plafonnés aux PV restants** de la cible (un coup à 400 sur une cible à 30 PV rapporte 30 — anti-overkill).

Versée **en entier à trois pistes simultanées** :
1. l'**élément** du coup (le même dominant qui a rempli le segment de chaîne) ;
2. la **compétence d'arme** (ou le domaine de magie pour un module) ;
3. la **maîtrise de type de dégâts** (tranchant / perforant / contondant).

Le multiplicateur de **potentiel** ([[Potentiel]]) s'applique ensuite, **par piste**.

**Côté défense, symétrie exacte** : l'armure gagne ce qu'elle **épargne** — `dégâts évités` versés à la **compétence de construction** de la pièce touchée (Matelassé, Cuir, Mailles, Écailles, Plaque). Une zone nue ne rapporte rien, et la compétence de construction augmente en retour la réduction de la pièce ([[Armure par zone et constructions]]).

**Boucle vertueuse assumée** : finir ses chaînes avec son élément phare y verse une XP gonflée par le multiplicateur — le joueur *choisit* sa spécialisation par sa façon de jouer. Le **potentiel régule seul** l'emballement (l'élément le plus monté épuise son potentiel et ralentit, les éléments frais gardent le leur) : aucune règle anti-farm n'est nécessaire.

Parité totale avec les PNJ et compagnons qui progressent ([[Compagnons]]).

**Multi-cibles ([[Trous connus du combat]]) :** la jauge se remplit d'un segment par attaque, **l'XP, elle, se somme par cible**.

> [!success] Codé le 2026-08-26 — dans le prototype
> Chaque être porte `xp: {element, competence, type, construction}`. À chaque dégât appliqué : `min(dégâts, PV restants)` versé à l'élément dominant du coup, à la compétence (`combat_skill` de l'arme ; pour un noyau magique, `magie_<élément>` en attendant le mappage des domaines de [[Domaines de grimoires et manuels]] ; pour une action de créature, son id) et au type de dégâts ; la cible verse `dégâts évités` (bruts × zone − finaux) à la construction de la pièce touchée. L'**écran de fin** (client) affiche l'issue, la durée du combat en ticks (le critère « 60 à 200 ticks » se lit directement) et les quatre pistes, puis les remet à zéro : non persistée, comme prévu par la spec.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Jauge de chaîne Wu Xing]], [[Potentiel]], [[Progression par l'usage]]
- **Alimente** : [[Armure par zone et constructions]], [[Double niveau combat et général]], [[Domination et multiplicateurs]]
- **Voir aussi** : [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Compagnons]], [[Trous connus du combat]], [[Pipeline de résolution du combat]], [[Décision — Multi-ennemis et jauge]]
