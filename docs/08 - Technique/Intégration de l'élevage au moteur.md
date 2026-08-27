---
aliases: ["H.8", "Annexe H.8", "Intégration de l'élevage au moteur", "Crochets d'élevage"]
tags: [technique, élevage, architecture, décidé]
domaine: technique
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> **Rien de nouveau côté moteur : tout existe.** Le système d'élevage s'accroche entièrement sur des mécanismes déjà spécifiés.

Où chaque besoin de l'élevage se branche, et l'inventaire exact du code spécifique.

## Les points d'accroche

| Besoin | Où ça s'accroche |
|---|---|
| **capture** | une occupation par verbe : `filet`, `ligne`, `appât`, `ramassage`, `nasse` — jets standards ([[Jet de compétence universel]]) |
| **élevage** | `tickCouvees()` générique, lit `moteur` et applique `HERITE[type]` **locus par locus** ([[Loci — les dix types]]) |
| **habitats** | des **meubles** ([[Meubles]]) posés sur les cases claim ([[Rôles de cases]]), avec leurs stats propres |
| **croissance, mues, migrations, colonies** | le **passage hebdomadaire** ([[Simulation du monde — performance]] : timer wheel, déjà en place pour cultures, corruption, raids) |
| **registre** | un mode de rendu par groupe : `grille`, `records`, `galerie`, `familles`, `séquences`, `studbook` ([[Écrans d'interface]]) |

## Inventaire du code spécifique

Pour **trente-cinq groupes possibles** ([[Catalogue des groupes d'élevage]]) :

- **10 types de loci** ([[Loci — les dix types]])
- **15 conditions** ([[Conditions de reproduction]]), prédicats de trois lignes
- **6 coûts**
- **6 crochets** : éclosion, tick d'âge, passage hebdomadaire, rendu du registre, verbe de capture, stats de l'habitat
- **0** `if (espèce === 'x')`

> **C'est la mesure que le découpage tient.**

## Les données

Un nouveau catalogue `species/` ([[Décision — Pipeline de contenu]]) : une fiche par espèce déclarant ses **loci**, son **moteur d'hérédité**, ses **conditions**, ses **coûts**, son **habitat** et son **mode de registre**. Ajouter une espèce = **un fichier JSON, zéro code** — c'est exactement le contrat du pipeline, appliqué au vivant.

Les êtres eux-mêmes suivent le schéma unique de [[Blocs de l'être]] : le bloc `génome` est présent ou absent, aucun système ne teste l'espèce.

## Note d'adaptation — habitats sur la grille

L'annexe décrit les habitats comme « des meubles dans la grille 4×4 d'un bâtiment ». Sur la grille tactique ([[Grille continue]]), **un habitat est un contenu de tuile** ([[Décision — Structure de données de la grille]]) posé dans une pièce détectée ([[Détection de pièces]]) — le vivarium occupe une tuile et porte ses 4 couvées dans son état. Même principe, vocabulaire de la grille.

> [!success] Codé le 2026-08-28 — première brique (famille « grille à remplir »)
> Catalogue `data/species/` (une espèce : la **carpe de bassin**, loci `couleur` anneau 16, `motif` anneau 8, `taille` nombre) ; les êtres d'élevage sont des **objets** `specimen` (bloc `genome`, `espece`, `sexe`) — capturés au **filet** sur une tuile d'eau adjacente (intention `capturer`, jet `1d20 + Collecte` contre `dd`), génome tiré au hasard. Habitat = meuble **vivarium** (4 emplacements, se remplit comme un coffre). **Passage hebdomadaire** `_semaine_elevage` : pour chaque vivarium de la fenêtre, le premier couple valide se reproduit si les **conditions** (évaluateur unique qui renvoie *pourquoi*, journal) passent — `habitat`, `place`, `temperature`, `saison`, `sexe`, `age`, `stat`, `ressource` ; hérédité **locus par locus** : `anneau` (34/34/16/16 — Règle d'anneau), `nombre` (moyenne × dérive gaussienne, sans plafond), `recessif`, `sequence`, `acquis` (null) ; les autres types attendent. **Registre** `territoire.registre[espece]` = variétés (couleur × motif) obtenues, dans l'écran K. Zéro `if espèce`.

## Liens
- **Dépend de** : [[Élevage — intention et familles]], [[Loci — les dix types]], [[Conditions de reproduction]], [[Décision — Pipeline de contenu]]
- **Alimente** : [[Tests de conformité — élevage]], [[Écrans d'interface]], [[Arborescence du projet]]
- **Voir aussi** : [[Simulation du monde — performance]], [[Meubles]], [[Blocs de l'être]], [[Décision — Structure de données de la grille]], [[Jet de compétence universel]]
