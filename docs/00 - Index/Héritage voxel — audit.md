---
aliases: ["Héritage voxel", "Audit voxel", "Héritage voxel — audit"]
tags: [index, héritage-voxel, à-trancher]
domaine: index
statut: à-trancher
etape: 0
---

L'en-tête du GDD acte le pivot tactique (2026-08-09), mais les annexes D, E et G n'ont jamais été réécrites : elles décrivent encore le moteur voxel première personne. Cet audit a classé tout ce qui était contaminé, et documente le nettoyage. Seules les 8 propositions et cette note portent encore le tag `héritage-voxel`.

**Règle de lecture :** en cas de conflit, **le pivot fait foi** ([[Décisions fondatrices]] — décision irrévocable) : vue isométrique sur grille, tuile = hauteur entière 0-20 + matériau + contenu + occupant ([[Grille continue]]), personnages en billboards paperdoll 2D, donjons en étages discrets, filons de surface, pas de volume souterrain.

---

## État d'avancement (2026-08-26)

- **Catégorie 1 : réécrite ✅** — version grille en place ; le texte voxel d'origine est **retiré** (archivé dans `archive/SENSEN_GDD.md` et l'historique git).
- **Catégorie 3 : appliquée ✅** — vocabulaire converti (blocs→tuiles, voxels→pixels, .vox→sprites) directement dans les notes.
- **Catégorie 2 : notes adaptées, chiffres en attente de validation** — chaque conflit a sa proposition dans `99 - Ouvert/` : [[Décision — Altitude sur 21 niveaux]] · [[Décision — Structure de données de la grille]] · [[Décision — Minerais et strates après le pivot]] · [[Décision — Pièces en 2D]] · [[Décision — Sculpture en pixel art]] · [[Décision — Prefabs de donjon en tuiles]] · [[Décision — Budgets et critères de performance tactiques]] · [[Décision — Minimap en 2D]]. Les notes concernées intègrent déjà la version grille, avec les valeurs marquées « proposé » — **valider (ou amender) les 8 propositions clôt définitivement l'héritage voxel.**
- **Contenu voxel retiré du coffre** le 2026-08-26 sur décision du designer — la note purement historique *Voxels — mémoire et meshing* (G.2) est supprimée, ses alias repris par [[Décision — Structure de données de la grille]]. Tout l'original reste lisible dans `archive/SENSEN_GDD.md`.

---

## Catégorie 1 — Déjà tranché par le pivot, texte pas encore réécrit

Le GDD post-pivot donne le remplacement ; la note contenait encore l'ancien système. **Réécrit le 2026-08-26** — le texte voxel survit en annexe historique dans chaque note.

| Note | Ce qui est obsolète | Ce que le pivot dit |
|---|---|---|
| [[Décision — Structure de données de la grille]] | stockage 3D, octrees, subdivision, greedy meshing, LOD 3D — **intégralement** | [[Grille continue]] : « plus de meshing volumétrique, plus de LOD 3D, plus de streaming en volume » — rendu = tuiles instanciées teintées + billboards triés |
| [[Éclairage]] | flood fill 3D, skylight par colonne | [[Risques majeurs]] : propagation **2D sur la grille** ; la modulation jour/nuit en shader survit |
| [[Détection de pièces]] | flood fill **3D**, limite 4 096 blocs | [[Construction cadrée]] : « triviale en 2D » — empreinte de tuiles + hauteur de murs |
| [[Eau et liquides]] | automate par blocs 3D, clause subdivision | [[Hauteur de terrain ±10]] : « E.22 se simplifie en **2D + hauteur** au lieu d'un volume » |
| [[Éditeur de sculpture]] | mini-espace **voxel**, périmètres 16³→64×64×96, subdivision | [[Construction cadrée]]/[[Tables de sculpture]] : sculpture en **pixel art paramétrique** |
| [[Tables de sculpture]] | « voxel par voxel », pondération voxel | idem — le déroulé (fonctionnalité → éditeur → stats auto → modèle réutilisable) survit tel quel |
| [[Donjons — structure et intégration]] | « l'intérieur occupe le volume de chunks sous/autour de la cellule » | [[Grille continue]] : les donjons sont des **grilles séparées en étages discrets** reliés par escaliers |
| [[IA des créatures]] | pathfinding « voxel 3D » : 2 blocs d'air au-dessus, liens de saut/chute | la traversabilité découle des règles de dénivelé de [[Hauteur de terrain ±10]] (+1/+2 franchissable, ±3 non, chute avec dégâts) |
| [[Squelette modulaire et points d'attache]] | vocabulaire .vox dans les Décisions | la note l'acte elle-même : *pipeline identique, en 2D* — marqueurs et couleurs réservées s'appliquent aux **sprites** |

## Catégorie 2 — Invalidé par le pivot, remplacement à décider

L'ancien système ne tient plus, et le GDD ne dit pas ce qui le remplace. **Chaque ligne a désormais sa proposition à valider** (liens dans l'état d'avancement ci-dessus) — sauf [[Explosions]], [[Tooltips contextuels]], [[Arborescence du projet]] et le vocabulaire de [[Véhicules]], finalement réglés mécaniquement (voir leurs bandeaux).

| Note | Le conflit | La décision à prendre |
|---|---|---|
| [[Unification macro-micro]] / [[Terrain spectaculaire]] | pics « 200-400 blocs », falaises « 30-80 blocs », bruit 3D de cavernes — écrits pour une altitude voxel continue | comment l'altitude continue du bruit se **quantifie sur les 21 niveaux (0-20)** de [[Hauteur de terrain ±10]] ? Référence absolue ou relative par cellule ? Que deviennent les cavernes ? |
| [[Décisions d'architecture]] | chunks cubiques 16×16×16 indexés `(x,y,z)` + octree de subdivision | structure de données réelle de la grille tactique : [[Grille continue]] dit chunk = **32×32 tuiles**, « structure plate » — et les étages de donjon ? |
| [[Stratification verticale]] / [[Minerais par profondeur]] | strates et bandes de minerai en Y — mais on ne creuse plus nulle part | remapper sur la **profondeur d'étage de donjon** et la composition des **filons de surface** ? Ou supprimer ? |
| [[Habitat des PNJ]] / [[Détection de pièces]] | pièce minimale « 2×2×2 blocs », bonus « volume ≥ 27 blocs » | critères de pièce en **2D** : surface minimale en tuiles, bonus de taille |
| [[Éditeur de sculpture]] | périmètres en voxels 1px | périmètres et résolution du **pixel art** par table |
| [[Génération de donjon]] / [[Salles et connecteurs]] | tailles en cubes (8³, 16³…), « offset vertical −16 aligné chunk », `vox_model` | dimensions des prefabs **en tuiles par étage** ; format des prefabs 2D — l'algorithme par graphe survit intégralement |
| [[Budgets de performance]] / [[Ordre de vérification]] | meshing < 4 ms/chunk, 8 Ko/chunk, « façade 64 blocs 4px meshée » | budgets et critères de validation du **rendu tuiles + billboards** (les budgets de tick < 8 ms et ~64 entités restent valables) |
| [[Minimap et brouillard de guerre]] | « coupe au niveau Y », bitmask par bande verticale | en surface, le monde est une grille unique + hauteur — le découpage par étage ne garde de sens **qu'en donjon** |
| [[Sauvegarde]] | `chunks/x_y_z.bin`, « octree sérialisé » | format du diff sur la grille (le principe seed + modifications survit) |
| [[Météo]] | mod_altitude « −1/20 blocs », mod_profondeur « cavernes », neige « bloc fin 4px » | recalibrer sur les 21 niveaux et les étages de donjon |
| [[Véhicules]] | « Σ durete des **voxels** », modèle sculpté voxel | stats dérivées du modèle **pixel art** ; l'entité rigide et les blocs fonctionnels survivent |
| [[Explosions]] | « la subdivision est respectée : chaque sous-bloc testé » | rayon en tuiles + seuil de dureté suffisent — clause subdivision à supprimer |
| [[Tooltips contextuels]] | déclencheurs « premier bloc en main », « première subdivision » | premières-fois de la direction tactique |
| [[Arborescence du projet]] | `systems/voxel/` (chunks, meshing, subdivision octree) | système de grille à nommer |

## Catégorie 3 — Vocabulaire seulement

La mécanique tient sur la grille ; seules les unités et les mots dataient. **Appliqué le 2026-08-26** dans les notes concernées :

- **« blocs » → « tuiles »** pour toute distance/portée : les modules de [[Modules]] (« téléporte 5 blocs », « cercle 3 blocs », « rue de 4 blocs »…), le spawn « 200 blocs » de [[Début de partie]], la propagation foudre « rayon 5 » de [[Eau et liquides]], « 1 bloc de dénivelé » → 1 niveau de hauteur ([[Véhicules]]), « −1/20 blocs » d'altitude…
- **« .vox » → sprites 2D** : `vox_model`/`vox_slots` de [[Schéma objet et recette]], « comptage de voxels » → comptage de pixels ([[Stats d'un objet crafté]]), « bruit par voxel en shader » → par tuile ([[Palette de couleurs des matériaux]]), « impact meshing » de la transparence ([[Application des stats de matériau]], [[Catalogue matériaux — Synthétiques]]).
- **`place_block`/`destroy_block` → intentions de tuile** ([[Réseau]]), « mutations voxel » → mutations de tuiles.
- **Optimisation** : les principes transversaux de [[Optimisation — principes]] (GDScript typé, zéro allocation, time-slicing, threads, tout seedé) restent valables tels quels ; seuls les « candidats probables » (meshing, éclairage 3D) et [[Génération procédurale — performance]] (« remplissage 3D », cavernes) sont à relire — l'échantillonnage du bruit par colonne reste juste pour une heightmap.

## Ce qui est déjà propre

Écrit après le pivot, rien à toucher : [[Action-time à ticks]], [[Combat tactique sur grille]], [[Zones de coup par dénivelé]], [[Jauge de chaîne Wu Xing]], [[Sorts cataclysmiques]], [[Construction cadrée]], [[Grille continue]], [[Hauteur de terrain ±10]], [[Armure par zone et constructions]], [[Craft compositionnel]], [[Direction artistique]], et tout le dossier combat hors pipeline E.3 (déjà flaggé pour une autre raison).

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Grille continue]], [[Hauteur de terrain ±10]]
- **Alimente** : toutes les notes taguées `héritage-voxel`
- **Voir aussi** : [[Carte — Technique]], [[Carte — Ouvert]], [[Ordre de construction]]
