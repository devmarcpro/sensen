---
aliases: ["3.5", "3.5 Donjons", "Donjons", "Donjon"]
tags: [monde, donjon, décidé]
domaine: monde
statut: décidé
etape: 2
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : chaque étage est une grille bornée indépendante ([[Grille continue]]) — le passage « volume de chunks » d'origine est conservé entre parenthèses dans le corps.

Les donjons sont une des sources principales de contenu du jeu, et le premier espace jouable à construire — une grille bornée ne nécessite aucune génération de monde.

**Rôle central :** les donjons sont une des sources principales de contenu du jeu — loot de tout type, **grimoires/manuels** (source première des modules de compétences, [[Grimoires et manuels]]), objectifs de quêtes de guilde ([[Quêtes et guildes]]/[[Gabarit de quête]]), trésors/artefacts ([[Trésors et artefacts]]), et terrain de combat pur. À développer en priorité.

**Génération à la Daggerfall — modulaire, en salles et connecteurs préfabriqués :**
- Un donjon est assemblé depuis une bibliothèque de **salles** (prefabs de grille — tailles petite/moyenne/grande/immense, formes variées, **jamais forcément planes** : le sol d'une salle utilise la hauteur de tuile ([[Hauteur de terrain ±10]]) pour ses estrades, fosses et gradins) et de **connecteurs** (corridors droits/coudés/en T, escaliers montants/descendants, portes, rampes).
- **Points d'attache** : des tuiles-marqueurs typées dans les prefabs indiquent où les pièces se branchent (porte nord/sud/est/ouest, cage d'escalier vers l'étage suivant).
- **Étages, verticalité réelle ("à étage")** : un donjon empile plusieurs niveaux reliés par des connecteurs escaliers — extension naturelle des chunks cubiques indexés `(x,y,z)` ([[Grille continue]]/[[Décisions d'architecture]]). Chaque étage a son propre graphe de salles, généré indépendamment.
- **Palette remapable** : les mêmes salles/connecteurs génériques servent tous les thèmes (ruine, crypte, mine effondrée, repaire...) via le remapping de couleurs stand-in déjà en place ([[Direction artistique]]/[[Squelette modulaire et points d'attache]]) — un petit nombre de prefabs, une grande variété visuelle.

**Génération (algorithme, détail technique en [[Génération de donjon]]) :** placement de l'entrée → extension par graphe (attacher connecteur + salle compatible à un point d'attache libre, répéter jusqu'au nombre de salles cible) → garantie de connexité → cage d'escalier vers l'étage suivant si applicable → salle spéciale (trésor/boss) au point le plus reculé de l'étage le plus profond.

**Taille et profondeur (alignées sur les foyers de [[Dérive de la corruption]]) :**
- **Donjon mineur :** 2-3 étages, 8-15 salles/étage.
- **Donjon majeur :** 5-8 étages, 15-25 salles/étage, salle boss unique au dernier étage.
- **Difficulté et loot croissent avec la profondeur** de l'étage (indépendamment de la corruption de surface de la cellule, formule [[Génération de donjon]]) : descendre est toujours un choix qui paie, quel que soit le danger ambiant de la région.

**Occupation de la cellule sur la carte du monde :**
- Le **terrain de surface** de la cellule où apparaît un donjon est remplacé par une structure d'entrée scellée (ruine effondrée, faille, gouffre, portail muré...) — non claimable ([[Claims et persistance]]), non cultivable ; le reste de la cellule est naturellement impraticable autour du point d'entrée unique.
- **Voyage rapide restreint au point d'entrée** : la carte du monde ne peut cibler que l'entrée — jamais un point arbitraire à l'intérieur (les étages empilés n'ont pas de représentation 2D unique). Une fois entré, exploration entièrement à pied, façon roguelike classique.
- Techniquement, chaque étage est une **grille bornée indépendante** ([[Grille continue]] : « grilles séparées en étages discrets », mêmes chunks de tuiles que la surface — [[Décision — Structure de données de la grille]]).

**Persistance et nettoyage (fixe, pas de repop avant nettoyage complet) :**
- Mobs et loot générés sont **fixes** : explorer un donjon, c'est le vider progressivement — aucune régénération interne tant qu'il n'est pas entièrement nettoyé (contrairement à la surface, [[Claims et persistance]]). Les changements (morts, butin pris, blocs détruits) suivent exactement la sauvegarde différentielle standard ([[Sauvegarde]]) : rien de nouveau à construire.
- **Nettoyage complet (boss vaincu) :** le donjon **disparaît et redevient une cellule normale**, mais reste dans son état exploré (loot restant accessible, structure intacte) pendant **1,5 jour in-game** — le temps que le joueur termine ce qu'il a à faire. Passé ce délai, la cellule régénère en terrain normal du biome environnant et devient claimable comme n'importe quelle case sauvage.

**Intégration aux systèmes existants :**
- **Quêtes de guilde ([[Quêtes et guildes]]/[[Gabarit de quête]]) :** nouveau pattern `donjon` — nettoyer ou atteindre le fond d'un donjon désigné (cohérent avec les gabarits par guilde déjà posés).
- **Grimoires/manuels ([[Grimoires et manuels]]) :** les donjons sont leur **source principale** (piédestaux, coffres, salles de bibliothèque thématiques).
- **Artefacts ([[Trésors et artefacts]]) :** réservés à la salle boss/trésor des donjons majeurs.
- **Créatures :** **humains hostiles** ([[Profils de PNJ]] : bandits, pillards, ermites) et **bêtes tanières** ([[Créatures]] : ours, loups) peuplent les salles selon le profil du donjon — un ermite en salle isolée profonde, une bande organisée dans les grandes salles d'un étage supérieur.

**Décisions :**
- **Après nettoyage complet : la cellule redevient normale et claimable après le délai de grâce de 1,5 jour** (ci-dessus) — pas de farm infini du même donjon, pas de disparition brutale non plus.
- **Pas de repop avant nettoyage complet** — explorer vide réellement le donjon, cohérent avec un vrai dungeon crawl plutôt qu'un spawn infini.

**Questions ouvertes :** [[Ouvert — Taille des salles de donjon]], [[Ouvert — Réapparition d'un donjon]].

> [!success] Codé le 2026-08-27 — contenants et butin
> Les salles reçoivent des **coffres** (une tuile de sol par tranche de 120 tuiles, +1 en salle du boss — `loot_rules.contenants`), remplis à la profondeur de l'étage par le générateur de loot ; contenus de tuile `coffre` / `butin` franchissables, ramassés par l'intention `ramasser` (R, 5 ticks) sur la tuile. À sa mort, un être lâche ce qu'il portait (équipement d'instance et sac) plus, pour le tout-venant, un objet avec 25 % de chance. Le loot et les mobs sont **fixes** : aucun repop, le sac et les contenants suivent l'état de la grille.

> [!success] Codé le 2026-08-27 — remonter, ressortir, étages fixes
> Chaque étage quitté est **mis de côté tel quel** (grille, êtres morts ou vivants, contenants) et revient dans cet état quand on y remonte — *pas de repop, explorer vide réellement le donjon*. La tuile d'entrée (verte) sert d'escalier montant ; à l'étage 1 elle est la **sortie** : l'expédition se termine (récapitulatif : étage max, tués, objets, boss, niveaux dérivés — signal `expedition_terminee`) et une nouvelle expédition commence avec le même être, son sac, ses niveaux et ses potentiels. La surface, le délai de grâce de 1,5 jour et la cellule qui redevient claimable attendent l'étape 8.

> [!success] Décidé le 2026-08-27 — un étage = une cellule
> Chaque étage tient dans **une cellule de 128×128** (la taille de cellule du monde, [[Grille continue]]) ; l'entrée en surface, à l'étape 8, occupera donc exactement une cellule de la carte. Deux escaliers par étage, un montant et un descendant ; le premier étage remonte vers la surface ([[Génération de donjon]]).

> [!success] Précisé le 2026-08-27 (soir)
> La cellule fait désormais 64×64 ([[Grille continue]]) : un étage = 64×64 tuiles, 4 à 8 salles procédurales.

> [!success] Précisé le 2026-08-28
> Retour à 128×128 par étage ([[Grille continue]]), 14 à 24 salles reliées en réseau maillé.

> [!success] Précisé le 2026-08-28 — le camp entre deux expéditions
> Sortir par l'escalier de l'étage 1 (`expedition_terminee`) **ramène au camp** ([[Claims et persistance]]) ; l'expédition suivante part de la tuile `entree_donjon` du camp (E), avec un nouvel id de donjon — un nouveau donjon à chaque fois, en attendant la surface et ses entrées.

> [!success] Codé le 2026-08-28 — les donjons de surface (8.3a)
> Une cellule à POI donjon porte une **entrée scellée** : la tuile `entree_donjon` entourée d'un anneau de roche ouvert au sud, posée hors de l'eau. Entrer (E) lance l'expédition dans le donjon **de cette cellule** (`id = hash(seed, cellule)`, thème selon le biome : `repaire` en marécage ou zone corrompue, `ruine` ailleurs) ; ressortir **ramène devant l'entrée** (`e.retour`), pas au camp. Le voyage rapide vers une cellule à donjon dépose au point d'entrée. La cellule reste claimable dans ce prototype (pas encore de claim au-delà du camp) ; le nettoyage, le délai de grâce et la réapparition viennent avec la corruption hebdomadaire (8.3b).

> [!success] Précisé le 2026-08-28 — nettoyage, grâce, réapparition (8.3b)
> Ressortir d'un donjon dont le boss est vaincu le marque **nettoyé** ([[Dérive de la corruption]]) ; il reste explorable **1,5 jour** (36 000 ticks) puis son **entrée disparaît** de la cellule (la roche de l'entrée scellée aussi) — la cellule redevient une cellule normale ; une réapparition tirée par la dérive la remet. Les étages nettoyés ne sont plus mis de côté après la grâce.

> [!success] Codé le 2026-09-01 — les donjons ne naissent plus que de la corruption (designer)
> « retire les entrées de donjons qui sont encore un peu partout ». Depuis le point 51, un donjon est un accident de corruption : un bruit qui dérive chaque jour, cristallise au-delà d'un seuil, prend l'élément de sa cellule et monte en niveau tant que personne ne le nettoie. Les **entrées scellées posées en POI** (6 % des cellules terrestres, héritées d'avant) doublaient ce système avec des donjons statiques que rien ne fait vivre. `planete.poi.donjon` passe à **0** : la cellule du camp garde la sienne (c'est le donjon d'apprentissage, `poi_de` la force), tout le reste vient de la corruption.


> [!success] Codé le 2026-09-01 — le camp n'a plus d'entrée de donjon (designer)
> « retire l'entrée de donjon du camp ». `poi_de` forçait encore `donjon = true` sur la cellule de départ : la dernière entrée scellée du monde. Elle disparaît — **plus aucun donjon n'est posé à la génération**, tous naissent de la corruption et s'atteignent en marchant sur leur cellule. Conséquence assumée : le cycle de *foyer* hérité des donjons de POI (repeuplement, générations, `_reposer_entree`) n'a plus de cellule à animer ; le code reste en place, inerte, plutôt que d'être arraché tant que la corruption n'a pas fait ses preuves à l'usage. **À juger** : le camp n'a plus de donjon à portée de pas — le premier donjon dépend maintenant du hasard de la corruption alentour ; faut-il garantir une cellule corrompue à quelques cases du départ ?


> [!success] Tranché le 2026-09-02 — un **gouffre** par région : infini, gratuit, et qui ne se régénère jamais (designer)
> « Chaque région a un donjon infini (donjon à paliers qui devient de plus en plus difficile plus le joueur descend) […] donjon infini gratuit, mais ne se régénère jamais. »
> J'avais posé la question du verrou d'accès — payer, ou avoir accompli quelque chose dans la région. La réponse tranche autrement, et mieux : **rien ne verrouille l'entrée, c'est la sortie qui coûte.** La profondeur est déjà la porte, elle est gratuite et elle ne se contourne pas ; ce qui empêche le gouffre de devenir une machine à farmer, ce n'est pas un péage, c'est qu'**un étage vidé le reste pour toujours**. On ne redescend pas chercher le même trésor : on descend plus bas, ou on ne descend plus.
> **Deux natures de donjon coexistent, et c'est voulu.** Les donjons de corruption sont des **événements** : ils naissent d'une corruption qui monte, ils infectent leurs voisines, on les vide pour changer la carte, et ils disparaissent quand leur boss tombe ([[Dérive de la corruption]]). Le gouffre est un **lieu permanent** : il ne change rien au monde, il mesure le joueur, et son butin monte avec la profondeur. Le gouffre n'est donc jamais un foyer — il ne s'éteint pas, ne se repeuple pas, n'infecte rien.
> **Ce que « ne se régénère jamais » veut dire dans le code** (mon choix d'implémentation, à corriger si ce n'est pas l'intention) : le terrain d'un étage se régénère de sa graine, comme aujourd'hui — il est déterministe, le stocker ne servirait à rien. Ce qui ne revient pas, ce sont **les êtres et le butin** : la partie retient les étages déjà vidés, et un étage déjà vidé se regénère désert. Redescendre est donc rapide et sans danger jusqu'à sa profondeur record, ce qui rend inutile tout raccourci payant — la question du prix du raccourci tombe d'elle-même.

> [!success] Tranché le 2026-09-02 — **le gouffre ne donne pas de butin unique** (designer)
> « Pas de butin unique pour le gouffre. » Il donne de la quantité et de la qualité qui montent avec la profondeur, rien qu'on ne puisse trouver ailleurs. L'unique reste aux **donjons de corruption**, ce qui leur garde une raison d'exister : le gouffre mesure le joueur, les donjons de corruption récompensent celui qui change la carte. Sans cette séparation, le gouffre — permanent, gratuit, toujours là — aurait rendu les donjons de corruption inutiles.

## Liens
- **Dépend de** : [[Grille continue]], [[Hauteur de terrain ±10]], [[Décisions fondatrices]]
- **Alimente** : [[Génération de donjon]], [[Salles et connecteurs]], [[Loot — affixes, gemmes et rareté]], [[Trésors et artefacts]], [[Grimoires et manuels]]
- **Voir aussi** : [[Dérive de la corruption]], [[Claims et persistance]], [[Minimap et brouillard de guerre]], [[Ouvert — Taille des salles de donjon]], [[Ouvert — Réapparition d'un donjon]]
