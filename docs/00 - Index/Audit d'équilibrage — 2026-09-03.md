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

## 1. Un écart de quatre-vingt-quatre entre le meilleur et le pire sort de classe

> [!error] Résolu le 2026-09-03 — **le robot se tuait lui-même, le jeu n'y était pour rien**
> J'avais rapporté que le robot armé de sorts mourait trois fois à l'étage 1 quand le même robot sans sorts descendait et faisait vingt tués, et j'en avais tiré des conclusions sur les sorts. La dernière ligne de son journal disait pourtant tout : « **SURCHAUFFE : 9 de mana manquant → 18 PV** », puis « tombe » — **combat déjà gagné, aucun ennemi en vue**.
> Lancer à sec n'est pas *refusé* par le jeu : c'est la **surchauffe**, qui prend le déficit en points de vie, doublé. Le robot tirait un sort au hasard une fois sur deux sans jamais regarder son mana, et se suicidait. Ses trois morts étaient portées au compte de la difficulté du donjon ; **aucune** n'était due aux ennemis.
> **Après correction du robot** — il vérifie qu'il peut payer —, même graine, même équipement :
>
> | profil | étages | tués | morts | PV à la fin |
> |---|---|---|---|---|
> | 3 objets, 0 sort | 1 | 20 | 1 | 68/68 |
> | 3 objets, **3 sorts** | **1** | **22** | 2 | 63/68 |
>
> Les deux profils se valent. **Un robot qui joue comme aucun humain ne joue ne mesure rien** — et il m'a fait écrire deux conclusions fausses d'affilée sur le même sujet.

**Ce qui reste, et qui est réel.** Le robot n'a lancé que **six sorts en huit mille images**, parce que le mana se régénère d'un point tous les quatre-vingts ticks environ — un sort à 8 de mana coûte donc **six cent quarante ticks** de régénération. Ce n'est pas un défaut : la régénération suit la **Méditation** (`1 + Méditation × 0,2`), et le robot a Méditation zéro. C'est le taux de départ, pas celui d'un lanceur établi. Mais cela dit quelque chose du jeu de début de partie : **au niveau zéro, on est un guerrier qui a six sorts en réserve**, et les classes dont les sorts sont au contact — donc qui montent sur l'arme — s'en sortent bien mieux que celles qui dépendent de sorts élémentaires à distance.

> [!error] Corrigé le 2026-09-03 — **ma comparaison arme/sort était fausse, et dans le mauvais sens**
> J'avais écrit qu'une épée rend **14,0 PV par tick** et une masse **16,2**, contre 6,75 pour le meilleur sort. C'était une **erreur d'unité** : `vitesse_base` **divise** le coût en ticks (`ticks = actions.attaque_base / vitesse`), elle ne le multiplie pas. J'ai calculé `moyenne × vitesse` et appelé ça des dégâts par tick : le classement **entre armes** restait juste, mais la valeur était **dix fois trop grande**, et je m'en suis servi pour comparer les armes aux sorts.
> **Les vrais chiffres** : masse **1,69** PV/tick, épée 1,40, rapière 1,38, lance 1,29, dague 1,05, mains nues 0,40. Les armes vont donc de **0,40 à 1,69**, et non de 4 à 16.

**Le vrai problème n'est pas « les sorts contre les armes », c'est l'écart ENTRE LES SORTS.** Le banc mesure de **0,08** (La Paume, Sève : 1 PV en 12 ticks) à **6,75** (Le Rieur, Botte : 27 PV en 4 ticks) — un facteur **quatre-vingt-quatre**. Et la coupure n'est pas aléatoire : les sorts au **contact** (Botte 6,75, Projection 6,4, Estoc 4,25) portent **les dégâts de l'arme équipée en plus des leurs**, quand les sorts élémentaires à distance (Éclat 1,69, Flamme 0,8, Gel 0,7) ne comptent que sur eux-mêmes. Quatre classes ont tiré le bon numéro, les autres non.

**Ce qui reste vrai malgré l'erreur** : le robot armé de sorts meurt trois fois à l'étage 1 quand le même robot sans sorts descend et fait vingt tués. La mesure tient ; c'est mon **explication** qui était fausse. La cause reste à trouver — coût en mana, choix de cible du robot, ou temps perdu à lancer des sorts utilitaires — et je ne la devinerai pas deux fois de suite.

**Pourquoi c'est le plus grave** : ce n'est pas le système qui est mauvais, c'est le **tirage au sort du kit**. Un joueur qui choisit La Paume ou La Trace reçoit des sorts vingt à quatre-vingts fois moins efficaces que celui qui choisit Le Rieur ou Le Sabre, sans que rien ne l'en avertisse. Le choix de classe, qui devrait être un choix de **style**, est en réalité un choix de puissance.

**Les leviers, revus après correction** : (1) faire en sorte qu'un sort à distance rapporte autant qu'un sort de contact — aujourd'hui le contact encaisse en plus les dégâts de l'arme, ce qui est une double rémunération ; (2) relever les noyaux du bas (Sève, Gravier, Épine sont sous les mains nues) ; (3) revoir les kits pour qu'aucune classe ne parte avec trois sorts faibles. La (1) est la plus structurante, la (3) la moins risquée.

## 2. Le monde va jusqu'au niveau 90, le butin s'arrête au niveau 15

Quatre axes de progression, quatre plateaux, quatre causes distinctes :

| axe | niveau 5 | niveau 15 | niveau 90 | la cause |
|---|---|---|---|---|
| palier de matière (P5) | 0 % | 11 % | 10 % | `paliers_materiaux` ouvre P5 à la profondeur 14, il n'y a pas de P6 |
| rareté (exceptionnel) | 15 % | 15 % | 16 % | `poids_par_profondeur` n'a que **cinq lignes**, elle s'arrête à la profondeur 4 |
| objets à affixe | 20 % | 23 % | 23 % | conséquence du plateau de rareté |
| qualité moyenne | 1,87 | 2,25 | 2,55 | `niveau/(niveau+25) × 2` — **+12 % sur soixante-quinze niveaux** |

Pendant ce temps, la profondeur, elle, continue : cinq étages à niveau 15, **vingt-quatre** à niveau 90.

> [!check] Résolu à moitié le 2026-09-03 — **le plafond de rareté était écrit en dur dans le code**
> La table `poids_par_profondeur` s'arrêtait à la ligne 4, mais surtout le générateur y **plafonnait en dur** : `mini(profondeur, 4)`. Ajouter des lignes n'aurait rien fait — un donjon de niveau 90 tirait sa rareté sur la ligne du niveau 4. C'était aussi un nombre de gameplay en dur, ce que les contraintes du projet interdisent. Le plafond est redevenu une **donnée** : le code prend la plus haute ligne que la table déclare.
> **La table est étendue jusqu'au niveau 60**, et les lignes 0 à 4 sont **inchangées** — le début de partie, que tout le monde joue, se comporte exactement comme avant. Mesure après coup :
>
> | niveau | 1 | 5 | 15 | 25 | 50 | 90 |
> |---|---|---|---|---|---|---|
> | exceptionnel | 1 % | 15 % | **29 %** | **42 %** | 43 % | **51 %** |
> | objets à affixe | 5 % | 20 % | **34 %** | **40 %** | 41 % | **44 %** |
>
> Deux des quatre axes progressent donc de nouveau sur toute la portée du monde. **Le palier de matière reste plat** après le niveau 14 : celui-là demande soit d'étirer les cinq paliers existants — ce qui appauvrirait le début de partie — soit d'écrire des matières de palier 6 et 7. C'est du contenu et un choix de fond : il reste au designer.

**Les leviers pour le palier de matière** : étirer les cinq paliers existants (cinq chiffres, mais le début de partie s'appauvrit) ; ajouter des paliers 6 et 7 (du contenu à écrire) ; ou plafonner la courbe de niveau du monde.

## 3. Les deux échelles de niveau ne parlent pas la même langue

L'XP versée **égale les dégâts infligés**, et un niveau de compétence coûte `100 × (N+1)^1,6`. Le « niveau de combat » est la moyenne des cinq meilleures compétences. Ordres de grandeur, en supposant qu'un coup nourrit trois compétences à la fois (élément, arme, type de dégâts) :

| niveau de combat visé | tués, ordre de grandeur |
|---|---|
| 25 | ~7 000 |
| 50 | ~43 000 |
| 90 | ~196 000 |

Un personnage de niveau 50 n'est donc pas atteignable en temps de jeu réaliste, alors que la carte affiche des donjons de niveau 90. Les deux nombres n'ont pas la même signification — la difficulté réelle d'un étage vient de son **plafond de puissance** (`26 + 6 × étage`), pas du niveau du donjon — mais le joueur, lui, lit deux fois le mot « niveau ». **Ce n'est peut-être qu'un problème de vocabulaire**, et alors il se règle en renommant ; ou c'est un vrai désaccord d'échelles, et alors l'un des deux nombres doit bouger.

## 4. La masse n'a aucune contrepartie

**1,69 PV par tick** (chiffre corrigé), le meilleur du jeu — devant l'épée (1,40), la rapière (1,38) et la lance (1,29, qui coûte pourtant deux mains). Et elle est **contondante**, le type que la matrice d'armure favorise contre les protections lourdes (0,95 contre la plaque, quand le tranchant paie 1,30). La plus forte dans l'absolu **et** la meilleure contre ce qui protège le mieux, en une seule main, sans malus de portée.

L'écart reste modéré — 21 % au-dessus de l'épée — mais il va dans le même sens sur les deux axes, et c'est ce cumul qui la rend sans rivale. Les sept armes de contact ajoutées le même jour ont été conçues pour ne pas aggraver : le marteau de guerre frappe plus fort (14,0 de moyenne) mais si lentement qu'il tombe à 1,17 par tick, et coûte deux mains.

## Ce qui a été corrigé pendant l'audit

- **Le mur du premier étage** venait de `puissance_creature`, la formule qui décide qui peut peupler un étage : elle comptait les stats et le nombre d'actions, et **ignorait l'équipement**. Un bandit en cuirasse avec une épée valait autant qu'un bandit à mains nues. Il passe de 25 à 42 et quitte l'étage 1. Trois hypothèses avaient été écartées par la mesure avant d'y arriver — l'aggro coupée, l'alerte de meute à zéro, et une rejouée au tag `v0.4.1-alpha`.
- **Une erreur d'unité dans ma propre mesure**, qui a faussé la conclusion principale de la première version de cet audit : `vitesse_base` divise le coût en ticks, elle ne le multiplie pas. Les valeurs annoncées pour les armes étaient dix fois trop grandes, et j'en avais conclu — à tort — que taper battait tous les sorts. Corrigée dans la mesure, dans la sonde des armes qui la portait, et ici.
- **Deux fautes de mes propres sondes**, corrigées avant d'être rapportées comme des défauts du jeu : l'une appelait une fonction inexistante et faisait croire à un blocage ; l'autre inventait une rareté « légendaire » qui n'existe pas (la bonne s'appelle **artefact**) et annonçait donc 0 % à tous les niveaux.

## Liens

- **Détaille** : [[À juger — parcours de jeu]], [[Vers la production]]
- **Mesure** : [[Stats d'armes]], [[Loot — affixes, gemmes et rareté]], [[Progression par l'usage]], [[IA des créatures]]
