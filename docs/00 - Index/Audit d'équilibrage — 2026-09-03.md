---
aliases: ["Audit d'équilibrage", "État de l'équilibrage 2026-09-03"]
tags: [index, production, mesure, ouvert]
domaine: index
statut: ouvert
etape: 10
---

# Audit d'équilibrage — 2026-09-03

> [!important] Ce que le designer a demandé
> « De tout ce qu'on a maintenant dans le jeu, vérifie que tout est bon, que tout marche comme il faut, l'équilibrage etc tout ça. »

**Le technique est sain.** Suite complète verte, dix sondes vertes, cinq bancs, fuzz sur trois graines (7 500 pas, zéro erreur), scène soixante secondes sans erreur, coffre intègre, audit des données propre, traductions à 100 %, tous les scripts compilent. Rien n'est cassé.

**L'équilibrage, lui, a quatre problèmes de fond.** Ils sont tous mesurés, aucun n'est tranché ici — ce sont des décisions de designer. Ils sont classés par ce qu'ils coûtent au jeu, pas par difficulté de correction.

## 1. Les sorts sont dominés par le fait de taper

Même robot, même graine, même équipement, huit mille images :

| profil | étages descendus | tués | coups portés |
|---|---|---|---|
| 3 objets, **0 sort** | 1 | **20** | 88 (fin à 68/68 PV) |
| 3 objets, **3 sorts** | 0 | 1 | 8 — et 15 sorts lancés |

Le banc donne la raison : le **meilleur** sort de classe rend **6,75 PV par tick** (Le Rieur, Botte), le pire **0,08** (La Paume, Sève). Une épée en rend **14,0**, une masse **16,2**. Et ce qui tue les sorts n'est pas tant leurs dés que leur **temps** : 10 à 21 ticks contre 4 pour un coup d'épée.

**Pourquoi c'est le plus grave** : le système de modules est l'identité du jeu. Aujourd'hui, rien ne pousse mécaniquement à s'en servir. Les sorts ont pour eux la portée, la zone et les statuts — que le banc ne mesure pas — mais le robot joue vraiment, et il conclut pareil.

**Les leviers** : monter les dés des noyaux offensifs ; baisser le coût en ticks ; ou assumer que les sorts sont **situationnels** et donner alors aux classes de meilleures armes. Le choix dit ce qu'est le jeu.

## 2. Le monde va jusqu'au niveau 90, le butin s'arrête au niveau 15

Quatre axes de progression, quatre plateaux, quatre causes distinctes :

| axe | niveau 5 | niveau 15 | niveau 90 | la cause |
|---|---|---|---|---|
| palier de matière (P5) | 0 % | 11 % | 10 % | `paliers_materiaux` ouvre P5 à la profondeur 14, il n'y a pas de P6 |
| rareté (exceptionnel) | 15 % | 15 % | 16 % | `poids_par_profondeur` n'a que **cinq lignes**, elle s'arrête à la profondeur 4 |
| objets à affixe | 20 % | 23 % | 23 % | conséquence du plateau de rareté |
| qualité moyenne | 1,87 | 2,25 | 2,55 | `niveau/(niveau+25) × 2` — **+12 % sur soixante-quinze niveaux** |

Pendant ce temps, la profondeur, elle, continue : cinq étages à niveau 15, **vingt-quatre** à niveau 90.

**Les leviers** : étirer les cinq paliers existants pour couvrir la carte (cinq chiffres, aucun contenu) ; ajouter des paliers 6 et 7 (du contenu) ; plafonner la courbe de niveau du monde ; ou assumer le plateau et faire porter la fin de partie par autre chose — qualité et affixes ne le font pas aujourd'hui, c'est mesuré.

## 3. Les deux échelles de niveau ne parlent pas la même langue

L'XP versée **égale les dégâts infligés**, et un niveau de compétence coûte `100 × (N+1)^1,6`. Le « niveau de combat » est la moyenne des cinq meilleures compétences. Ordres de grandeur, en supposant qu'un coup nourrit trois compétences à la fois (élément, arme, type de dégâts) :

| niveau de combat visé | tués, ordre de grandeur |
|---|---|
| 25 | ~7 000 |
| 50 | ~43 000 |
| 90 | ~196 000 |

Un personnage de niveau 50 n'est donc pas atteignable en temps de jeu réaliste, alors que la carte affiche des donjons de niveau 90. Les deux nombres n'ont pas la même signification — la difficulté réelle d'un étage vient de son **plafond de puissance** (`26 + 6 × étage`), pas du niveau du donjon — mais le joueur, lui, lit deux fois le mot « niveau ». **Ce n'est peut-être qu'un problème de vocabulaire**, et alors il se règle en renommant ; ou c'est un vrai désaccord d'échelles, et alors l'un des deux nombres doit bouger.

## 4. La masse n'a aucune contrepartie

**16,2 dégâts par tick**, le meilleur du jeu — devant l'épée (14,0) et la lance (13,5, qui coûte pourtant deux mains). Et elle est **contondante**, le type que la matrice d'armure favorise contre les protections lourdes (0,95 contre la plaque, quand le tranchant paie 1,30). La plus forte dans l'absolu **et** la meilleure contre ce qui protège le mieux, en une seule main, sans malus de portée.

Les sept armes de contact ajoutées le même jour ont été conçues pour ne pas aggraver — le marteau de guerre frappe plus fort (14,0 de moyenne) mais si lentement qu'il tombe à 11,2 par tick, et coûte deux mains.

## Ce qui a été corrigé pendant l'audit

- **Le mur du premier étage** venait de `puissance_creature`, la formule qui décide qui peut peupler un étage : elle comptait les stats et le nombre d'actions, et **ignorait l'équipement**. Un bandit en cuirasse avec une épée valait autant qu'un bandit à mains nues. Il passe de 25 à 42 et quitte l'étage 1. Trois hypothèses avaient été écartées par la mesure avant d'y arriver — l'aggro coupée, l'alerte de meute à zéro, et une rejouée au tag `v0.4.1-alpha`.
- **Deux fautes de mes propres sondes**, corrigées avant d'être rapportées comme des défauts du jeu : l'une appelait une fonction inexistante et faisait croire à un blocage ; l'autre inventait une rareté « légendaire » qui n'existe pas (la bonne s'appelle **artefact**) et annonçait donc 0 % à tous les niveaux.

## Liens

- **Détaille** : [[À juger — parcours de jeu]], [[Vers la production]]
- **Mesure** : [[Stats d'armes]], [[Loot — affixes, gemmes et rareté]], [[Progression par l'usage]], [[IA des créatures]]
