---
aliases: ["4.2.1", "4.2.1 Craft compositionnel", "Craft compositionnel", "Composants craft"]
tags: [objets, craft, décidé]
domaine: objets
statut: décidé
etape: 6
---

Un objet n'est plus une recette monolithique mais un assemblage de composants, chacun dans n'importe quel matériau — la liberté est totale en théorie, gatée par la connaissance des recettes en pratique.

**Principe :** un objet n'est plus une recette monolithique (« épée = 3 bois + 3 métal ») mais un **assemblage de composants**, chaque composant étant crafté séparément, dans **n'importe quel matériau** — la liberté est totale en théorie, gatée par la **connaissance des recettes** en pratique.

**Structure standardisée (granularité figée — éviter les 10 000 items) :**
- Chaque objet = **2 composants majeurs** (porteurs des stats : tête/lame + manche pour outils et armes ; plaque + sangles pour les armures...) + **1 slot de fixations générique** (rivets, ligatures, colle — composant standard partagé par toutes les recettes d'une même table, qui module légèrement la qualité d'assemblage selon son matériau).
- Les composants sont **réutilisés partout** : le même « manche court » sert à la pioche, la hache et le marteau — peu de *types* de composants, beaucoup de *matériaux* possibles. Catalogue de composants en [[Composants]].

**Composant logique :** la recette d'un objet référence des **slots typés** (« une tête de pioche »), jamais un matériau (« une tête en fer »). Chaque composant a ses **recettes d'obtention** par familles de matériaux, chacune avec sa table requise et sa condition de déblocage (schéma [[Composant et recette d'obtention]]).

**L'équilibrage par la connaissance :**
- Les **recettes de base** (manche en bois, tête en lingot métallique...) sont connues d'office.
- Les **recettes exotiques** (manche en os, en or, lame d'obsidienne, de verre...) s'**apprennent** : loot de donjon (parchemins de recette, même logique que les grimoires [[Grimoires et manuels]]), achat chez des marchands spécialisés, enseignement de guilde (secrets d'artisans par rang, [[Quêtes et guildes]]) — et certaines demandent une **table plus avancée**. Nouvelle boucle de collection, parallèle aux modules.

**Navigation des recettes (l'UI qui enseigne le système) :**
- La recette affiche ses slots de composants ; **cliquer sur un composant déplie son obtention** (tête de pioche → un lingot, à l'enclume), **récursivement** (lingot → minerai + four ; minerai → où ça se mine). La recette EST le tutoriel — cohérent avec [[Tooltips contextuels]] (information pure, jamais de verrou).
- **Recettes non connues : affichées en silhouette** (« ??? — recette inconnue, se trouve en donjon/guilde ») — la découverte reste visible sans être révélée. Les recettes de base sont toujours dépliables intégralement.

**Friction early game — résolue par la boucle existante, pas par un mode simplifié :** le loot de donjon ([[Donjons — structure et intégration]]) et les boutiques couvrent le besoin d'équipement pendant que le joueur apprend le craft. Le craft n'est pas la porte d'entrée obligée de l'équipement.

**Fonte et façonnage séparés (chaîne du métal) :**
- **Four/Forge** : fonte — minerai → lingot (+ sable → verre, argile → brique).
- **Enclume** (nouvelle station, [[Stations de transformation]]) : façonnage — lingot → composants métalliques (têtes, lames, plaques, rivets).
- Les autres chaînes suivent la même logique avec leurs stations existantes : Scierie → composants en bois (manches, hampes), Atelier de tissage → sangles/rembourrages, Tailleur de pierre → composants en pierre.

**Qualité — par composant, avec jet d'assemblage ([[Stats et qualité de l'assemblage]]) :** chaque composant a sa propre qualité ([[Qualité d'artisanat]], sur la compétence de sa station) ; l'assemblage final fait une **moyenne pondérée des qualités des composants + un jet sur la compétence d'assemblage** — un maître assembleur tire le meilleur de composants moyens, un débutant gâche des composants excellents.

**Wu Xing composite ([[Wu Xing — cycles et vecteurs]]) :** l'alignement élémentaire de l'objet dérive de ses composants — une arme manche-bois/tête-métal est alignée **Bois ET Métal** (chaque alignement au prorata du poids du composant). Tout-métal = fort contre Bois mais vulnérable au Feu ; mixte = polyvalent sans bonus franc. Le choix des matériaux de composants devient un choix d'alignement.

**Niveaux de recette — les doublons approfondissent :** chaque recette a **5 niveaux** ; apprendre une recette déjà connue la fait monter (coût croissant : N doublons pour passer au niveau N, soit 10 au total). Aucun parchemin n'est un loot mort. L'enseignement par un artisan à haute relation ([[Réputation et relations]]) devient le moyen **volontaire** de cibler une recette précise. *Axe de bonus à trancher au playtest* (efficacité matière / vitesse et lots / stabilité du jet) — **contrainte non négociable : le niveau de recette ne multiplie jamais la qualité**, sinon farmer des parchemins court-circuite la progression de compétence. → [[Ouvert — Axe des niveaux de recette]]

**Généralisation :** ce paradigme couvre armes, outils, armures — et les véhicules ([[Véhicules]]) fonctionnaient *déjà* ainsi (coque + roues + mât) : le craft entier du jeu devient un seul modèle compositionnel.

*(La chimie élémentaire — Extracteur/Synthétiseur, 58 éléments — a été **supprimée** le 2026-08-09 : trop lourde en contenu pour un système purement endgame, et redondante avec le Wu Xing sur « de quoi est fait un matériau ». Une seule couche élémentaire subsiste, dérivée de la catégorie ([[Wu Xing hors combat]]). Le rôle d'endgame d'artisanat est repris par les **recettes industrielles** — voir [[Palier industriel]].)*

**Contenu à produire :** [[Ouvert — Recettes de composants par famille]].

> [!success] Codé le 2026-08-28 — `data/components/` (14), `data/component_recipes/` (la matrice), objets assemblés `data/items/craft_*`
> Le modèle de la note tel quel : un objet = ses **slots** de composants (`slots` de la fiche d'objet) + une recette d'assemblage (station, compétence) ; un composant = une recette d'obtention par **famille de matériaux** (`data/material_families.json` traduit chaque famille en filtre : catégorie/matériau + forme — `lingot_metal` = tout métal en lingot, `bois` = toute essence en planche…). Un composant consomme **une unité** de la famille et porte les 13 stats et le vecteur Wu Xing de son matériau, plus sa **qualité** (A.3 sur la compétence de sa station). Les recettes exotiques (`unlocked_by_default: false`) attendent leurs sources (`e.recettes_connues`) — parchemins, marchands, guildes viennent avec les étapes 3-9. **Décisions** : l'assemblage se fait à l'**Établi** (la « table d'assemblage » de la note), avec la compétence de la recette d'objet (Forge pour les armes et armures de métal, Menuiserie pour les outils) ; les niveaux de recette restent ouverts ([[Ouvert — Axe des niveaux de recette]]) et ne sont pas codés. Le laminoir (contrepoids en tungstène) attend le [[Palier industriel]].

> [!success] Codé le 2026-08-29 — le tannage : la famille `cuir` avait des recettes mais aucune source
> Trou trouvé en relisant les données : `material_families.cuir` (matériau `cuir`, forme brute) alimente `component_recipes/sangles_cuir` et les armures légères, mais **rien au monde ne produisait de cuir** — ni loot, ni filon, ni recette. Nouvelle recette **`tanner_cuir`** (atelier de tissage, compétence **Cuir**, 2 peaux → 1 cuir brut) : la peau des bêtes (`creatures.*.depouille`) devient la matière des sangles et des armures. Décision : le tannage se fait à l'**atelier de tissage** (pas de cuve à tanner : la note *Stations de transformation* en fixe neuf, on n'en ajoute pas une dixième pour une recette).

> [!success] Corrigé le 2026-08-29 — 33 recettes « meuble_x → meuble_x » supprimées
> Troisième pan du défaut signalé par le designer. `recipes/` portait **une recette par meuble et par station** (`meuble_chaise`, `meuble_table`, `station_forge`… — 24 + 9), chacune ne disant qu'une chose : « ce meuble coûte ça ». Un meuble neuf n'était donc constructible qu'après l'écriture d'un fichier de plus, avec sa clé de localisation. Le **coût monte sur la fiche de l'objet** (`items/meuble/*.json` → `recipe: {station, craft_skill, inputs}`), et `GameData._deriver_recettes_objets` en dérive la recette au chargement, sous l'id de l'objet — rien ne change pour le code qui lit `catalogues.recipes`, ni pour les intentions `fabriquer`. **Décisions** : le nom de la recette est le nom de l'objet (33 clés de traduction en moins) ; un objet à `slots` ne dérive rien (il passe par l'assemblage) ; une recette plate du même nom qu'un objet à coût est une **erreur de données** au boot. Les 24 recettes de transformation (fondre, scier, tanner…) restent des recettes : elles transforment une catégorie en une forme, elles sont déjà catégorielles.

## Liens
- **Dépend de** : [[Composants]], [[Composant et recette d'obtention]], [[Stations de transformation]], [[Qualité d'artisanat]]
- **Alimente** : [[Stats et qualité de l'assemblage]], [[Palier industriel]], [[Équipement — 14 slots]], [[Armure par zone et constructions]], [[Véhicules]]
- **Voir aussi** : [[Wu Xing — cycles et vecteurs]], [[Armes fantomatiques]], [[Grimoires et manuels]], [[Quêtes et guildes]], [[Tooltips contextuels]], [[Ouvert — Axe des niveaux de recette]], [[Ouvert — Recettes de composants par famille]]
