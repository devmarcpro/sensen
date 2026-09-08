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
| 6 | **Est-ce que ça vaut pour tout le monde ?** Les cinq zones humanoïdes ne vont ni à un loup, ni à un essaim, ni à une calèche. Faut-il des silhouettes par squelette ? | idem | [[Combat tactique sur grille]] |
| 7 | **Le sens de la vérité des catalogues.** La note redevient-elle la source (il faut alors valider à la main les lignes reversées et les chiffres étirés), ou la donnée devient-elle la source et la note son reflet ? **Tant que ce n'est pas tranché, les tables réalignées rederiveront au prochain équilibrage.** | Tout chantier matériaux durable | [[Matériaux — 13 stats]] |
| 8 | **Les champs avant ou après le jeu fini ?** Le designer a tranché l'ordre *des six champs entre eux*, pas leur place par rapport à la pause, la mort et les touches — celles-ci sont faites depuis, la question porte donc maintenant sur la suite du palier 3 et la sauvegarde. | L'ordre des paliers 5 à 7 | [[Émergence — les champs partagés]] |
| 9 | **Le nom du champ sonore.** Il ne peut pas s'appeler `bruit` : le mot désigne déjà le bruit de Perlin partout dans le code. | La **première ligne** du champ sonore | [[Ordre de travail]] |
| 10 | **Faut-il une relève de garnison ?** Un repeuplement qui puisse rendre un garde. **Sans elle, l'équipement qui suit le stock d'une ville ne peut mordre sur personne** — un garde n'est jamais ré-équipé. | La ligne 32 bis, déjà réfutée sous sa forme initiale | [[Ordre de travail]] |

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
| 19 | **Les arbres fruitiers hauts** : un verger est un buisson aujourd'hui ; un pommier devrait-il bloquer la vue, et passe-t-on dessous ? | [[Agriculture et élevage]] |

## Ce qui n'est pas une décision mais un choix de contenu

| # | | |
|---|---|---|
| 20 | **Le son.** Zéro fichier audio, zéro `AudioStreamPlayer` dans tout le projet. Je peux poser l'architecture (bus, événements → sons, ambiance par biome et par heure) ; **les sons eux-mêmes sont un choix du designer**. C'est l'absence la plus criante à l'écran. | [[Ordre de travail]], palier 13 |
| 21 | **La difficulté de départ** : le robot meurt aux étages 1 et 2 avec le kit complet. **Jugeable dès maintenant** — la pause et l'écran de mort existent depuis le 2026-09-08. | [[À juger — parcours de jeu]] |

## Liens
- **Dépend de** : [[Vers la production]], [[Ordre de travail]]
- **Voir aussi** : [[À juger — parcours de jeu]] (ce qui se juge à l'œil, en jouant), [[Émergence — les champs partagés]], [[Émergence — le monde vivant]]
