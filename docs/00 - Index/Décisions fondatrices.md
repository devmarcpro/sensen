---
aliases: ["16", "16. État du document", "Décisions fondatrices", "Décision fondatrice", "Voxen"]
tags: [index, décision, décidé]
domaine: index
statut: décidé
etape: 0
---

La rupture du 2026-08-09 : ce qui a été abandonné, ce qui survit, et pourquoi. Décision irrévocable.

## Décision fondatrice — roguelike tactique, pas voxel temps réel

**Sensen est un roguelike tactique en vue isométrique sur grille**, avec des personnages en **billboards paperdoll pixel art** (façon Dofus), un **monde continu** et une **hauteur de terrain quantifiée sur 21 niveaux** (façon FFT/Disgaea). Le combat se joue en **action-time à ticks** : le temps n'avance que lorsqu'une action est engagée.

**Pourquoi :** ce jeu est fondamentalement un **jeu de données et de décisions** — Wu Xing, jauge de chaîne, potentiel, affixes générés, économie, PNJ simulés. Le voxel temps réel était un vêtement mal taillé : il exigeait un travail d'animation insoluble en solo, cachait les systèmes au lieu de les exposer, et poussait vers de la dextérité là où le jeu récompense la réflexion. Plus **Dwarf Fortress** que Minecraft. *Décision irrévocable — elle ne sera pas rediscutée.*

**Ce qui disparaît :** le minage exploratoire souterrain (remplacé par des **filons de surface à récolter**, façon Elin — [[Récolte]]), la construction voxel libre (remplacée par une **construction cadrée** en empreintes de bâtiments — [[Construction cadrée]]), le volume souterrain (remplacé par des **donjons en étages discrets** — [[Donjons — structure et intégration]]).

**Ce qui survit intact :** monde continu, cases, biomes, destruction du terrain, verticalité, royaumes, PNJ, corruption, météo, craft, Wu Xing, loot, potentiel, donjons.

## État du document

**Toutes les décisions de design sont tranchées.** *Nuance découverte à la conversion : les annexes D, E et G n'ont pas été réécrites après le pivot et décrivent encore par endroits le moteur voxel — voir [[Héritage voxel — audit]].* Chaque section porte ses Décisions, les formules vivent en Annexe A, les schémas de données en B, le contenu de lancement en C et F, l'architecture Godot en D, les intégrations système en E, la performance en G.

### Décisions structurantes du 2026-08-09 (rupture avec le prototype Voxen)

| Décision | Conséquence |
|---|---|
| **Nom : 森森 Sensen** | remplace Voxen |
| **VOXEL TEMPS RÉEL ABANDONNÉ** | **roguelike tactique isométrique sur grille**, billboards paperdoll pixel art, hauteur ±10 — décision irrévocable |
| **Combat en action-time à ticks** | le temps n'avance qu'à l'action ; le choix d'arme est un choix de tempo ; exploration en temps réel libre |
| **Combat directionnel (M&B) abandonné** | zones dérivées du **dénivelé**, garde en posture frontale, télégraphe = icône d'interface |
| **Minage exploratoire écarté** | filons de surface façon Elin ; plus de volume souterrain, les donjons sont des étages discrets |
| **Construction voxel libre écartée** | construction cadrée en empreintes de bâtiments + modelage du terrain |
| **Wu Xing en vecteurs** | plus aucun domaine « hors cycle » ; format unique pour armes, armures, créatures, modules, matériaux, lieux |
| **Jauge de chaîne 5→10** | le cœur du combat ; deux voies équivalentes (rotation / construction-détonation) |
| **Craft compositionnel** | slots typés à matériau libre, équilibrage par la connaissance des recettes |
| **Armure par zone** | supprime la mitigation par dés (cause de l'écrasement des dégâts) ; permanente, jamais situationnelle |
| **Affixes = générateurs** | loot-only ; gemmes = nombres ; « l'atelier améliore, le donjon transforme » |
| **Chimie élémentaire supprimée** | remplacée par le palier industriel (recettes trouvées/achetées) |
| **XP = dégâts appliqués** | trois pistes offensives, constructions en défense ; le potentiel régule seul |

*Notes correspondantes : [[Identité visuelle chinoise]] · [[Hauteur de terrain ±10]] · [[Action-time à ticks]] · [[Zones de coup par dénivelé]] · [[Récolte]] · [[Construction cadrée]] · [[Wu Xing — cycles et vecteurs]] · [[Jauge de chaîne Wu Xing]] · [[Craft compositionnel]] · [[Armure par zone et constructions]] · [[Loot — affixes, gemmes et rareté]] · [[Palier industriel]] · [[XP de combat]].*

### Décision du 2026-08-26 — retrait des peuples inventés et du bestiaire fantastique

| Décision | Conséquence |
|---|---|
| **3 races « originales » supprimées** | Sylvide, Cendreux et Échomorphe disparaissent. Restent **Humain, Elfe, Nain** — fantasy classique assumée ([[Races]]) |
| **3 cultures dédiées supprimées** | Sylvestre, Ignée, Résonance partaient avec leurs races — **7 cultures**, toutes inspirées du monde réel ([[Cultures de nommage]]) |
| **Créatures fantastiques abandonnées** | le bestiaire reste **définitivement** réaliste ; la haute corruption produit des bêtes réelles plus dangereuses ([[Ouvert — Créatures fantastiques]]) |

**Ce qui n'est pas touché :** le système de races est **intact** — réputation par race ([[Réputation et relations]]), race dominante d'un royaume ([[Génération des royaumes PNJ]]), `race_affinity` des cultures, `lifespan` par race ([[Âge des PNJ]]). La magie, le mana, les grimoires et le **Wu Xing** le sont aussi.

### Reste ouvert, par nature

- **Lore** : noms propres, textes d'ambiance, mythologie — à écrire au fil du contenu. → [[Ouvert — Lore]]
- **Audio/musique** : hors périmètre de ce document. → [[Ouvert — Audio et musique]]
- **Saisons** ([[Météo]] : l'architecture les accueille, gros impact agricole — après playtest de la boucle agricole). → [[Ouvert — Saisons]]
- **Créatures fantastiques** en zones à haute corruption ([[Créatures]] : prévu sans changement de système). → [[Ouvert — Créatures fantastiques]]

### À trancher au playtest (implémentable sans)

- Axe unique des **niveaux de recette** (efficacité matière / vitesse et lots / stabilité). → [[Ouvert — Axe des niveaux de recette]]
- **Esquive active** dédiée ou mouvement pur. → [[Décision — Esquive active]]
- Répartitions élémentaires exactes d'**Arcane, Espace, Corruption**. → [[Ouvert — Répartitions Arcane Espace Corruption]]
- Fourchettes des **gemmes** et plafond +15 par compétence ; taille des pools d'**affixes**. → [[Ouvert — Fourchettes des gemmes]]
- Ce qui compense réellement une **arme mixte** face à une arme pure (au-delà de l'amortissement des matchups et de la purification par gemmes). → [[Ouvert — Compensation de l'arme mixte]]

### Contenu à produire

- 5 modules du domaine **Métal** ([[Modules]]) → [[Ouvert — Modules du domaine Métal]] ; affinités élémentaires des ingrédients de cuisine → [[Décision — Affinités de cuisine]].
- Recettes d'obtention par composant × famille ([[Composant et recette d'obtention]]) et leurs sources exotiques. → [[Ouvert — Recettes de composants par famille]]
- Pools de noms des 10 cultures ([[Cultures de nommage]]). → [[Ouvert — Pools de noms des cultures]]
- Surcharges `wuxing` des matériaux dont la catégorie ment. → [[Décision — Surcharges Wu Xing des matériaux]]

### Trous connus du combat (à traiter avant ou pendant le prototype)

Voir [[Trous connus du combat]] — sept points : [[Décision — Multi-ennemis et jauge]], [[Décision — Vocabulaire d'attaque des créatures]], [[Décision — Fuite et désengagement]], [[Décision — Chaîne côté ennemis]], [[Décision — Boucliers]], [[Décision — Projectiles]], [[Ouvert — Dark Continent]].

## Liens
- **Alimente** : [[Ordre de construction]], [[Contraintes permanentes]], [[Pitch et identité]], tout le coffre
- **Voir aussi** : [[Sensen — Index général]], [[Carte des dépendances]], [[Risques majeurs]], [[Trous connus du combat]]
