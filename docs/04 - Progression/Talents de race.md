---
aliases: ["Talents de race", "Talent de race", "Races cachées", "Vampire", "Spectre"]
tags: [progression, êtres, décidé]
domaine: progression
statut: décidé
etape: 4
---

> [!success] Décidé le 2026-08-26
> Amende la ligne du GDD *« la race donne des bonus de stats »* : chaque race porte désormais **un talent qui change la façon de jouer**.

Un talent de race est **passif et subi** : un état du corps, avec sa contrepartie. On ne l'active pas, on vit avec.

## La règle de conception

**Chaque talent a une contrepartie proportionnelle.** Plus il change le jeu, plus il coûte. Et **jamais d'immunité binaire** : les multiplicateurs défensifs ont été compressés exprès pour qu'*« un mauvais matchup soit un désagrément, jamais un mur »* ([[Domination et multiplicateurs]]). Une résistance ×0.3 donne le même fantasme sans casser le combat.

**Aucun talent n'ajoute de machinerie.** Tous s'expriment avec le [[Résolveur de modificateurs]] et les `grant_tag` des [[Effets d'équipement passifs]].

## Les trois races visibles

| Race | Talent | Contrepartie |
|---|---|---|
| **Humain — Polyvalent** | porte **deux talents de classe** au lieu d'un ([[Talents de classe]]) | aucun talent propre : sa force est de porter celle des autres |
| **Elfe — Chair de mana** | la **surchauffe** ([[Mana]] : lancer sans mana suffisant) coûte de l'**endurance** au lieu de la santé ; +20 % de régén de mana | endurance basse en permanence (−20 max) : il ne tient pas la durée en mêlée |
| **Nain — Œil de la pierre** | `detection_filons` permanent ; **ignore la règle d'irrécoltabilité** ([[Récolte]]) — peut extraire n'importe quel matériau, très lentement | vitesse de récolte ÷ 3 sur les matériaux au-dessus de son seuil normal ; −20 % de portée de vision (yeux de sous-sol) |

L'Elfe joue le mage imprudent qui peut brûler sa barre de sorts sans mourir. Le Nain court-circuite la progression matérielle — au prix du temps. L'Humain ne fait rien de particulier, sauf tout.

## Les races cachées

**Ce ne sont pas des choix de création : on le devient.** Une transformation réécrit le champ `race` — le type de locus `acquis` de l'Annexe H ([[Loci — les dix types]]) est exactement fait pour ça (*« non hérité, fixé après la naissance »*).

| Race | Talent | Contrepartie | Comment on le devient |
|---|---|---|---|
| **Vampire** | vision nocturne ; **+3 à toutes les stats la nuit** ; se nourrit de sang (une morsure remplit la jauge entière) | **brûle au jour** (1 % PV max / 10 ticks à la lumière directe — [[Cycle jour-nuit et sommeil]]) ; **ne peut plus manger de plats cuisinés**, donc perd toute la boucle potentiel/cuisine ([[Cuisine et alchimie]]) | mordu par un vampire, ou boire à une source maudite en donjon |
| **Spectre** | dégâts physiques **×0.3** ; traverse un mur d'une tuile d'épaisseur | ne porte **aucune armure** ; capacité de poids **5** ; ne se soigne que par mana ou domaine Vie ; les PNJ fuient à vue (réputation par race effondrée) | mourir dans un lieu de forte corruption sans être ressuscité à temps |
| **Lycanthrope** | transformation volontaire : stats **×1.5**, actions de créature ([[Actions des créatures]]) | sous forme bestiale : **plus d'armes, plus de modules, plus de dialogue** ; transformation **forcée** une nuit sur trente | mordu, ou rituel |
| **Toute espèce du bestiaire** | ses stats, sa morphologie, ses actions ([[Créatures]], [[Catalogue des groupes d'élevage]]) | ses `equip_slots` réduits ([[Équipement — 14 slots]]) : un quadrupède n'a pas de mains, donc pas d'armes ; pas de lecture, donc pas de modules ([[Lecture des livres]]) | **en prendre le contrôle** — voir ci-dessous |

## Jouer une bête : on ne la choisit pas, on l'élève

**Jouer un mouton, c'est prendre le contrôle d'un compagnon qu'on possède** ([[Ouvert — Changer de personnage]]). L'accès n'est pas un menu, c'est un parcours — et il est déjà entièrement décrit par [[Blocs de l'être]] :

> des dizaines de générations pour monter Force, Endurance et Intelligence · une lignée nourrie et logée · des bardes forgées · des heures de combat · du Leadership · des modules lus et sertis.

Le mouton jouable **est** le mouton ultime. Et ses limitations sont le contenu : pas de mains, pas de lecture, un monde qui ne te parle pas. Comme le Spectre, c'est un défi, pas une blague.

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Races]], [[Blocs de l'être]]
- **Alimente** : [[Talents de classe]], [[Ouvert — Changer de personnage]], [[Schéma créature]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Cycle jour-nuit et sommeil]], [[Mana]], [[Récolte]], [[Créatures]], [[Loci — les dix types]], [[Réputation et relations]]
