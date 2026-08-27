---
aliases: ["C.8", "Annexe C.8", "Stations", "Stations de transformation", "Transformation"]
tags: [objets, craft, contenu, décidé]
domaine: objets
statut: décidé
etape: 6
---

Les 8 stations de transformation, leurs recettes principales, et le principe portative/fixe.

**Transformation et stations (4.2) :**
- Par défaut, un matériau récolté correspond à un bloc ; il peut être transformé (raffiné/travaillé) en d'autres formes (ex : minerai → lingot).
- Toute transformation nécessite une **station dédiée** (forge, scierie, etc.).
- Une station peut être :
  - **Portative** : portée dans l'inventaire du joueur si son poids le permet — les recettes des stations transportées apparaissent alors dans la fenêtre de craft.
  - **Fixe sur une case claim** : les recettes des stations posées sur la case revendiquée par le joueur sont disponibles tant que le joueur se trouve sur cette case.

**Liste (C.8) :** Établi (générique), Forge, Scierie, Tailleur de pierre, Atelier de tissage, Alambic, Cuisine, Table d'enchantement — plus les **5 tables de sculpture** (items, armes, blocs, meubles, véhicules), qui se débloquent uniquement via les rangs de guilde (voir [[Tables de sculpture]]).

**Ajout craft compositionnel ([[Craft compositionnel]]) :** **Enclume** (façonnage : lingot → composants métalliques), séparée de la Forge (fonte : minerai → lingot). Les composants en bois viennent de la Scierie, les sangles de l'Atelier de tissage, les composants en pierre du Tailleur de pierre.

**Stations du palier industriel ([[Palier industriel]]) :** améliorations des stations existantes — Forge → **Haut fourneau**, Enclume → **Laminoir** — débloquées par recettes trouvées/achetées, consommant du combustible (coke, charbon) à chaque opération.

**Décisions (4.2) :**
- **Transformations principales (station → recettes) :** Forge : minerai→lingot (fonte), sable→verre, argile→brique · **Enclume : lingot→composants métalliques (façonnage, [[Craft compositionnel]])** · Scierie : tronc→planches, bois→papier, planches→composants bois (manches, hampes) · Tailleur de pierre : roche brute→pierre taillée/pavés/composants pierre · Atelier de tissage : fibres→tissu, paille→chaume, tissu→sangles/rembourrages · Alambic : liquides→extraits/potions · Cuisine : ingrédients→plats ([[Nourriture]]) · Table d'enchantement : gemmes→gemmes taillées (+ enchantement futur, [[Effets d'équipement passifs]]). Le détail vit en données (`data/recipes/`), extensible sans code. **Les objets finaux s'assemblent depuis des composants ([[Craft compositionnel]])** — les recettes plates ne subsistent que pour les transformations de matériaux et les consommables.
- **Stations portatives :** chaque station a un poids élevé (**établi 35, forge 80, scierie 60, autres 40-60**) intégré au système de capacité existant ([[Armures et poids porté]] : `30 + Force×5`) — transporter une forge est possible mais engage l'essentiel de la capacité d'un personnage non spécialisé.

**Entretien du royaume ([[Entretien et taxes]]) :** chaque station compte comme structure spéciale (25 or/semaine).

> [!success] Précisé le 2026-08-28
> Les 5 tables de sculpture sont abandonnées ([[Tables de sculpture]]) : les stations sont les 8 de base plus l'Enclume.

> [!success] Codé le 2026-08-28 — `data/stations/` (9), `data/recipes/` (9 transformations plates), intention `fabriquer`
> Les 8 stations de base + l'Enclume en données (poids de la note : établi 35, forge 80, scierie 60, autres 40-60 ; compétence de la station). **Portative** = un objet `station_<id>` (type `station`) dans le sac : ses recettes apparaissent (touche **F**, chiffre pour fabriquer) ; la version **fixe** attend le claim (étape 7), le poids porté attend [[Armures et poids porté]]. **Décisions** : chaque personnage part avec un **établi portatif** (« le jeu démarre sans forge », la voie pierre/os est connue d'office) ; les autres stations se trouvent dans les coffres de donjon en attendant le camp. Une recette plate transforme des matériaux bruts en **formes** (`brut`, `lingot`, `planche`, `pierre_taillee`, `tissu`, `taillee`) ou en un autre matériau (sable → verre, argile → brique, bois → papier, paille → chaume) ; ses entrées se disent par matériau ou par catégorie (`fondre_lingot` vaut pour tous les métaux). Durée = `craft.ticks_base / skill_factor(N)` ; XP à la compétence de la station = dureté du matériau produit. Aucune qualité sur ces transformations (les matériaux n'en ont pas — [[Qualité d'artisanat]]).

## Liens
- **Dépend de** : [[Catégories de matériaux]], [[Claims et persistance]]
- **Alimente** : [[Craft compositionnel]], [[Palier industriel]], [[Tables de sculpture]], [[Cuisine et alchimie]]
- **Voir aussi** : [[Armures et poids porté]], [[Composants]], [[Effets d'équipement passifs]], [[Entretien et taxes]], [[Écrans d'interface]], [[Fabrication d'outils]]
