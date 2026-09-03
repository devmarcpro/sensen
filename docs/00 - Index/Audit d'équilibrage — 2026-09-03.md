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

> [!warning] Trouvé le 2026-09-04 — **le robot jouait toujours Le Sabre**, quelle que soit la classe demandée
> `parcours.tscn` ne créait son personnage que si l'écran titre était ouvert — et en headless, `main.gd` ne l'ouvre jamais. Les options `--classe` et `--race` étaient donc ignorées **sans un mot** : toute « matrice de classes » jouée par le robot (le point 30 du 2026-08-31, les comparaisons de kits) comparait Le Sabre à Le Sabre. Trouvé quand le robot a enfin **dit qui il était** (une ligne de journal de plus). Corrigé : il crée son personnage dès qu'une classe ou une race est demandée. Les mesures de cette note qui n'opposaient pas des classes (le robot avec et sans sorts, la surchauffe) tiennent ; celles qui les opposaient sont à refaire.

> [!check] Refait le 2026-09-04 — la matrice des six voies, jouée par un robot qui change vraiment de classe
> Même graine, même étage, 2 500 images, trois objets et trois sorts composés par classe ; un représentant par classe mère (la première dans l'ordre alphabétique). Ce sont des **mesures**, pas des jugements — l'équilibrage est au designer.
>
> | classe mère | représentant | combats | coups portés | coups reçus (dégâts) | tués | morts |
> |---|---|---|---|---|---|---|
> | guerrier | L'Écarlate | 5 | 62 | 21 (44) | 8 | 1 |
> | rôdeur | L'Engrenage | 4 | 26 | **37 (100)** | **1** | **2** |
> | mage | La Paume | 2 | 27 | 5 (8) | 2 | 0 |
> | sentinelle | Le Sceau | 6 | 25 | **0 (0)** | 4 | 0, et un étage descendu |
> | érudit | Le Creuset | 2 | 41 | 2 (4) | 1 | 0 |
> | meneur | La Balance | 3 | 41 | 6 (9) | 5 | 0 |
>
> **Une réserve avant de lire le tableau** : `--equiper 3` a donné à chaque classe **les mêmes trois objets** — une lance, une dague, des jambières de plaque — et la lance a remplacé l'arme de départ de la classe. La matrice compare donc les stats et les capacités de kit, **pas les voies d'armes** : L'Engrenage s'est battu avec une lance, pas avec son arc. C'est un défaut du robot (il équipe par-dessus le kit), corrigé ensuite ; le tableau reste vrai pour ce qu'il mesure.
>
> **Refaite avec le kit gardé** (le robot n'écrase plus l'arme de départ ; les objets générés vont dans les emplacements vides) — mêmes réglages :
>
> | classe mère | représentant | arme de départ | combats | coups portés | coups reçus (dégâts) | tués | morts |
> |---|---|---|---|---|---|---|---|
> | guerrier | L'Écarlate | épée en fonte (pauvre 0,60) | 2 | 30 | 20 (42) | 1 | 1 |
> | rôdeur | L'Engrenage | arc en plomb (misérable 0,48) | 3 | 23 | 7 (21) | 2 | 0 |
> | mage | La Paume | bâton magique en cuivre (pauvre 0,54) | 1 | 39 | 0 | 0 | 0 |
> | sentinelle | Le Sceau | bâton magique en cuivre | 1 | 29 | 1 (1) | 0 | 0 |
> | érudit | Le Creuset | bâton magique en cuivre | 1 | 57 | 0 | 0 | 0 |
> | meneur | La Balance | bâton magique en cuivre | 4 | 52 | 3 (5) | 1 | 0 |
>
> Lue avec son arme, la matrice dit autre chose : **avec le seul kit de départ, quatre classes sur six ne tuent rien** en 2 500 images — cinquante-sept coups portés pour zéro tué, c'est un bâton de cuivre à 1d4 et pauvre 0,54, pas un manque de coups. L'Engrenage, lui, s'en sort mieux à l'arc qu'à la lance qu'on lui avait mise. **Quatre classes sur six partent avec le même bâton magique en cuivre** : les kits des classes mères mage, sentinelle, érudit et meneur ne se distinguent pas par l'arme. Deux questions pour le designer, dans [[À juger — parcours de jeu]] : la qualité des armes de départ (pauvre / misérable), et une arme de départ par voie.
>
> **Troisième passe, avec les kits alignés sur la voie** (même graine, chaque classe tient l'arme de sa voie) :
>
> | classe mère | représentant | arme de départ | coups portés | coups reçus (dégâts) | tués | morts |
> |---|---|---|---|---|---|---|
> | guerrier | L'Écarlate | épée en fonte (0,60) | 30 | 21 (45) | 1 | 1 |
> | érudit | L'Engrenage | arc en plomb (0,48) | 16 | 0 | 1 | 0 |
> | mage | La Paume | bâton magique en cuivre (0,54) | 35 | 0 | 0 | 0 |
> | sentinelle | Le Sceau | lance en aluminium (0,56) | 17 | 0 | 0 | 0 |
> | érudit | Le Creuset | sarbacane en étain (0,63) | 12 | 17 (38) | 1 | 0 |
> | meneur | La Balance | luth en manganèse (0,60) | **90** | 20 (40) | **0** | 1 |
>
> La lecture ne change pas : le kit de départ est trop faible pour tuer au premier étage, quelle que soit la voie. Et une donnée neuve : **la meneuse frappe quatre-vingt-dix fois au luth sans tuer personne** — un instrument est un focus, pas une arme (1d4, pauvre 0,60), et une classe de soutien jouée seule par un robot qui ne compose que des sorts au hasard n'a rien pour tuer. C'est cohérent avec l'identité du barde ; c'est aussi la preuve que la matrice du robot mesure le **solo brut**, pas le jeu.
>
> Deux extrêmes qui méritaient un œil dans la première matrice (avec la lance) : **Le Sceau** ne prend aucun coup et descend (les glyphes tiennent les ennemis à distance) ; **L'Engrenage** prend cent dégâts pour un seul tué et meurt deux fois — il part avec une arme de tir et une tourelle, et le robot se bat probablement au contact avec. C'est peut-être le robot (il ne sait pas prendre de la distance), peut-être la classe. Consigné dans [[À juger — parcours de jeu]].

## Liens

- **Détaille** : [[À juger — parcours de jeu]], [[Vers la production]]
- **Mesure** : [[Stats d'armes]], [[Loot — affixes, gemmes et rareté]], [[Progression par l'usage]], [[IA des créatures]]
