---
aliases: ["A.4.1", "Annexe A.4.1", "Stats d'armes", "Stats de combat des armes", "Profils de fonctionnalité"]
tags: [objets, équipement, combat, formule, décidé]
domaine: objets
statut: décidé
etape: 0
---

La fonctionnalité porte le profil de base, les matériaux modulent, la qualité multiplie — une seule fois.

**Principe :** la **fonctionnalité** (choisie au craft/à la sculpture) porte le profil de base ; les **matériaux** modulent via leurs stats existantes (aucune nouvelle stat de matériau nécessaire) ; la **qualité** multiplie.

```
degats  = jet(degats_des(fonctionnalité)) * (durete_BASE_arme / 20) * qualite
          (système à jets de dés : voir E.3 pour la résolution complète.
          durete_BASE = moyenne pondérée des matériaux AVANT qualité, cf. A.4 —
          la qualité n'est appliquée qu'UNE fois, ici ; ne jamais utiliser la
          dureté finale déjà multipliée, ce serait un double comptage)
          (20 = dureté de référence, étalon fer)
vitesse = vitesse_base(fonctionnalité) * (poids_reference / poids_reel)^0.75
          bornée à [0.4, 1.8] * vitesse_base
          (exposant 0.75 au lieu de sqrt : le choix du matériau du
          manche se SENT — pin vs ébène ≈ 25 % d'écart de cadence)
portee  = fixe par fonctionnalité (non modulée par les matériaux)
type_degats = fixe par fonctionnalité (tranchant / perçant / contondant)
```

**Le poids, chiffré le 2026-08-26** — la formule de vitesse consomme `poids_reference` et `poids_reel`, dont aucun n'était défini. Les deux dérivent d'un seul champ déclaré, le **volume** :

```
volume            = champ déclaré par la fonctionnalité (data/functionalities/*.json)
poids_reel_kg     = densite_composite * volume / 10
poids_reference   = 12 * volume / 10          (12 = densité du FER, l'étalon)
```

| Fonctionnalité | Dague | Épée | Masse | Lance | Hache d'armes | Arc | Arbalète | Bâton |
|---|---|---|---|---|---|---|---|---|
| `volume` | 1.6 | 3.2 | 5.5 | 3.8 | 4.6 | 1.4 | 4.2 | 2.0 |

**Pour l'armure**, `volume` est déclaré par pièce : Casque 6 · Cuirasse 12 · Brassards-gants 5 · Jambières 7 · Bottes 3. Le poids porté alimente `capacite = 30 + Force × 5` ([[Armures et poids porté]]).

Conséquence voulue : **une épée en or pèse 5 kg et une en titane 2,6 kg** — le matériau se sent dans la main avant de se voir dans les chiffres.

**Profils de fonctionnalité par défaut** (`data/functionalities/*.json`) :

| Fonctionnalité | Dés de dégâts | Crit | Vitesse (att./10 ticks) | Portée (blocs) | Type |
|---|---|---|---|---|---|
| Dague | 1d6 | 19-20 | 3.0 | 1 | perçant |
| Épée | 2d6 | 20 | 2.0 | 1.5 | tranchant |
| Masse | 3d8 | 20 | 1.2 | 1.5 | contondant |
| Lance | 2d8 | 20 | 1.5 | 2.5 | perçant |
| Hache d'armes | 2d10 | 20 | 1.4 | 1.5 | tranchant |
| Arc | 2d6 | 20 | 1.5 | 25 | perçant |
| Arbalète | 3d6 | 20 | 0.8 | 30 | perçant |
| Bâton magique | 1d4 | 20 | 1.8 | 1 | contondant |

Le résultat du jet est ensuite modulé par matériaux/qualité (formule [[Pipeline de résolution du combat]]) — les dés remplacent le `degats_base` fixe ; `crit_range` : valeurs naturelles du d20 déclenchant un critique.

- La dureté pilote les dégâts, la densité (poids) pilote la vitesse : granit noir = lent et dévastateur, bois-fer léger = rapide mais mordant modérément.
- Les **dégâts élémentaires viennent des modules** ([[Structure compétences-modules-slots]]), jamais de l'arme elle-même.

**Vitesse d'arme et tempo ([[Action-time à ticks]]) :** `attaque : 10 / vitesse_arme` ticks — le choix d'arme est un choix de tempo.

**Portée en tuiles ([[Combat tactique sur grille]]) :** chaque arme a sa portée et éventuellement un **minimum** (une lance est mauvaise au contact).

**Modulation par l'élasticité du bois ([[Application des stats de matériau]]) :** `Arc/arbalète : degats *= (0.8 + elasticite_bois / 250)`.

> [!success] Décidé le 2026-08-26 — portées sur la grille
> Le tableau donne des portées en « blocs » (1.5, 2.5) antérieures au pivot. Sur la grille, une portée se lit en **tuiles de Chebyshev** (les 8 voisines sont à distance 1), **arrondie à l'entier inférieur** : Dague/Épée/Masse/Bâton = 1, Lance = 2, Arc = 25, Arbalète = 30. Le `portee_min` est 1 par défaut, **2 pour la lance et l'arc** (zone morte au contact — *« une lance est mauvaise au contact »*). Le déplacement se fait en **8 directions au même coût** (3 ticks, modulé par le dénivelé). Le prototype fixe `durete_base = 20` (fer étalon) et `qualite = 1.0` sur ses armes, l'élément étant un champ de l'objet (`data/items/proto_*.json`) en attendant le craft.

> [!success] Rendu le 2026-09-03 — **les armes à distance : à munitions, et de jet** (designer, point 78)
> « Rajoute les armes d'attaque à distance à munitions (fronde, pistolet, arc etc.) et les armes de jets (l'item en lui-même est la munition, le stack s'équipe en main, javelots etc.) »
>
> **La moitié « à munitions » existait déjà, entièrement.** Ma note d'état des lieux disait le contraire et j'ai failli réécrire un système entier : `functionality.projectile: true` marque l'arme, le **carquois** fournit le compte, chaque tir décrémente, un tir sans munition est refusé et le dit, la trajectoire est réelle — un allié sur la ligne bloque, un ennemi prend la flèche — et les munitions se **récupèrent** après le combat. Il manquait du **contenu**, pas de la mécanique.
>
> **La mécanique de JET, elle, n'existait pas.** C'est ce qui sépare les deux familles : l'arc reste en main et vide un carquois ; le javelot **quitte la main**. La pile équipée diminue d'un à chaque jet, l'objet lancé retombe sur la tuile visée — **copié depuis celui qu'on tenait**, même matière, même qualité, même affixe, pour qu'un javelot ramassé vaille exactement celui qu'on a lancé — et quand la pile est vide, l'emplacement se libère. Mesuré par `res://scenes/tests/sonde_jet.tscn` : 3 en main → 2, 1, 0, et 3 au sol.
>
> **Six armes, différenciées sur quatre axes à la fois** — jamais un seul, parce que deux armes qui ne diffèrent que par leurs dés ne sont pas deux armes :
>
> | arme | dés | vitesse | portée | type | ce qui la définit |
> |---|---|---|---|---|---|
> | Fronde | 1d8 | 1,7 | 14 / 3 | contondant | la seule contondante à distance ; munitions ramassables partout |
> | Arbalète | 3d6 | 0,9 | 22 / 2 | perforant | la portée et la force, payées par la lenteur |
> | Pistolet | 3d8 | 0,7 | 12 / 2 | perforant, crit **18** | brutal et lent ; c'est la rareté de sa poudre qui l'équilibre |
> | Javelot | 2d6 | 1,6 | 8 / 2 | perforant | l'arme de jet complète : portée ET dégâts |
> | Couteau de jet | 1d6 | 2,6 | 6 / 2 | perforant, crit 19 | le plus rapide du jeu, à bout portant |
> | Hachette de jet | 2d4 | 1,8 | 5 / 2 | **tranchant** | la seule tranchante à distance |
>
> Avec leurs munitions (billes, carreaux, balles) et trois compétences qui manquaient : `fronde`, `jet`, `armes_a_poudre`.
>
> > [!warning] Le compteur qui mentait
> > Au troisième jet, la sonde affichait « 1 en main » alors que la main était vide. La pile était bien retirée de l'équipement, mais je ne remettais pas son compteur à zéro : le dictionnaire orphelin **mentait sur son compte**. Sans conséquence visible aujourd'hui, et exactement le genre de valeur périmée qui donne un bug incompréhensible trois semaines plus tard, quand quelque chose garde une référence.

## Liens
- **Dépend de** : [[Fonctionnalité]], [[Stats d'un objet crafté]], [[Qualité d'artisanat]], [[Matériaux — 13 stats]]
- **Alimente** : [[Pipeline de résolution du combat]], [[Action-time à ticks]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Stats et qualité de l'assemblage]], [[Application des stats de matériau]], [[Compétences — liste]], [[Catalogue matériaux — Bois]], [[Décision — Projectiles]]
