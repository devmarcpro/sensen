---
aliases: ["Vocabulaire", "Glossaire", "Lexique", "De quoi on parle"]
tags: [index, décidé]
domaine: index
statut: décidé
etape: 0
---

**Un mot, une chose.** Quand un mot du projet désigne deux choses, on le dit ici et on tranche lequel garde le mot.

Cette note est née le 2026-09-08 d'une demande du designer — « il faudra rédiger un document vocabulaire pour qu'on
puisse savoir de quoi on parle, comme pour *bruit* ». Elle n'est pas théorique : **six collisions ont été heurtées dans
la seule journée du 8 septembre**, dont une qui bloque encore un chantier.

**La règle** : un mot déjà pris ne se reprend pas. Si un chantier neuf a besoin d'un mot occupé, **c'est le chantier
neuf qui change de mot** — jamais le code existant, qui est plus coûteux à renommer et plus risqué à relire.

---

## Les collisions, et ce qu'on a tranché

| Le mot | Ce qu'il désigne déjà | Ce qui le voulait aussi | Tranché |
|---|---|---|---|
| **bruit** | Le **bruit de Perlin** — `FastNoiseLite`, les huit couches de `noise_layers.json`, `monde.surface.bruits`. Le mot est partout dans la génération. | Ce qui s'entend : une porte, un combat, une forge, un éboulement. | **TRANCHÉ le 2026-09-09 par le designer : le champ s'appelle `sonore`.** Le bruit de Perlin garde `bruit` ; ce qui s'entend prend `sonore` — `carte_sonore`, `sonore_a`, `sonner()`. Le mot était **libre** : deux occurrences dans tout le code, et ce sont deux commentaires sur « l'onde sonore » du barde, donc une future *source* du champ, pas une collision. Écarté au passage : `son`, techniquement libre comme identifiant mais présent **367 fois en prose** — c'est le possessif français, et tout `grep son` serait illisible. *Un mot qu'on ne peut pas chercher est un mot pris.* |
| **absorption** | Un **noyau de sort** (`data/modules/noyau/defense/absorption.json`). | La **stat de matière** qui dira ce qu'une matière étouffe du son. | Le module **meurt** avec les 236 contenus ; la stat prend le mot. Mais **tout `grep absorption` est ambigu tant que les deux coexistent**. |
| **inertie** | Rien, jusqu'au 2026-09-08. | Deux choses à la fois : la **masse thermique** (une matière dense met du temps à changer de température) et la **quantité de mouvement** (un rocher lancé, lâché d'un étage, ou poussé par un moteur). | **Les deux gardent le mot, qualifié** : *inertie thermique* (codée) et *inertie mécanique* (en file). Ne jamais écrire « inertie » seul. |
| **densité** | Une **stat de matière** qui commande le **poids porté** et la **vitesse d'arme** (un manche dense frappe plus lentement). | La masse thermique du champ de chaleur, plus trois homonymes sans rapport : `filons.densite` (la fréquence des filons), `faune_densite` (la population animale d'une cellule), `densite_mana` (la charge magique d'une tuile). | **La stat de matière garde le mot.** Les trois autres sont des **fréquences**, pas des masses : les lire comme des densités de matière est une faute. |
| **zone** | Deux choses **déjà** en collision dans le code : `sim.zones` = les **nuages** (gaz, feu, sol vif) qui expirent, et `regles.r.zones` = les **zones du corps** (tête, torse, bras, jambes, pieds). | La *forme de zone* d'un sort (ligne, cône, croix, carré, anneau) est encore un troisième sens. | **Rien n'est tranché, et c'est la collision la plus ancienne.** Proposition : *nuage* pour le premier, *zone du corps* ou *membre* pour le second, *forme* pour le troisième (le mot existe déjà dans la grammaire des modules). |
| **champ** | Un **champ partagé** au sens de l'émergence (chaleur, lumière, bruit, danger) — le mot central de [[Émergence — les champs partagés]]. | Un **champ de culture** (`villes.json → champs`, le périmètre agricole d'un village). | **Les deux gardent le mot** : le contexte suffit (un champ *partagé* n'est jamais un champ *de blé*). À surveiller si un système agricole devient un champ au sens émergent. |
| **module** | Deux sens **également installés** : un **module de sort** (les 236 contenus de `data/modules/`, voués à mourir) et un **module de la simulation** (les fichiers `sim_*.gd`, voir [[Modules de la simulation et le C++]]). | — | **Les deux restent**, mais on écrit toujours *module de sort* ou *module de code*. Jamais « module » seul dans une note. |
| **palier** | Trois sens : le **palier d'un matériau** (1 à 5, ce qui commande où il tombe), les **paliers de qualité d'artisanat** (huit crans, de commun à mythique), et les **paliers de l'[[Ordre de travail]]** (les étapes du chantier). | — | Contexte suffisant, mais **toujours qualifier** : *palier de matière*, *palier de qualité*, *palier du chantier*. |
| **niveau** | Le **niveau d'une compétence** (0-100), l'**étage** d'un donjon, le `niveau_liquide` d'une tuile (0-8), le `niveau_construction` d'une pièce d'armure. | — | **L'étage se dit « étage »**, jamais « niveau ». Les trois autres se qualifient. |

## Le vocabulaire du monde

- **Cellule** — un carré de 64 × 64 tuiles du monde. Le monde en compte 1024 × 1024. C'est l'unité de la carte, du voyage et des passages hebdomadaires.
- **Tuile** — la case. L'unité de la grille, du déplacement et de tous les champs.
- **Fenêtre** — les 3 × 3 cellules chargées autour du joueur. Ce qui est *dans* la fenêtre existe en tuiles ; le reste existe en données.
- **Couche Z** — un étage, encodé dans la coordonnée `y` par bandes. Un bâtiment à étages, une mine, un gouffre.
- **Secteur** — un carré de 32 × 32 cellules, l'unité de génération des royaumes. À ne pas confondre avec le **secteur d'un écran** (le groupe de lignes surligné, que Tab fait défiler).
- **Région** — un Voronoï jitteré au pas de 24 cellules ; chacune porte sa culture et son nom.
- **Continent** — des plaques continentales voisines réunies par union-find.

## Le vocabulaire des lieux

- **Camp** — la surface. Le monde ouvert, l'horloge en temps réel.
- **Donjon** — un lieu à étages engendré d'une graine. L'horloge y passe **à l'action**.
- **Mine** — un donjon **sans salles** : un bloc de roche pleine qu'on creuse, avec une chambre d'arrivée. Ce qu'on y ouvre reste ouvert.
- **Gouffre** — un donjon **sans fond** : on descend jusqu'à mourir, et chaque étage vidé le reste.
- **Donjon de corruption** — celui qui naît d'un foyer de corruption qui cristallise, et qui disparaît quand on l'a vaincu.
- **Arène** — les lieux de test, hors jeu.

## Le vocabulaire du temps

- **Tick** — l'unité de temps de la simulation. Toute action coûte des ticks.
- **Horloge du monde** — celle du camp, en **temps réel** ; en donjon elle passe **à l'action** (elle n'avance que quand quelqu'un agit).
- **Horloge de combat** — une par combat, toujours à l'action. Pendant un combat, le reste de l'étage attend.
- **Passage hebdomadaire** — ce qui fait vivre le monde hors écran : production, prix, naissances, royaumes, guerres.

## Le vocabulaire de l'émergence

- **Champ partagé** — une donnée par tuile que **plusieurs systèmes lisent**. C'est le mot central : un champ nouveau doit **remplacer** les règles ad hoc qui l'imitaient, jamais s'ajouter à côté.
- **Source** / **puits** — ce qui écrit dans un champ, ce qui l'épuise.
- **Incrémental** — un champ qui ne recalcule que ce qui a changé. La chaleur l'est ; la lumière ne l'est pas encore.
- **Modulation** — ce que devient un module de sort : il ne produit plus d'effet, il **tourne un bouton d'une règle du monde**.

## Liens
- **Dépend de** : [[Décisions fondatrices]]
- **Alimente** : [[Émergence — les champs partagés]], [[Décisions en attente]], [[Ordre de travail]]
- **Voir aussi** : [[Grille continue]], [[Modules de la simulation et le C++]], [[Matériaux — 13 stats]]
