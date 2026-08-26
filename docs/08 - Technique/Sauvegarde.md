---
aliases: ["E.10", "Annexe E.10", "Sauvegarde", "Save", "Sauvegarde différentielle"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

Le format de sauvegarde : un dossier par monde, seuls les chunks modifiés écrits.

```
Format : un dossier par monde.
  world.json      : seed, temps (ticks), réglages
  chunks/x_y_z.bin : uniquement chunks modifiés — liste (index_bloc,
                     nouvel_état) ; état = id matériau OU octree sérialisé
  entities.json   : instances de créatures (état complet, cf. fiche §B.5)
  players/*.json  : inventaire, compétences+XP, position, modèles sculptés,
                    claims (rôles de cases), rangs de guilde, réputations
  abstract.json   : états abstraits hors-site (E.6), boutiques, royaume
Écriture : autosave toutes les 5 min réelles + sur événements clés,
écriture atomique (tmp + rename). Le multi : seul le host possède la
sauvegarde ; les invités gardent localement leur personnage (import à la
connexion, exporté à la déconnexion).
```

**Contrainte permanente ([[Contraintes permanentes]]) :** *l'état du monde est sérialisable en permanence — même exigence que la sauvegarde, payée une fois pour deux usages.*

**Principe général ([[Optimisation — principes]]) :** *tout est SEEDÉ et déterministe → jamais besoin de stocker ce qui est regénérable.*

**Stockages spécifiques :** delta de corruption par cellule ([[Dérive de la corruption]]), bitmask d'exploration par joueur ([[Minimap et brouillard de guerre]]), modèles sculptés ([[Éditeur de sculpture]]), état « vu » des tooltips ([[Tooltips contextuels]]), noms générés ([[Génération de noms]]), compétences d'instance des PNJ ([[Schéma créature]]).

**Donjons ([[Donjons — structure et intégration]]) :** les changements (morts, butin pris, blocs détruits) suivent exactement la sauvegarde différentielle standard — *rien de nouveau à construire*.

**Performance ([[Réseau et sauvegarde — performance]]) :** sérialisation en thread, écriture atomique, l'autosave ne bloque jamais le jeu (copie-sur-écriture).

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Arborescence du projet]]
- **Alimente** : [[Multijoueur]], [[Abstraction hors-site]], [[Minimap et brouillard de guerre]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Réseau]], [[Réseau et sauvegarde — performance]], [[Optimisation — principes]], [[Contraintes permanentes]], [[Schéma créature]], [[Éditeur de sculpture]]
