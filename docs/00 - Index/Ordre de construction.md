---
aliases: ["Ordre de construction", "D.3", "Annexe D.3", "15", "15. MVP", "MVP", "Étapes"]
tags: [index, production, décidé]
domaine: index
statut: décidé
etape: 0
---

Le donjon avant le monde. Chaque étape doit produire quelque chose de jouable et jugeable, jamais une brique invisible.

## Ordre de construction (révisé pour la direction tactique)

**Principe : le donjon avant le monde.** Un donjon n'est qu'une grille bornée — il ne nécessite aucune génération de monde. On peut donc obtenir un **roguelike complet et jouable** bien avant d'avoir un monde ouvert. Chaque étape doit produire quelque chose de **jouable et jugeable**, jamais une brique invisible.

| # | Étape | Ce qu'on obtient | Notes concernées |
|---|---|---|---|
| **0** | **Prototype de combat isolé** — document : [[Prototype de combat — spécification]] | *Le combat est-il bon ?* Rien ne démarre avant un oui. | [[Action-time à ticks]], [[Boucle de tick]], [[Combat tactique sur grille]], [[Zones de coup par dénivelé]], [[Garde en posture]], [[Attaque lourde et télégraphe]], [[Endurance]], [[Wu Xing — cycles et vecteurs]], [[Jauge de chaîne Wu Xing]], [[Domination et multiplicateurs]], [[Structure compétences-modules-slots]], [[Vocabulaire des modules — six axes]], [[Six types de modules et assemblage]], [[Familles de capacités de la grille]], [[Sorts cataclysmiques]], [[Mana]], [[Pipeline de résolution du combat]], [[Statuts]], [[Trous connus du combat]] |
| **1** | Projet réel : combat rapatrié + pipeline paperdoll minimal (une silhouette, quelques pièces d'équipement visibles) | un combat propre dans le vrai projet | [[Direction artistique]], [[Squelette modulaire et points d'attache]], [[Palette de couleurs des matériaux]], [[Tooltips contextuels]], [[Localisation]] |
| **2** | **Génération de donjon** (salles et connecteurs sur grille, étages, hauteur) | un espace clos à explorer | [[Donjons — structure et intégration]], [[Génération de donjon]], [[Salles et connecteurs]], [[Hauteur de terrain ±10]] |
| **3** | **Loot** : affixes générateurs, gemmes, sertissures, rareté par profondeur | une raison de descendre | [[Loot — affixes, gemmes et rareté]], [[Effets d'équipement passifs]], [[Effets d'équipement types]], [[Équipement — 14 slots]], [[Armure par zone et constructions]], [[Trésors et artefacts]], [[Monstres rares]], [[Grimoires et manuels]], [[Lecture des livres]] |
| **4** | **Progression** : usage, potentiel, niveaux d'élément et de construction | une raison de recommencer | [[Progression par l'usage]], [[Potentiel]], [[Double niveau combat et général]], [[XP de combat]], [[Création de personnage]], [[Races]], [[Classes]], [[Astrologie — cycle sexagésimal]], [[Compétences — liste]], [[Mort et pénalité]] |
| **5** | ⭐ **JALON — roguelike jouable de bout en bout** | *entrer, combattre, looter, progresser, ressortir.* **À juger honnêtement avant toute suite.** | — |
| **6** | **Matériaux (~30, justifiés un par un)** + craft compositionnel | fabriquer ce qu'on n'a pas looté | [[Matériaux — 13 stats]], [[Application des stats de matériau]], [[Schéma matériau]], [[Catégories de matériaux]], [[Récolte]], [[Qualité d'artisanat]], [[Craft compositionnel]], [[Composants]], [[Composant et recette d'obtention]], [[Stats et qualité de l'assemblage]], [[Stations de transformation]], [[Palier industriel]], [[Tables de sculpture]], catalogues [[Catalogue matériaux — Bois]] et suivants |
| **7** | **Camp de base** : une seule cellule, stations, coffres, repos | un point d'ancrage entre deux expéditions | [[Construction cadrée]], [[Claims et persistance]], [[Rôles de cases]], [[Détection de pièces]], [[Habitat des PNJ]], [[Meubles]], [[Faim]], [[Nourriture]] |
| **8** | **Génération du monde** : grille continue, hauteur, biomes, cellules, carte du monde, voyage rapide | un monde à parcourir entre les donjons | [[Grille continue]], [[Génération par couches de bruit]], [[Unification macro-micro]], [[Terrain spectaculaire]], [[Stratification verticale]], [[Minerais par profondeur]], [[Biomes — schéma]], [[Biomes de départ]], [[Carte du monde]], [[Niveau de danger]], [[Dérive de la corruption]], [[Météo]], [[Eau et liquides]], [[Cycle jour-nuit et sommeil]], [[Minimap et brouillard de guerre]], [[Début de partie]] |
| **9** | **PNJ et villages** : dialogue, relations, information par paliers, boutiques | un monde habité | [[Schéma unifié créature-PNJ]], [[Schéma créature]], [[IA des créatures]], [[LOD de simulation]], [[Compagnons]], [[Âge des PNJ]], [[Apprivoisement et recrutement]], [[Dialogue PNJ]], [[Réputation et relations]], [[L'information comme récompense]], [[Voie de rédemption]], [[Commerce et boutiques]], [[Prix suggéré]], [[Quêtes et guildes]], [[Villages PNJ — repeuplement et décimation]], [[Noms culturels]], [[Génération de noms]], [[Créatures]] |
| **10** | **Royaumes, lois, économie, claims** | l'endgame de territoire | [[Royaume du joueur]], [[Expansion territoriale]], [[Population et exploitation]], [[Halls de guilde]], [[Gouvernance, lois et diplomatie]], [[Lois et infractions]], [[Défense et raids]], [[Raids et menaces]], [[Entretien et taxes]], [[Économie — sources et puits]], [[Barèmes économiques]], [[Génération des royaumes PNJ]], [[Schéma royaume]], [[Conquête de village]], [[Familles et succession]], [[Abstraction hors-site]], [[Agriculture et élevage]], [[Cuisine et alchimie]] |
| **11** | **Coop** (temporalités parallèles, [[Action-time à ticks]]) | dernier chantier, jamais avant un solo bon | [[Multijoueur]], [[Réseau]], [[Réseau et sauvegarde — performance]], [[Temporalités parallèles]] |

**Ce qui a changé par rapport à l'ordre voxel :** le Wu Xing et les chaînes ne sont plus une étape tardive — ils sont *dans* le prototype de combat (étape 0), puisqu'ils sont l'identité du jeu. La génération du monde recule de la 1ʳᵉ à la 8ᵉ place : elle n'est plus un prérequis technique (plus de meshing, plus de streaming volumétrique), et elle ne produit rien de jouable seule.

---

## D.3 et section 15 (MVP) — archivés

L'ordre de construction conseillé **D.3** et le **MVP voxel** de la section 15 étaient écrits pour l'ancien moteur (subdivision, import .vox, monde voxel continu). Ils sont retirés — le texte intégral vit dans le GDD archivé (`archive/SENSEN_GDD.md`) et l'historique git. **La table des 11 étapes ci-dessus est l'unique ordre de construction.**

Ce qui survivait de D.3 est intégré ailleurs : le pipeline de localisation dès la première ligne ([[Localisation]]), la validation de perf par étape ([[Ordre de vérification]]), le premier donjon comme validation du pipeline complet (étape 2).

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Contraintes permanentes]]
- **Alimente** : tout le coffre, par le champ `etape` de chaque note
- **Voir aussi** : [[Ordre de vérification]], [[Risques majeurs]], [[Carte des dépendances]], [[Sensen — Index général]]
