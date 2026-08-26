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

## Liens
- **Dépend de** : [[Fonctionnalité]], [[Stats d'un objet crafté]], [[Qualité d'artisanat]], [[Matériaux — 13 stats]]
- **Alimente** : [[Pipeline de résolution du combat]], [[Action-time à ticks]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Stats et qualité de l'assemblage]], [[Application des stats de matériau]], [[Compétences — liste]], [[Catalogue matériaux — Bois]], [[Décision — Projectiles]]
