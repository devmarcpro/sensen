---
aliases: ["E.10", "Annexe E.10", "Sauvegarde", "Save", "Sauvegarde différentielle"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Le format voxel (`chunks/x_y_z.bin`, octree sérialisé) est retiré — archivé dans le GDD source. Le format du diff de tuiles proposé : [[Décision — Structure de données de la grille]] ). Le principe est inchangé.

Le format de sauvegarde : un dossier par monde, seuls les chunks modifiés écrits.

```
Format : un dossier par monde.
  world.json          : seed, temps (ticks), réglages
  chunks/cx_cz.bin    : uniquement chunks modifiés — liste
                        (index_tuile, champs modifiés : hauteur/sol/contenu)
  dungeons/{id}/floor_n.bin : même format, par étage de donjon
  entities.json       : instances de créatures (état complet, cf. fiche §B.5)
  players/*.json      : inventaire, compétences+XP, position, modèles sculptés,
                        claims (rôles de cases), rangs de guilde, réputations
  abstract.json       : états abstraits hors-site (E.6), boutiques, royaume
Écriture : autosave toutes les 5 min réelles + sur événements clés,
écriture atomique (tmp + rename). Le multi : seul le host possède la
sauvegarde ; les invités gardent localement leur personnage (import à la
connexion, exporté à la déconnexion).
```

**Contrainte permanente ([[Contraintes permanentes]]) :** *l'état du monde est sérialisable en permanence — même exigence que la sauvegarde, payée une fois pour deux usages.*

**Principe général ([[Optimisation — principes]]) :** *tout est SEEDÉ et déterministe → jamais besoin de stocker ce qui est regénérable.*

**Stockages spécifiques :** delta de corruption par cellule ([[Dérive de la corruption]]), bitmask d'exploration par joueur ([[Minimap et brouillard de guerre]]), modèles sculptés ([[Éditeur de sculpture]]), état « vu » des tooltips ([[Tooltips contextuels]]), noms générés ([[Génération de noms]]), compétences d'instance des PNJ ([[Schéma créature]]).

**Donjons ([[Donjons — structure et intégration]]) :** les changements (morts, butin pris, tuiles détruites) suivent exactement la sauvegarde différentielle standard — *rien de nouveau à construire*.

**Performance ([[Réseau et sauvegarde — performance]]) :** sérialisation en thread, écriture atomique, l'autosave ne bloque jamais le jeu (copie-sur-écriture).

> [!success] Codé le 2026-08-28 — étape 8.2c, `systems/sauvegarde.gd`, `Simulation.sauvegarder / charger_sauvegarde`
> Le principe tel quel : **seed + liste des modifications**, un dossier par monde (`user://sauvegardes/<nom>/`), écriture atomique (tmp + rename). Fichiers : `world.json` (graine, temps en ticks, compteurs, cellule du camp), `surface.json` (par cellule : modifications de tuiles, tuiles découvertes, contenants, êtres endormis, chunks explorés — jamais ce qui se regénère), `entities.json` (les êtres et contenants de la fenêtre courante), `items.json` (les instances d'objets), `players/joueur.json` (fiche et être du joueur). **Décisions** : JSON lisible plutôt que `.bin` tant qu'on prototype (les Vector2i et clés non textuelles sont encodés explicitement) ; on ne sauvegarde **qu'en surface** (au camp ou à pied) — un donjon en cours n'est pas persisté, l'expédition reprend au camp ; **autosave toutes les 5 minutes réelles** et à chaque retour d'expédition ; F6 sauvegarde, F7 charge. Le profil multi-joueurs et les modèles sculptés n'existent pas.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Arborescence du projet]]
- **Alimente** : [[Multijoueur]], [[Abstraction hors-site]], [[Minimap et brouillard de guerre]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Décision — Structure de données de la grille]], [[Réseau]], [[Réseau et sauvegarde — performance]], [[Optimisation — principes]], [[Contraintes permanentes]], [[Schéma créature]], [[Éditeur de sculpture]]
