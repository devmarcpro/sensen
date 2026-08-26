---
aliases: ["6.3", "6.3 Début de partie", "Début de partie", "Spawn"]
tags: [progression, monde, décidé]
domaine: progression
statut: décidé
etape: 8
---

La séquence de démarrage : le joueur choisit lui-même son niveau de risque initial, puis spawn en pleine nature, seul.

**Séquence de démarrage :**
1. Création du monde (seed) puis **création de personnage détaillée** ([[Création de personnage]]).
2. **Choix de la zone de départ sur la carte du monde** : le joueur voit la carte générée (biomes + indication du niveau de danger/corruption par case, façon heat-map simplifiée) et **clique sa case de départ**. C'est cohérent avec le danger piloté par le bruit ([[Niveau de danger]]) : le joueur choisit lui-même son niveau de risque initial — zone paisible pour apprendre, ou zone corrompue pour un départ brutal assumé.
3. **Spawn en pleine nature, seul** (façon Minecraft) : pas de scène d'ouverture, pas de village de départ imposé — le monde commence immédiatement. Position exacte : point marchable le plus proche du centre de la case choisie, en surface.
4. Équipement initial = kit de la classe ([[Classes]]), rien d'autre.

**Apprentissage par le jeu (zéro script)** : aucun tutoriel guidé ni quête d'apprentissage imposée. Un système de **tooltips contextuels** déclenchés par les événements EventBus enseigne au fil des premières fois (voir [[Tooltips contextuels]]). Tout est désactivable dans les réglages ("mode vétéran") et n'apparaît qu'une fois par savoir.

**En multijoueur :** les invités qui rejoignent spawnent près du joueur host (ou à un point de ralliement défini par le host), avec leur propre personnage importé ([[Sauvegarde]]).

**Décisions :**
- **Heat-map : vague par défaut** — 3 niveaux lisibles (paisible / dangereuse / mortelle) ; la **valeur précise** de corruption se débloque par rang dans la guilde Exploration (récompense d'information, cohérent avec [[Quêtes et guildes]]).
- **Garde-fou de spawn :** re-tirage automatique du point exact si la surface marchable connexe < 200 blocs (falaise, îlot) — jusqu'à trouver une zone viable dans la case choisie, sinon case adjacente la plus proche.

## Liens
- **Dépend de** : [[Création de personnage]], [[Carte du monde]], [[Niveau de danger]], [[Classes]]
- **Alimente** : [[Tooltips contextuels]], [[Boucle de jeu]]
- **Voir aussi** : [[Dérive de la corruption]], [[Quêtes et guildes]], [[Multijoueur]], [[Sauvegarde]], [[Mort et pénalité]]
