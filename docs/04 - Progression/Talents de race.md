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
| **Humain — Polyvalent** | porte **deux talents de classe** au lieu d'un ([[Talents de classe]]) — le seul qui peut être *Le Sabre* **et** *Le Passeur* | aucun talent propre : sa force est de porter celle des autres |
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

## Deux cas limites, tranchés

- **Polyvalent sur Le Vent.** *Sans maître* ne donne aucun talent au départ : le champ `talents.classe` d'un **Le Vent** est donc `null`, pas *« Sans maître »*. Un **humain Le Vent** n'a donc pas deux talents — il peut en **apprendre deux au lieu d'un**, et en changer. C'est le seul empilement des deux talents, et il est cohérent : le polyvalent du polyvalent.
- **Polyvalent et classe cachée.** Le second talent d'un humain est tiré dans les **classes visibles** uniquement. Une classe cachée s'apprend d'un porteur ([[Talents de classe]]) et occupe le slot principal — elle ne se distribue jamais gratuitement par la race.

> [!success] Codé le 2026-08-28 — les trois visibles
> **Polyvalent** (Humain : peut apprendre un second talent de classe auprès d'un PNJ, comme Le Vent, sans perdre le sien), **Chair de mana** (Elfe : la surchauffe coûte de l'endurance au lieu de la santé, régénération de mana ×1,2, endurance max −20), **Œil de la pierre** (Nain : la règle d'irrécoltabilité ne s'applique plus — vitesse ÷ 3 sur ce qui dépassait son seuil —, vision −20 %, tag `detection_filons`). Les races cachées attendent.

> [!success] Codé le 2026-08-28 — le Vampire, première race cachée
> `races/vampire.json` (tag `cache`, hors création) et le talent **Soif de sang**. **Devenir** : un être `humanoide` **mordu** porte le statut *Morsure* (un jour) ; **à l'aube suivante**, s'il vit encore, il devient vampire (`race_origine` conservé, `race = vampire`, tag acquis `vision_nocturne`, journal) — joueur compris, aucun cas particulier ; la source maudite attend un meuble de donjon. **La nuit** : statut *Sang de la nuit* (**+3 aux six stats**), posé et rafraîchi à chaque pas, retiré au jour. **Le jour, hors donjon** : statut *Soleil* (`1d2` toutes les 10 ticks, rafraîchi tant qu'il fait jour) — décision : le « 1 % des PV max / 10 ticks » de la note devient un dé fixe, les statuts ne connaissant pas les pourcentages ; à 100 PV c'est équivalent. **Mordre** (clic droit sur un être adjacent) : `1d6` de dégâts perforants, **la jauge de chaîne se remplit entièrement** de l'élément dominant de la victime, la victime humanoïde reçoit *Morsure*. **Ne mange plus de plats** (objets tag `plat` : refusés, journal) — les potions passent.

> [!success] Codé le 2026-08-28 — le Spectre
> `races/spectre.json` (cache) et le talent **Sans chair**. **Devenir** : au **respawn** après une mort dans une cellule de **corruption ≥ 70** (`talents.sans_chair.corruption_seuil`), l'être se relève spectre (`race_origine` conservé) — une *Renaissance* (effet `resurrection`) avant le respawn l'évite, c'est le « ressuscité à temps » de la note. **Dégâts physiques × 0,3** (contondant, tranchant, perforant — dans `_appliquer_degats`, avant tout). **Traverse un mur d'une tuile** : clic droit sur la tuile libre juste derrière un contenu qui bloque le passage (ligne droite, distance 2) → *Traverser le mur*, au coût de deux pas. **Aucune armure** (casque, cuirasse, jambières refusés à l'équipement). **Capacité de poids 5** (`capacite_poids_fixe` lu par `poids_de`). **Ne se soigne que par mana** : les soins des plats et potions (`soin_des`) sont ignorés, les capacités de soin passent. **Les PNJ fuient à vue** : un civil qui voit un spectre reçoit *Terreur* — décision : la « réputation par race effondrée » est portée par cet effet immédiat, la réputation par race n'existant pas.

> [!success] Codé le 2026-08-28 — toute espèce du bestiaire, par l'incarnation
> Voir [[Ouvert — Changer de personnage]] : *Prendre le contrôle* d'un compagnon (bête apprivoisée ou élevée : gratuit ; humanoïde : relation ≥ 75). Une bête incarnée garde ses stats, sa silhouette et ses actions de créature (attaquer passe par elles quand elle n'a pas d'arme — `_attaquer_bete` avec **ses** actions), n'équipe que la barde et les bijoux, ne lit ni ne parle. Le tableau des races cachées est complet.

> [!success] Codé le 2026-08-28 — le Lycanthrope
> `races/lycanthrope.json` (cache) et le talent **Lune**. **Transformation volontaire** (clic droit sur sa tuile → *Se transformer* / *Reprendre forme humaine*, 4 ticks) : `forme_bestiale` — **toutes les stats × 1,5** (`forme_mult` lu par `Etres.recalculer`) ; **attaquer** passe par les **actions de créature** de la forme (`talents.lune.actions` : griffure, morsure puissante — la première possible sur la cible), plus d'arme ; **capacités et dialogue refusés** (journal). **Forcée** : les nuits dont l'index de jour est multiple de 30, la forme bestiale s'impose au premier pas de nuit et se relâche seule à l'aube (`forme_forcee`) — un lycanthrope ne peut pas la quitter cette nuit-là. **Devenir** : mordu (action de créature taguée `morsure`, ou dont l'id commence par `morsure`) par un lycanthrope sous forme bestiale → statut *Morsure lunaire* (un jour) → **à l'aube** suivante, lycanthrope (`race_origine` conservé) ; le rituel attend un meuble. Décision : les actions de la forme sont un jeu fixe en règles, pas une fiche de créature à part — la fiche `loup-garou` viendra avec ses sprites.

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Races]], [[Blocs de l'être]]
- **Alimente** : [[Talents de classe]], [[Ouvert — Changer de personnage]], [[Schéma créature]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Cycle jour-nuit et sommeil]], [[Mana]], [[Récolte]], [[Créatures]], [[Loci — les dix types]], [[Réputation et relations]]
