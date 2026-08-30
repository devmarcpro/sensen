---
aliases: ["3.2", "3.2 Structure du monde", "Grille continue", "Tuile chunk cellule"]
tags: [monde, structure, décidé]
domaine: monde
statut: décidé
etape: 8
---

Une seule grille finie et continue, sans écran de chargement, à quatre échelles emboîtées.

Une seule **grille de tuiles**, sans écran de chargement ni transition de zone — mais **bornée** ([[Décision — Monde fini, continents et océan]]). Quatre échelles s'emboîtent :

**tuile** → **chunk** (32×32 tuiles, unité de génération et de streaming) → **cellule** (128×128 tuiles, unité de la carte du monde, du claim et du zonage) → **secteur** (64×64 cellules, unité de génération politique).

**Le monde entier fait 16×16 secteurs**, soit 1024×1024 cellules ou 131 072 tuiles de côté. Toutes les coordonnées sont donc bornées : un identifiant de cellule tient dans un `u32`, et la sauvegarde a une taille maximale connue.

Chaque tuile porte : une **hauteur entière** (0-20, voir [[Hauteur de terrain ±10]]), un **matériau de sol**, un **contenu** éventuel (mur, arbre, filon, meuble, empreinte de bâtiment) et un **occupant** éventuel (créature). Structure plate, lisible, sérialisable.

- **Fini ne veut pas dire découpé.** Le monde est borné, mais il reste **une seule grille sans couture** : on traverse un continent entier à pied sans un seul chargement. La limite du monde n'est pas un mur, c'est un océan profond ([[Décision — Monde fini, continents et océan]]).
- **Continuité réelle** : on marche d'une cellule à l'autre sans rupture ; les chunks se génèrent devant et se déchargent derrière. La carte du monde reste un **résumé** du même champ de bruit ([[Unification macro-micro]]) — le voyage rapide est un raccourci par-dessus un monde qui existe vraiment.
- **Pas de volume souterrain.** Le souterrain n'existe plus comme espace continu : il devient les **donjons**, grilles séparées en étages discrets reliés par des escaliers ([[Donjons — structure et intégration]]). Les ressources minérales se récoltent en **filons de surface** (façon Elin), pas en creusant des tunnels — le minage exploratoire est explicitement écarté.
- **Gain technique** : plus de meshing volumétrique, plus de LOD 3D, plus de streaming en volume, plus de propagation de lumière en 3D. Le rendu est : tuiles instanciées teintées par matériau + billboards triés en profondeur.

*Note d'architecture : les chunks sont indexés en 3D `(x, y, z)` dès le premier jour — voir [[Décisions d'architecture]] et [[Décision — Structure de données de la grille]].*

> [!success] Décidé le 2026-08-27 — la cellule fait 64×64 (instruction du designer)
> « Je veux que les cellules soient de 64×64. » La cellule passe de 128×128 à **64×64 tuiles** ; un chunk de 32×32 = un quart de cellule. Le monde (16×16 secteurs de 64×64 cellules) fait donc 65 536 tuiles de côté. Les mentions de 128 dans [[Décision — Monde fini, continents et océan]] et [[Unification macro-micro]] sont remplacées par ce callout. Un étage de donjon = une cellule ([[Génération de donjon]]).

> [!success] Décidé le 2026-08-28 — retour à la cellule de 128×128 (instruction du designer)
> « On va repasser à 128 tuiles par cellule. » La cellule redevient **128×128** ; le callout du 2026-08-27 (64×64) est annulé, la note d'origine et [[Décision — Monde fini, continents et océan]] redeviennent exactes. Un étage de donjon = une cellule de 128×128.

> [!success] Codé le 2026-08-28 — étape 8.2a : la fenêtre glissante (`systems/worldgen/monde.gd`)
> La grille active est une **fenêtre de 3×3 cellules** (384×384 tuiles) autour de la cellule du joueur, en **coordonnées monde** (`Grille.origine`) : quand le joueur change de cellule, la fenêtre se recentre sans qu'aucune position ne bouge ; les cellules sont **générées à la demande et mises en cache**, les voisines **pré-générées en thread** ; ce qui n'est pas regénérable est **capturé par cellule** — tuiles modifiées (`Grille.modifies`, marquées à chaque mutation), tuiles découvertes, contenants, êtres endormis hors fenêtre (« seed + liste des modifications », [[Sauvegarde]]). Les cellules ne se touchent par aucune couture : plus de bord de roche en surface. **Décision** : rayon 1 (3×3) plutôt que les 8 chunks de la note — c'est la fenêtre de rendu (rayon 20 tuiles) qui coûte, pas la grille ; on élargira au profilage. Les chunks 32×32 SoA de [[Décision — Structure de données de la grille]] restent la cible de la sauvegarde ; la grille garde ses tableaux compacts (`PackedByteArray`, `PackedInt32Array`).

> [!success] Décidé et codé le 2026-08-30 — un **temps de chargement** entre les cellules, en exploration
> **Instruction du designer** : « temps de chargement entre chaque cellule en mode exploration ». Jusqu'ici la fenêtre se recentrait **à la volée** au pas qui franchit la cellule (génération synchrone dans `_verifier_fenetre`, puis reconstruction du client sur `fenetre_recentree`) — un à-coup de 150–300 ms au milieu d'un pas, sans rien pour le dire. Désormais, quand la fenêtre se recentre **au camp** (jamais en donjon : un étage est une seule cellule), le client **ouvre un écran de chargement** : fond noir, la cellule d'arrivée et son biome, une barre ; l'**horloge du monde est mise en pause** (`Horloge.active`) et l'entrée est ignorée pendant `planete.monde.chargement_s` (0,6 s) — et ce temps est **utilisé** : chaque image de l'écran de chargement pré-génère une cellule voisine manquante (`pregenerer_voisins`), si bien qu'à la sortie, les huit voisines sont prêtes et la traversée suivante ne coûte plus que le recentrage. **Décisions** : la durée est un minimum (l'écran ne se ferme pas avant), pas un maximum — si une cellule est lente à générer, l'écran reste ; le monde est **en pause** pendant l'écran (la faim, la météo, les PNJ n'avancent pas — c'est un temps de chargement, pas une ellipse) ; le donjon n'en a pas, la descente d'étage ayant déjà son propre passage.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Unification macro-micro]]
- **Alimente** : [[Décision — Monde fini, continents et océan]], [[Hauteur de terrain ±10]], [[Carte du monde]], [[Claims et persistance]], [[Donjons — structure et intégration]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Décisions d'architecture]], [[Décision — Structure de données de la grille]], [[Sauvegarde]], [[Risques majeurs]]
