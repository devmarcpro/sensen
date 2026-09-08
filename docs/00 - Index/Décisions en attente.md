---
aliases: ["Décisions en attente", "Ce que je dois trancher", "Décisions bloquantes"]
tags: [index, production, ouvert]
domaine: index
statut: ouvert
etape: 12
---

**Tout ce qui attend une décision du designer et qui bloque du code.** Une seule liste, tenue à jour à chaque fois
qu'une question sort d'un chantier.

Cette note est née le 2026-09-08 d'une question du designer — « tu notes toujours toutes les décisions à prendre, n'est-ce
pas ? ». La vérification a répondu **oui, mais mal** : 56 questions dormaient dans **20 notes différentes**, chacune à
l'endroit où elle était née. Elles étaient traçables et personne ne pouvait les lire d'un coup.

**Ce que cette note NE contient pas** : ce qui se juge **à l'œil, en jouant** — la lisibilité, le rythme, le plaisir,
la difficulté ressentie. Ça a déjà son parcours d'une heure dans [[À juger — parcours de jeu]] (22 questions). Ici, il
n'y a que ce dont j'ai besoin **pour écrire du code juste**.

**Comment répondre** : une phrase suffit. J'écris le callout daté dans la note concernée et je code derrière.

---

## Ce qui bloque un chantier en cours

| # | La question | Ce qu'elle bloque | Où elle est née |
|---|---|---|---|
| 1 | **Le grain de la vitesse.** Une grille à ticks n'a pas de vélocité continue : un corps avance de N tuiles par tick, ou d'une tuile toutes les N ticks. Combien de crans entre la flèche et le rocher ? | L'**inertie mécanique** (ligne 27 bis de l'[[Ordre de travail]]), donc la réécriture des modules qui en dépend | [[Émergence — les champs partagés]] |
| 2 | **Jusqu'où va le recul.** Un corps poussé pousse-t-il à son tour ce qu'il heurte (chaîne de collisions), ou s'arrête-t-il au premier obstacle ? | idem | [[Émergence — les champs partagés]] |
| 3 | **Le joueur est-il un corps ?** Une charge qui emporte au-delà de la cible, un personnage lourd plus lent à changer de direction. **C'est le plus intrusif : ça touche les contrôles.** | idem, et le ressenti du déplacement | [[Émergence — les champs partagés]] |
| 4 | **Le grain des membres.** Une intégrité par zone (0-100), ou des blessures nommées qu'on accumule (entaille, fracture, brûlure, hémorragie) ? | Les **membres simulés** | [[Combat tactique sur grille]] |
| 5 | **Jusqu'où va l'irréversible.** Un membre peut-il être perdu pour de bon — le joueur peut-il finir manchot pour le reste de la partie ? | idem | [[Combat tactique sur grille]] |
| 6 | ~~Est-ce que ça vaut pour tout le monde ?~~ **TRANCHÉ le 2026-09-08 par l'élargissement du designer** : le corps devient un **plan de parties en données**, un par créature — `silhouette` en devient l'ancêtre. | — | [[Combat tactique sur grille]] |
| 6 bis | **Les emplacements d'équipement doivent dériver du corps.** C'est le point structurel de l'anatomie : `e.equipement` a des clés **fixes** aujourd'hui. Perdre un bras doit retirer un emplacement, en gagner un doit en ajouter. Faut-il y aller, sachant que c'est le chantier le plus intrusif en file (le paperdoll dessine par emplacement, et la suite entière suppose des emplacements fixes) ? | Toute l'anatomie | [[Combat tactique sur grille]] |
| 6 ter | **Le budget de place interne.** « Plusieurs estomacs = manger plus mais demande plus de place » introduit une **contenance du corps** qui n'existe nulle part. Quelle en est l'unité, et qu'est-ce qui la consomme — les organes seuls, ou aussi les greffes et les membres surnuméraires ? | Les organes | [[Combat tactique sur grille]] |
| 7 | **Le sens de la vérité des catalogues.** La note redevient-elle la source (il faut alors valider à la main les lignes reversées et les chiffres étirés), ou la donnée devient-elle la source et la note son reflet ? **Tant que ce n'est pas tranché, les tables réalignées rederiveront au prochain équilibrage.** | Tout chantier matériaux durable | [[Matériaux — 13 stats]] |
| 8 | **Les champs avant ou après le jeu fini ?** Le designer a tranché l'ordre *des six champs entre eux*, pas leur place par rapport à la pause, la mort et les touches — celles-ci sont faites depuis, la question porte donc maintenant sur la suite du palier 3 et la sauvegarde. | L'ordre des paliers 5 à 7 | [[Émergence — les champs partagés]] |
| 9 | **Le nom du champ sonore.** Il ne peut pas s'appeler `bruit` : le mot désigne déjà le bruit de Perlin partout dans le code. *Candidats : son, vacarme, rumeur sonore.* Voir [[Vocabulaire]]. | La **première ligne** du champ sonore | [[Ordre de travail]] |
| 10 | **Faut-il une relève de garnison ?** Un repeuplement qui puisse rendre un garde. **Sans elle, l'équipement qui suit le stock d'une ville ne peut mordre sur personne** — un garde n'est jamais ré-équipé. | La ligne 32 bis, déjà réfutée sous sa forme initiale | [[Ordre de travail]] |

| 10 bis | ~~Le champ de vue du joueur doit-il être séparé de la portée de détection d'une IA ?~~ **FAIT le 2026-09-08 sur carte blanche du designer** : `vision.joueur_base` = 18 + Perception. A/B à graine fixe : la pire image passe de 46,1 à 36,6 ms. | — | [[Budgets de performance]] |
| 10 ter | **L'intensité du grain du décor.** Posée à 0,26 / 0,15 le 2026-09-08 (elle était à 0,12 / 0,07, donc invisible ; un essai à 0,38 / 0,22 grouillait). C'est de la **direction artistique** et une ligne de données — deux captures de comparaison ont été envoyées au designer. | La lisibilité du décor | [[Budgets de performance]] |

| 11 | **Un tick doit-il valoir 10 ms au lieu de 100 ?** *(question du designer, 2026-09-08 : « je pense que ça serait mieux de faire en sorte que 1 tick soit équivalent à 10 millisecondes non ? »)* **Mon avis : oui, et pour une raison précise** — le temps à l'action ne sait pas exprimer une différence de vitesse plus fine que 10 %. Une frappe coûte 5 ticks ; deux combattants dont l'un est 10 % plus rapide se départagent sur **0,5 tick**, qui s'arrondit à 0 ou à 1, soit 20 % d'écart réel. À 100 ticks/s la même frappe vaut 50 ticks et les 10 % se disent exactement. **Ce n'est pas un changement de rythme mais d'unité** : il faut multiplier par dix **tous** les coûts en ticks des données, sinon le monde tourne dix fois plus vite. **Le coût processeur ne bouge pas** (la file des compteurs ne réveille que ce qui est dû ; dix fois plus de pas, dix fois moins d'êtres par pas). **Les trois risques** : les sauvegardes existantes portent des compteurs en ticks ; tout nombre de ticks écrit en dur dans le code échapperait au balayage ; et une trentaine de tests affirment des valeurs exactes (« le monde a avancé de 8 000 ticks »). **À faire d'un coup, avec un test qui prouve qu'un jour dure toujours un jour** — pas au fil de l'eau. | Le temps à l'action, toute la donnée de combat | [[Simulation à ticks]] |
| 12 | **La hache de départ ne peut pas abattre un chêne, et c'est peut-être voulu.** Le chêne est de palier 3 (dureté 16) : il exige un outil de dureté **10**, une hache de départ en vaut **~7**. Le bouleau (8, palier 2, seuil 4,4) et le pin (4, palier 1, seuil 2) passent. *Trouvé le 2026-09-08 parce qu'un test abattait un chêne et **passait par chance** — la matière de la tête de hache est tirée au sort, et le moindre décalage du tirage le faisait rebondir.* **La question n'est pas le test** (corrigé, il abat un bouleau) **mais le début de partie** : est-ce que le joueur doit comprendre tout seul que le chêne lui résiste, ou est-ce que le coffre de départ doit contenir une hache dont la matière est **fixée** plutôt que tirée ? | Le début de partie, la lisibilité de la récolte | [[Récolte]] |

## Ce que le designer a réservé pour plus tard

| # | La question | État |
|---|---|---|
| 11 | **Refondre l'exploration et la génération du monde** — « plus Caves of Qud / Dwarf Fortress que JRPG classique / Elin / Elona ». | **Réservé le 2026-09-08** : « on en reparle plus tard ». Rien n'est engagé. Observation gardée pour ce moment-là : le substrat est déjà de ce côté (grille continue, tectonique à plaques, seuil de mer calibré) ; c'est la **couche d'exploration** qui est Elona, et six des huit couches de bruit qui restent libres. |
| 12 | **Le voyage à la Fallout 1** : que voit-on pendant le trajet (la carte du monde, ou le terrain qui défile) ? Qu'est-ce qui interrompt ? Reprend-on un trajet interrompu, à quel prix ? Les rencontres se tirent-elles par cellule ou se pondèrent-elles par le champ de danger ? | **Suspendu à la question 11** : un trajet cellule par cellule sur un écran de carte est une amélioration *dans* le modèle Elona ; si le modèle change, elle devient sans objet. |

## Ce qui dormait dans le coffre, parfois depuis longtemps

| # | La question | Où elle est née |
|---|---|---|
| 13 | **La résolution interne du pixel art.** Le designer aime le rendu pixelisé des captures — mais ces images sont des agrandissements au plus proche voisin, pas le rendu du jeu. L'obtenir vraiment demande un `SubViewport` à 480 × 270 ou 640 × 360 agrandi au plein écran : **tout devient du pixel art, l'interface comprise**, et le texte du HUD devient illisible sous 480 de large. | [[Vers la production]] (2026-09-01) |
| 14 | **La matrice 5 × 3 des noyaux de dégâts** : la garder (chaque case est une munition à collectionner), la réduire à trois noyaux paramétrés par l'élément, ou différencier les paliers autrement que par le dé ? *(À revoir avec la réécriture des modules, qui la rend peut-être caduque.)* | [[Modules]] |
| 15 | **La Règle d'anneau** : 40/40/20, ou une autre définition du hasard ? Elle est mesurée à ×5,7 au lieu de ×15. | [[Règle d'anneau]] |
| 16 | **Tuer une bête paisible a-t-il un prix ?** (réputation, raréfaction, faim des prédateurs) Et la faune **se reproduit**-elle, ou repeuple-t-elle par génération comme les villages ? | [[Vers la production]] |
| 17 | **L'IA des créatures** : l'aggro se transmet-elle entre êtres du même camp (une meute réagit ensemble) ou reste-t-elle individuelle ? Un être désengage-t-il quand le joueur s'éloigne, ou poursuit-il indéfiniment ? Le roam suit-il une patrouille fixe ou une marche au hasard ? | [[Vers la production]] |
| 18 | **Le sac du joueur pourrit-il ?** Décision de confort : une horloge de péremption par objet porté. | [[Économie — sources et puits]] |
| 19 bis | **`sous_sol.json` : collection ou configuration ?** Eau, géodes, magma — trois *sortes de poche* avec leur réglage. Les gaz, eux, sont passés en catalogue le 2026-09-08 (un fichier par entrée) parce que ce sont clairement quinze contenus ; celui-ci est à la frontière. | [[Décision — Pipeline de contenu]] |
| 19 | **Les arbres fruitiers hauts** : un verger est un buisson aujourd'hui ; un pommier devrait-il bloquer la vue, et passe-t-on dessous ? | [[Agriculture et élevage]] |

## Ce qui n'est pas une décision mais un choix de contenu

| # | | |
|---|---|---|
| 20 | **Le son.** Zéro fichier audio, zéro `AudioStreamPlayer` dans tout le projet. Je peux poser l'architecture (bus, événements → sons, ambiance par biome et par heure) ; **les sons eux-mêmes sont un choix du designer**. C'est l'absence la plus criante à l'écran. | [[Ordre de travail]], palier 13 |
| 21 | **La difficulté de départ** : le robot meurt aux étages 1 et 2 avec le kit complet. **Jugeable dès maintenant** — la pause et l'écran de mort existent depuis le 2026-09-08. | [[À juger — parcours de jeu]] |

## Liens
- **Dépend de** : [[Vers la production]], [[Ordre de travail]]
- **Voir aussi** : [[À juger — parcours de jeu]] (ce qui se juge à l'œil, en jouant), [[Émergence — les champs partagés]], [[Émergence — le monde vivant]]
