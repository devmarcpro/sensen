---
aliases: ["Apparence — données et équipement", "Apparence", "Silhouette", "Rendu d'un être"]
tags: [êtres, art, architecture, décidé]
domaine: êtres
statut: décidé
etape: 1
---

> [!success] Précisé le 2026-08-26 (Annexe H)
> **Ce qui définit l'apparence d'un être, ce sont ses données d'espèce et son équipement — jamais son type.** Un roi et un mouton passent par le même pipeline de rendu.

Comment un être se dessine : trois couches de données, aucune branche de code.

## La règle

**L'apparence est entièrement dérivée. Rien n'est dessiné « pour un roi » ou « pour un mouton ».** Trois sources, dans cet ordre :

**1. La fiche d'espèce** donne la **silhouette** — la grille de cases du corps (`corps.silhouette`, [[Blocs de l'être]]) et le template de squelette ([[Squelette modulaire et points d'attache]] : bipède, quadrupède, volant, amorphe, extensible en données). C'est elle qui dit *quelle forme* on dessine.

**2. Le génome** donne les **couleurs et les motifs** — les loci visuels déclarés par l'espèce ([[Loci — les dix types]] : `anneau` pour la couleur et le motif, `carte` pour les taches, `automate` pour les coquillages, `age` pour la ramure ou la dossière). C'est lui qui dit *comment cette forme est peinte*, et il est **hérité** ([[Règle d'anneau]]).

**3. L'équipement** donne les **pièces visibles** — chaque objet équipé s'attache à son point d'ancrage nommé et se superpose dans l'ordre de calque ([[Squelette modulaire et points d'attache]], [[Équipement — 14 slots]]). Une barde sur un quadrupède suit exactement le même chemin qu'un casque sur un humanoïde.

## Ce que ça remplace

Le GDD disait : *« les parties du corps sont purement visuelles ; les stats viennent d'ailleurs (race, classe, niveau) »* ([[Schéma unifié créature-PNJ]]). **C'est précisé, pas contredit** — les parties restent cosmétiques, mais **leur choix n'est plus arbitraire** : il vient du génome, donc il est héritable, donc il est le support de la collection ([[Vivarium — registre et paliers]]).

Un `parts_pool` fixe ([[Schéma créature]]) reste valable pour les êtres **sans bloc `génome`** — un bandit générique tire ses parties au hasard dans son pool, comme avant. Dès qu'une espèce déclare des loci visuels, **le génome remplace le tirage**.

## Les motifs sont des fonctions, pas des images

Le point technique qui fait tenir le volume ([[Vivarium — loci et variétés]]) : un motif est une **fonction de `(x, y)`**, jamais un masque plaqué. Conséquence :

> **La même variété ne rend pas pareil selon l'espèce.** Un jade rayé d'ambre sur un sphinx, ce sont deux grandes ailes barrées ; sur un phasme, trois traits sur une brindille.

Le motif **épouse la silhouette**. C'est ce qui rend 32 espèces × 4 816 variétés visuellement distinctes sans dessiner 154 112 sprites — cohérent avec [[Direction artistique]] (*l'effort visuel passe dans l'UI de lisibilité, pas dans l'animation*) et avec le remapping de palette en shader déjà en place ([[Palette de couleurs des matériaux]], [[Entités et pathfinding — performance]] : recolorisation par instance, meshes partagés).

**Les loci humanoïdes concrets** (teint, cheveux, yeux, taille, carrure, rousseur, pilosité, grisonnement, traits du visage — plus oreille pour l'elfe, barbe et tresses de clan pour le nain) sont déclarés et illustrés dans [[Exemples — dix PNJ générés]].

## Le pipeline de rendu, en une ligne

```
sprite(être) = silhouette(espèce)                     // la forme
             ▸ peinte par génome(loci visuels)        // couleur, motif, âge
             ▸ recolorisée par instance (shader)      // variante rare, statue
             ▸ surchargée des pièces d'équipement     // aux points d'ancrage
```

Aucune étape ne demande *quel type d'être* on dessine. C'est la contrepartie visuelle de la règle d'or de [[Élevage — intention et familles]] : **aucun `if (espèce === 'x')`**.

> [!success] Codé le 2026-08-31 — les loci visuels existent enfin à l'écran (designer, points 39 et 41)
> Le pipeline décrit ici — *silhouette peinte par les loci*, sans jamais demander quel type d'être on dessine — devient du code. `data/apparence.json` déclare six **loci** (tête, yeux, nez, bouche, cheveux, carrure), leurs facteurs et deux palettes (six teints, cinq couleurs de cheveux) ; chaque race porte un bloc `apparence` (`data/races/*.json`) qui donne son **défaut** : le nain est court et large, barbu, ambre et roux ; l'elfe élancé, mince, ivoire, **oreilles pointues** ; le spectre cendré et argenté ; le vampire pâle aux oreilles courtes ; le lycanthrope grand et massif. Le Paperdoll lit ces chiffres — échelle du rig, largeur par carrure, diamètre du crâne, longueur d'oreille et de barbe, visage dessiné sur le disque de la tête — et **aucune branche par race** n'est écrite nulle part.

## Liens
- **Dépend de** : [[Blocs de l'être]], [[Squelette modulaire et points d'attache]], [[Loci — les dix types]]
- **Alimente** : [[Vivarium — loci et variétés]], [[Équipement — 14 slots]], [[Monstres rares]]
- **Voir aussi** : [[Schéma unifié créature-PNJ]], [[Schéma créature]], [[Direction artistique]], [[Règle d'anneau]], [[Entités et pathfinding — performance]], [[Palette de couleurs des matériaux]]
