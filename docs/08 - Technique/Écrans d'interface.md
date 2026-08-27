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

> [!success] Décidé le 2026-08-27 — contrôles et caméra du prototype
> Tranché par le designer : **pas de rotation de caméra** (une seule vue isométrique). Le joueur est **centré à l'écran**, la vue le suit. Déplacement au clavier **ZQSD en 8 directions** (Z = haut de l'écran, D = droite, etc. ; deux touches ensemble = diagonale d'écran, soit un axe de la grille). La souris garde la visée : clic sur un être pour frapper, sur une tuile pour s'y rendre, capacités par F1-F3 puis clic. Le clavier n'entre jamais dans la logique : le client convertit une touche en intention de déplacement d'une tuile ([[Contraintes permanentes]]).

> [!success] Codé le 2026-08-28 — Inventaire + équipement, Atelier, Feuille (`scenes/demo/ecrans.gd`)
> Trois écrans en **Control Godot construits par code** (aucun asset) : un panneau centré, une liste à gauche, le détail à droite, des boutons. **I** inventaire (les 9 emplacements d'équipement puis le sac ; Équiper/Retirer, Jeter, Lire, Sertir ; E/J/L/T au clavier, Entrée = action, ↑↓), **F** atelier (toutes les recettes des stations du sac, faisables en tête ; le détail **déplie l'obtention** de chaque composant récursivement — famille → station → transformation plate → récolte ; les recettes exotiques inconnues en **silhouette** « ??? » avec leurs sources), **C** feuille (vitaux, stats et potentiels, compétences par catégorie, équipement). **Échap** ferme ; un seul écran à la fois ; les clics dans un panneau ne traversent pas vers le jeu. L'**infobulle exhaustive** d'un objet : type, emplacement, rareté, qualité (palier + valeur), dés/ticks/portée de l'arme, dureté et facteur de dégâts, armure, vecteur Wu Xing, vitesse du manche, composants, affixes avec leurs paramètres, sertissures, livre, station, 13 stats du matériau. Nouvelles intentions côté simulation : `desequiper` (slot → sac) et `jeter` (l'objet tombe en butin sur la tuile). Le poids porté, la carte, la gestion de claim et la minimap attendent leurs étapes.

## Liens
- **Dépend de** : [[Direction artistique]], [[Localisation]]
- **Alimente** : [[Combat tactique sur grille]], [[Craft compositionnel]], [[Habitat des PNJ]], [[Entretien et taxes]]
- **Voir aussi** : [[Minimap et brouillard de guerre]], [[Wu Xing — cycles et vecteurs]], [[Vocabulaire des modules — six axes]], [[Tooltips contextuels]], [[Dialogue PNJ]], [[Éditeur de sculpture]], [[Arborescence du projet]]
