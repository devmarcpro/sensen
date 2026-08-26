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
| **0** | **Prototype de combat isolé** (document séparé) | *Le combat est-il bon ?* Rien ne démarre avant un oui. | [[Action-time à ticks]], [[Boucle de tick]], [[Combat tactique sur grille]], [[Zones de coup par dénivelé]], [[Garde en posture]], [[Attaque lourde et télégraphe]], [[Endurance]], [[Wu Xing — cycles et vecteurs]], [[Jauge de chaîne Wu Xing]], [[Domination et multiplicateurs]], [[Structure compétences-modules-slots]], [[Vocabulaire des modules — six axes]], [[Six types de modules et assemblage]], [[Familles de capacités de la grille]], [[Sorts cataclysmiques]], [[Mana]], [[Pipeline de résolution du combat]], [[Statuts]], [[Trous connus du combat]] |
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

## Ordre de construction conseillé (D.3, aligné MVP historique)

1. GameData + 3 JSON de matériaux → afficher un chunk plat texturé par bruit. **Dès cette étape : pipeline de localisation en place (clés `name_key`, `locale/fr.csv` + `locale/en.csv`, validation des clés au boot) — aucune string affichable en dur, jamais.**
2. Génération par couches (altitude/temp/humidité) + 4 biomes → monde continu streamé.
3. Casser/poser des blocs, récolte avec XP, inventaire.
4. Subdivision (2 niveaux d'abord : 16 et 8 px).
5. Import .vox + remapping palette → premier outil crafté visible en main.
6. Une créature générique data-driven + combat minimal (1 arme, 3 modules, mana).
7. Carte du monde + voyage rapide + claim d'une case + minimap ([[Minimap et brouillard de guerre]]).
8. Premier donjon ([[Génération de donjon]]) : 2-3 salles/connecteurs prefabs, un étage, validation du pipeline complet (génération → boss → disparition).
9. Le reste (sculpture, guildes, boutiques, réseau) par itérations.

**Critères de performance par étape :** [[Ordre de vérification]].

---

## MVP : premier jalon jouable (section 15)

*(Le MVP est redéfini par la direction tactique : prototype de combat isolé d'abord — document séparé — puis génération du monde en grille, ~30 matériaux, combat rapatrié, boucle de donjon. Voir l'en-tête du document, ci-dessus.)*

**Contenu historique conservé pour référence :**

**Objectif :** une **tranche verticale mince** qui touche à tous les piliers, avec un **focus fort sur le monde et la construction** — le pilier prioritaire à prouver en premier.

**Inclus dans le MVP :**

*Monde et construction (priorité) :*
- Génération procédurale avec un jeu de couches de bruit réduit (altitude, température, humidité — les couches secondaires comme mana/danger/ressources peuvent être simplifiées ou reportées).
- Monde voxel continu, carte du monde avec voyage rapide.
- Une poignée de biomes de base.
- Construction avec subdivision (au moins 2-3 niveaux pour valider la technique, sans forcément les 5 niveaux complets dès le départ).
- Quelques catégories de matériaux et récolte de base.

*Combat et magie (minimal) :*
- Un ou deux types d'armes avec quelques slots de compétences.
- Un petit nombre de modules pré-définis pour valider la boucle (le système complet de grimoires/manuels peut arriver après).
- Système de mana basique.

*Vie simulée (minimal) :*
- PNJ de base utilisant le système modulaire ([[Schéma unifié créature-PNJ]]), sans forcément tout l'éventail de guildes/commerce dès le départ.

**Reporté après le MVP :**
- Les 12 guildes et leur système de quêtes complet.
- Le système complet de réputation à 4 niveaux.
- L'agriculture/élevage et l'abstraction hors-site.
- Les tables de sculpture (peuvent venir juste après, comme feature de personnalisation).
- Le multijoueur complet (même si l'architecture doit être pensée dès le départ pour ne pas bloquer son ajout plus tard).
- Direction artistique poussée (une palette de base suffit pour le MVP).

*(Répartition validée — l'ordre de construction exécutable est en D.3 ci-dessus, avec critères de perf par étape en [[Ordre de vérification]].)*

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Contraintes permanentes]]
- **Alimente** : tout le coffre, par le champ `etape` de chaque note
- **Voir aussi** : [[Ordre de vérification]], [[Risques majeurs]], [[Carte des dépendances]], [[Sensen — Index général]]
