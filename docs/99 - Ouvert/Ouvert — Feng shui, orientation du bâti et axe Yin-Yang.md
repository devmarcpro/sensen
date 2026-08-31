---
aliases: ["Ouvert — Feng shui", "Feng shui", "Orientation du bâti", "Vecteur de pièce", "Sha qi", "Yin-Yang", "Axe Yin-Yang"]
tags: [ouvert, société, monde, wuxing, vision]
domaine: société
statut: ouvert
etape: 7
---

Le Wu Xing mord sur six domaines et **pas sur le bâti**. Deux extensions culturellement justes le combleraient sans nouveau système : le **feng shui** (une décision spatiale) et l'**axe Yin-Yang** (une décision temporelle).

## Le manque, tel qu'il se voit au 2026-08-31

[[Identité visuelle chinoise]] pose le Wu Xing comme **grammaire mécanique de tout le jeu**. Il tient parole partout sauf à un endroit :

| Domaine | Comment il mord | Note |
|---|---|---|
| Combat | vecteurs, domination, jauge de chaîne | [[Wu Xing — cycles et vecteurs]] |
| Lieu | `vecteur_lieu(pos)` dérivé des couches de bruit, mana ×0.85 / ×1.15 | [[Wu Xing hors combat]] |
| Cuisine | plat couvrant les cinq → nutrition et potentiel ×1.2 | [[Cuisine et alchimie]] |
| Matériaux | vecteur dérivé de la catégorie | [[Décision — Surcharges Wu Xing des matériaux]] |
| Naissance | élément + animal → pente de potentiel, trines | [[Astrologie — cycle sexagésimal]] |
| **Bâti, claim, royaume** | **rien** | [[Royaume du joueur]], [[Habitat des PNJ]] |

Or le domaine 07 est la moitié du jeu et occupe les étapes 7 à 10. Le bâti y est aujourd'hui un problème d'**inventaire** (poser des meubles chers) et non de **placement** — le défaut de presque tout le genre, et celui que l'identité culturelle de Sensen est la mieux placée pour corriger.

## Ce qui existe déjà et qu'il n'y a pas à produire

C'est ce qui rend la question sérieuse plutôt que décorative — **aucune donnée nouvelle n'est requise** :

- `Simulation.pieces_de_cellule(cell)` rend déjà `{tuiles, meubles, portes}` par flood fill ([[Détection de pièces]]) — la porte, le mur et le meuble sont en main ;
- `Simulation.vecteur_lieu(pos)` rend déjà l'élément du sol sous la pièce ;
- `WuXing.relation(att, cible)` rend déjà `domine · domine_par · engendre · neutre` ;
- les matériaux portent déjà un vecteur — une pièce peut en hériter comme un plat hérite du sien ;
- le pentagramme a déjà ses directions canoniques : **Bois = Est · Feu = Sud · Métal = Ouest · Eau = Nord · Terre = centre**.

## Piste A — Le feng shui : la décision **spatiale**

Le geste à copier est celui de la cuisine — une **condition composée** que le joueur peut voir et rater, jamais une somme de petits bonus.

1. **Vecteur de pièce** = agrégat des vecteurs des matériaux de ses murs et de ses meubles. Fonction pure, calculée à la revalidation hebdomadaire déjà en place.
2. **Accord au lieu** — `relation(vecteur du lieu, vecteur de la pièce)` :
   - **engendre** → le lieu nourrit la pièce : sommeil réparateur, régénération, moral du PNJ logé ;
   - **domine** → le lieu attaque la pièce : sommeil mauvais, usure accélérée, le PNJ finit par déménager ;
   - **neutre** → rien. La plupart des pièces doivent tomber ici : l'accord se mérite.
3. **Orientation de la porte** — le vrai cœur historique du feng shui, et la seule donnée déjà stockée qui ne sert à rien aujourd'hui. Porte dont l'orientation s'accorde à l'élément dominant du lieu → la pièce « respire ».
4. **Sha qi** (les « flèches empoisonnées ») — un couloir droit qui pointe sur un lit, un angle de mur qui vise une porte. Une passe de raycast sur la grille au moment du flood fill. C'est ce point-là qui transforme réellement le bâti en problème de placement.

## Piste B — L'axe Yin-Yang : la décision **temporelle**

**Le piège à ne pas manquer :** faire du Yin-Yang un **sixième élément** casserait le pentagramme, la table de domination et la jauge de chaîne. Ce serait la pire version de l'idée.

La bonne version : un **axe orthogonal**, indépendant du vecteur à cinq branches, que chaque chose porte *en plus* de son élément.

- **Yang** : jour, extérieur, surface, chaud, sec, actif, été.
- **Yin** : nuit, intérieur, donjon, froid, humide, passif, hiver.
- Tout le support existe déjà : [[Cycle jour-nuit et sommeil]], [[Décision — Saisons activées à l'étape 10]], [[Météo]], surface *vs* [[Donjons — structure et intégration]].
- Se branche sur l'axe de **conditions** déjà en place ([[Vocabulaire des modules — six axes]]) sans toucher au Wu Xing : un noyau Yang rend `+X` le jour et `−X` la nuit, exactement comme l'affixe `cond_nuit` existe déjà.
- **Croise le feng shui** : une chambre est Yin par vocation, une forge est Yang. Une forge en sous-sol au nord est doublement fausse — et le joueur peut le comprendre sans lire un tableau.

## Piste C — L'almanach (Tongshu) : les jours fastes

Prolongement quasi gratuit d'[[Astrologie — cycle sexagésimal]] : le cycle sexagésimal s'applique déjà aux **êtres**, il peut s'appliquer aux **jours**. Résonance jour ↔ signe du personnage → modulateur mineur sur un craft, une récolte, un jet. Donne le geste très chinois de **choisir sa date** pour une entreprise importante. Rapport contenu / code excellent, aucun système nouveau.

## Ce qui est écarté, et pourquoi

- **Bagua / les huit trigrammes** — une *seconde* grammaire symbolique à huit branches à côté d'une grammaire à cinq. Deux systèmes concurrents dans la tête du joueur n'en font aucun. Réservé au **vocabulaire visuel** ([[Direction artistique]]), jamais à la mécanique.
- **Qi, dantian, méridiens, paliers de cultivation** — c'est du *xianxia*, pas du daoïsme classique, et c'est un genre entier. Sensen a déjà mana, endurance, potentiel et progression par modules ([[Structure compétences-modules-slots]]) : ce serait une cinquième jauge et un second système de progression.
- **Guanxi** — déjà présent sans le nom : [[Réputation et relations]] plus les trines astrologiques font exactement ce travail.

## Le risque de fond, qui vaut pour tout ajout futur

Le Wu Xing s'applique déjà à six domaines. **Chaque nouvelle application est individuellement séduisante et collectivement dangereuse** : un jeu où tout est teinté du même ±15 % transforme la grammaire en bruit de fond au lieu d'une lecture. La cuisine s'en sort parce qu'elle exige une *couverture des cinq* — une décision réelle ; le coût de mana par lieu est plus faible parce qu'il n'est qu'un multiplicateur.

**Critère retenu pour trancher tout ajout de ce type :** *est-ce que ça crée une décision spatiale ou temporelle que le joueur peut voir et rater ?* Le feng shui coche (placement). Le Yin-Yang coche (timing). L'almanach coche (timing). Un « +10 % Bois si l'on porte du jade » ne coche pas — et n'entre pas.

**Note de traitement :** le feng shui et le bazi sont des pratiques vivantes. Les mécaniser est légitime — le Wu Xing l'est déjà, et avec sérieux — à condition de rester du côté « système cohérent traité avec respect » et non « superstition pittoresque qui distribue des malus ».

## Ce qui reste à trancher

- [ ] Le vecteur de pièce est-il un **agrégat des matériaux**, ou un champ posé par le joueur (un autel, une pièce maîtresse qui donne le ton) ?
- [ ] Le sha qi est-il **bloquant** (le PNJ refuse la pièce) ou **graduel** (il y dort mal) ? Le graduel se lit moins bien mais frustre moins.
- [ ] L'axe Yin-Yang est-il **visible en UI** ou seulement déduit par le joueur ?
- [ ] Étape d'atterrissage : le feng shui suit [[Détection de pièces]] (étape 7) ; le Yin-Yang pourrait descendre à l'étape 0 (combat) puisqu'il n'y coûte qu'une condition.

## Liens
- **Dépend de** : [[Détection de pièces]], [[Wu Xing hors combat]], [[Wu Xing — cycles et vecteurs]], [[Identité visuelle chinoise]]
- **Alimente** : [[Habitat des PNJ]], [[Royaume du joueur]], [[Claims et persistance]], [[Vocabulaire des modules — six axes]]
- **Voir aussi** : [[Astrologie — cycle sexagésimal]], [[Cuisine et alchimie]], [[Cycle jour-nuit et sommeil]], [[Décision — Saisons activées à l'étape 10]], [[Ouvert — Saisons]], [[Réputation et relations]]
