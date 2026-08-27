---
aliases: ["13", "13. Tables de sculpture", "Tables de sculpture", "Sculpture"]
tags: [objets, craft, décidé]
domaine: objets
statut: décidé
etape: 6
---
> [!success] Abandonné le 2026-08-28 — instruction du designer
> « On abandonne complètement les tables de sculpture. » Cette note est conservée comme trace ; **rien de ce qu'elle décrit ne sera codé** : ni tables, ni éditeur, ni modèles sculptés, ni objets nommés par le joueur. Les objets viennent uniquement des recettes ([[Craft compositionnel]], craft simple) et du loot. La pondération des stats d'un objet est celle des composants et des recettes, jamais un comptage de pixels. Les accès par rang de guilde prévus ici disparaissent avec elles ([[Halls de guilde]], [[Quêtes et guildes]]).


> [!note] Adapté au pivot tactique
> Adapté au pivot : sculpture en **pixel art paramétrique** — « voxel par voxel » corrigé en « pixel par pixel ». Détail du pipeline 2D : [[Décision — Sculpture en pixel art]].

Des stations spéciales où le joueur designe lui-même la forme de ses objets — jamais obligatoire, toujours mérité par un rang de guilde.

**Principe :** des stations de craft spéciales — les **tables de sculpture** — permettent au joueur de designer lui-même la forme de ses objets, plutôt que de simplement combiner des matériaux via une recette fixe. **La sculpture n'est jamais obligatoire** : c'est une option pour plus de personnalisation, en plus du craft simple par recette ([[Fabrication d'outils]]) qui reste toujours disponible pour tous types d'objets.

**Catégories de tables :** une table dédiée par type d'objet — **items, armes, blocs, meubles, véhicules**.

**Déroulé :**
1. Le joueur utilise la table correspondant à ce qu'il veut créer.
2. Il choisit la **fonctionnalité** de l'objet (ex : épée, lit, décoratif, etc.) — la fonctionnalité détermine le rôle mécanique de l'objet ([[Fonctionnalité]]).
3. Un **éditeur de sculpture** s'ouvre, avec un **périmètre délimité** dans lequel construire ([[Éditeur de sculpture]]).
4. Le joueur construit la forme avec les **blocs de son inventaire** (les matériaux qu'il possède réellement).
5. Une fois la sculpture **validée**, les **stats de l'objet sont calculées automatiquement**.
6. Le modèle obtenu est **sauvegardé** et **nommé** par le joueur.
7. Le joueur peut ensuite **refabriquer le même modèle à volonté**, tant qu'il dispose des matériaux nécessaires — le design sauvegardé devient une recette réutilisable.

**Lien avec les autres systèmes :**
- Se distingue des objets pré-modélisés par l'équipe (loot, PNJ marchands) qui utilisent la technique de couleurs "stand-in" remappées : ici, le joueur place directement les vrais matériaux pixel par pixel, donc pas besoin de remapping de couleur — la couleur/texture réelle du matériau s'affiche nativement pendant la sculpture.
- S'articule avec le système de matériaux et de compétence d'artisanat ([[Matériaux — 13 stats]], [[Qualité d'artisanat]]).

**Taille du périmètre :** dépend de la table/fonctionnalité choisie (ex : la table à véhicules offre un périmètre bien plus grand qu'une table à items) — chiffres en [[Éditeur de sculpture]].

**Calcul des stats :** dépend **uniquement des matériaux utilisés** (même logique que pour les outils, [[Stats d'un objet crafté]]) — la forme/géométrie n'affecte pas les stats.

**Partage :** un modèle sauvegardé est **partageable avec les coéquipiers en coopératif**.

**Obtention : récompenses de guilde (progression en deux temps)**

Les tables de sculpture ne s'achètent pas et ne se craftent pas librement : elles se **débloquent en montant en rang dans les guildes** ([[Quêtes et guildes]]), en deux étapes par table :
1. **Rang intermédiaire** : droit d'utiliser les tables publiques présentes dans les locaux de la guilde.
2. **Rang supérieur** : obtention de la **station personnelle** (à poser sur son claim ou transporter, comme toute station — [[Stations de transformation]]).

| Table de sculpture | Guilde |
|---|---|
| Blocs / structures | Bâtisseurs |
| Meubles | Bâtisseurs (rang inférieur à celui des structures) |
| Armes | Guerriers / Gladiateurs |
| Items | Artisanat/commerce |
| Véhicules | Navigateurs / Transporteurs |

Ça renforce l'identité mécanique de chaque guilde (récompense désirable au-delà de l'or) et fait de la sculpture un privilège mérité, cohérent avec son statut optionnel.

**Décisions :**
- **Qualité sur les objets sculptés : oui** — même formule [[Qualité d'artisanat]], sur la compétence d'artisanat associée à la table utilisée. Un objet sculpté = stats des matériaux (pondération par pixels) × qualité, exactement comme un craft simple.
- **Contrainte de forme : aucune** — forme totalement libre, la fonctionnalité choisie fait foi. **Unique exception : les véhicules** ([[Véhicules]], blocs fonctionnels requis).
- **Partage : échange manuel explicite** — le créateur pousse un design vers le **catalogue de groupe** sur action volontaire ([[Éditeur de sculpture]]) ; jamais de partage automatique.
- **Rangs de déblocage (structure 5 rangs, [[Quêtes et guildes]]) :** accès aux tables des locaux de guilde au rang **3 (Adepte)** ; station personnelle au rang **4 (Expert)**.
- **Tables partagées entre deux guildes : chemins indépendants, conditions identiques** — rang 3/4 dans l'une OU l'autre suffit.

**Ce qui survit de la construction voxel ([[Construction cadrée]]) :** les tables de sculpture pour les **objets** — armes, meubles, véhicules — désormais en pixel art paramétrique plutôt qu'en voxel.

## Liens
- **Dépend de** : [[Quêtes et guildes]], [[Stations de transformation]], [[Qualité d'artisanat]], [[Fonctionnalité]]
- **Alimente** : [[Éditeur de sculpture]], [[Véhicules]], [[Meubles]]
- **Voir aussi** : [[Fabrication d'outils]], [[Craft compositionnel]], [[Stats d'un objet crafté]], [[Construction cadrée]], [[Schéma objet et recette]]
