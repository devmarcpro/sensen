---
aliases: ["11", "11. Contraintes techniques & risques majeurs", "Risques majeurs", "Risques"]
tags: [technique, risque, décidé]
domaine: technique
statut: décidé
etape: 0
---

Les sept risques identifiés — dont un levé par la direction tactique.

- ~~Physique voxel fine en 3D~~ **Risque levé** : destruction discrète à la tuile (voir [[Hauteur de terrain ±10]]/[[Construction cadrée]]), beaucoup moins coûteuse et bien plus simple à synchroniser en réseau.
- **Monde infini + persistance des claims** : besoin d'un système robuste de streaming de chunks et de sauvegarde différentielle (ne sauvegarder que ce qui a changé — [[Sauvegarde]]).
- **Netcode coopératif (host-and-join, façon Terraria)** : bien plus simple maintenant que la destruction se fait par blocs pleins (événements discrets), mais reste un développement à part entière ([[Multijoueur]], [[Réseau]]).
- **Scope très large** (4 inspirations combinées) : risque de dilution du développement → prioriser un MVP centré sur 1-2 piliers avant d'étendre ([[Ordre de construction]]).
- **Architecture data-driven à grande échelle** : bien conçue dès le départ, sinon coûteuse à retrofit plus tard ([[Data-driven design]]).
- **Abstraction hors-site** (voir [[Agriculture et élevage]]) : la gestion de ville/village/base doit se simuler de façon abstraite quand le joueur n'est pas sur place (cultures, élevage, boutiques passives, régénération des cases sauvages) — chantier transversal à concevoir en profondeur, impacte plusieurs systèmes déjà posés ([[Abstraction hors-site]]).
- **Localisation dès le jour 1** (voir [[Localisation]]) : discipline permanente — toute string affichable passe par une clé de traduction dès la première ligne de code. Coût quasi nul si respecté d'emblée, refonte massive sinon.
- **Éclairage** (impliqué par la stat `luminosite`, [[Application des stats de matériau]]) : propagation en 2D sur la grille (bien plus simple qu'en volume), utilisée pour la visibilité nocturne, les donjons et l'ambiance. La transparence devient un simple tri de rendu ([[Éclairage]]).

## Liens
- **Dépend de** : [[Décisions fondatrices]]
- **Alimente** : [[Ordre de construction]], [[Contraintes permanentes]]
- **Voir aussi** : [[Sauvegarde]], [[Multijoueur]], [[Data-driven design]], [[Abstraction hors-site]], [[Localisation]], [[Éclairage]], [[Construction cadrée]], [[Public visé]]
