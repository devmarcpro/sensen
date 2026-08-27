---
aliases: ["7.5", "7.5 Habitat des PNJ", "Habitat", "Logement", "Humeur", "Bétail"]
tags: [société, décidé]
domaine: société
statut: décidé
etape: 7
---

> [!note] Adapté au pivot tactique
> Critères volumétriques convertis en surfaces de tuiles (valeurs décidées : [[Décision — Pièces en 2D]]).

Les PNJ résidents ont des besoins de logement, et l'humeur qui en découle est LE levier de rendement du territoire.

Les PNJ résidant sur la base/claim du joueur (compagnons recrutés, animaux — [[Schéma unifié créature-PNJ]]) ont des **besoins de logement**, selon leur statut :

- **PNJ normal** — a besoin d'une **pièce** remplissant toutes ces conditions :
  - Fermée, avec une **porte**
  - Au moins **un meuble** (n'importe lequel)
  - Un **toit**
  - Surface minimale en tuiles ([[Décision — Pièces en 2D]] : **≥ 4 tuiles**)
- **Statut "bétail"** — a juste besoin d'un **toit** (abri simple, pas de pièce fermée requise).

**Implications techniques :** nécessite un algorithme de **détection de pièce** (espace clos + porte + toit) — à ranger dans `systems/` ([[Arborescence du projet]]). Voir [[Détection de pièces]]. Le statut bétail/normal est un champ modifiable de l'entité créature ([[Schéma créature]]).

**Règles :**
- **Besoin non satisfait :** le PNJ **reste** mais subit un **malus** (humeur/productivité) — pas de départ.
- **Partage de pièce :** possible, mais avec malus (−5 humeur par co-occupant au-delà du premier).
- **Statut bétail vs normal :** **assigné par le joueur lui-même** (il choisit de traiter une créature comme résident ou comme bétail).

**Décisions :**
- **Malus chiffrés :** sans logement valide : humeur **−15** · pièce partagée : **−5** par co-occupant au-delà du premier. **Effet de l'humeur :** la productivité des jobs ([[Abstraction hors-site]]/[[Population et exploitation]]) est multipliée par `humeur/100 × 1.5` borné **[0.4, 1.2]** — l'humeur est LE levier de rendement.
- **Meilleure chambre : oui** — **+1 humeur par type de meuble distinct** dans la pièce (max +10), **+5 si surface ≥ 9 tuiles**. Les meubles à bonus propres (tapis, trophée, [[Meubles]]) s'ajoutent.
- **Rétrogradation en bétail : oui, le PNJ réagit** — relation **−30**, humeur **−20** (durables tant que le statut persiste). Traiter un roi en bétail a un prix relationnel, en plus du prix diplomatique ([[Population et exploitation]]).

**Capacité des villages ([[Villages PNJ — repeuplement et décimation]]) :** le même algorithme de détection de pièces, appliqué aux bâtiments du village, donne sa capacité.

**Malus de régime ([[Gouvernance, lois et diplomatie]]) :** changer la gouvernance de son royaume applique −10 d'humeur temporaire sur la population pendant 4 semaines.

**Rôle de case dédié ([[Rôles de cases]]) :** « Habitation » — seules les pièces de ce rôle comptent pour la capacité de logement.

> [!success] Codé le 2026-08-28
> Au passage de semaine, l'humeur d'un résident est **recalculée** : `60 − 15 sans pièce valide autour de son lit` ; pièce valide : **+1 par type de meuble distinct** (max +10), **+5 à 12 tuiles**, **−5 par co-occupant** au-delà du premier (autres résidents dont le lit est dans la même pièce) ; puis la faim (−10 sans nourriture au garde-manger) et la dette. Le statut bétail et la rétrogradation attendent (pas de bétail-résident pour l'instant).

## Liens
- **Dépend de** : [[Détection de pièces]], [[Construction cadrée]], [[Rôles de cases]], [[Schéma créature]]
- **Alimente** : [[Population et exploitation]], [[Abstraction hors-site]], [[Villages PNJ — repeuplement et décimation]], [[Entretien et taxes]]
- **Voir aussi** : [[Meubles]], [[Faim des PNJ]], [[Réputation et relations]], [[IA des créatures]], [[LOD de simulation]], [[Compagnons]], [[Écrans d'interface]]
