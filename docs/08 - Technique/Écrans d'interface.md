---
aliases: ["E.13", "Annexe E.13", "Écrans d'interface", "UI", "Interface"]
tags: [technique, interface, décidé]
domaine: technique
statut: décidé
etape: 0
---

La liste de référence des écrans du jeu.

Inventaire+équipement (avec poids), Craft (recettes des stations à portée, [[Stations de transformation]]), Fenêtre de sculpture ([[Éditeur de sculpture]]), Feuille de personnage (stats, compétences, niveaux dérivés), Assemblage de compétences (slots armes/modules, coûts mana), Carte du monde (biomes, POI, claims, voyage rapide), Gestion de claim (rôles de cases, pièces/logements, assignations de jobs, journal des rapports [[Abstraction hors-site]]), Guildes (rangs, quêtes), Commerce (achat/vente, gestion d'étal), Relations (PNJ connus, réputations), Dialogue PNJ.

**UI de combat ([[Combat tactique sur grille]]) :** *la lisibilité EST le game feel d'un tactique* — timeline des prochaines actions, coûts en ticks affichés sur les tuiles atteignables, prévisualisation des dégâts avec le détail du calcul, journal de combat. L'effort visuel passe là, pas dans l'animation ([[Direction artistique]]).

**Lisibilité Wu Xing obligatoire ([[Wu Xing — cycles et vecteurs]]) :** l'alignement de la cible et le multiplicateur prévu s'affichent au survol ; la jauge de chaîne est toujours visible sous le réticule ; l'écran d'assemblage montre le pentagramme.

**Infobulle exhaustive ([[Vocabulaire des modules — six axes]]) :** chaque module affiche ses valeurs **calculées pour le personnage courant**, avec le détail du calcul. Aucune information cachée, aucun « environ ».

**Navigation des recettes ([[Craft compositionnel]]) :** cliquer sur un composant déplie son obtention, récursivement ; recettes inconnues en silhouette.

**Minimap ([[Minimap et brouillard de guerre]]) :** toujours visible à l'écran, coupe au niveau Y du joueur.

**Trésor du royaume ([[Entretien et taxes]]) :** l'écran de gestion de claim affiche solde, prévisionnel hebdomadaire, dépôts/retraits.

**Rafraîchissement à chaud ([[Localisation]]) :** signal `locale_changed` → toute l'UI se rafraîchit.

## Liens
- **Dépend de** : [[Direction artistique]], [[Localisation]]
- **Alimente** : [[Combat tactique sur grille]], [[Craft compositionnel]], [[Habitat des PNJ]], [[Entretien et taxes]]
- **Voir aussi** : [[Minimap et brouillard de guerre]], [[Wu Xing — cycles et vecteurs]], [[Vocabulaire des modules — six axes]], [[Tooltips contextuels]], [[Dialogue PNJ]], [[Éditeur de sculpture]], [[Arborescence du projet]]
