---
aliases: ["Six types de modules", "Assemblage", "Noyau Forme Modificateur", "Types de modules"]
tags: [combat, build, décidé]
domaine: combat
statut: décidé
etape: 0
---

La décision structurante : la FORME est séparée de l'EFFET. C'est ce qui fait que chaque forme multiplie chaque effet gratuitement.

**La décision structurante : la FORME est séparée de l'EFFET.** Si « ligne de 4 » et « dégâts de feu » sont deux modules distincts, chaque forme multiplie chaque effet gratuitement. Cuire la forme dans l'effet obligerait à écrire « projectile de feu », « ligne de feu », « cône de feu » séparément — et le catalogue deviendrait du remplissage.

| Type | Rôle |
|---|---|
| **Noyau** | la charge utile : dégâts, soin, statut, déplacement, terrain, invocation |
| **Forme** | où la charge s'applique : cible unique, ligne, cône, croix, anneau, carré, diagonale, tuile au sol |
| **Modificateur** | altère les paramètres du noyau suivant : portée, taille, puissance, coût en ticks, élément |
| **Condition** | verrou ou bonus : si plus haut, si la cible est isolée, si de dos, si ligne de vue dégagée, si tel segment est en jauge |
| **Déclencheur** | diffère la charge : à l'impact, à l'entrée sur la tuile, après N ticks, sur événement — c'est ce qui permet l'imbrication façon Noita |
| **Liaison** | répéter, alterner, disperser sur plusieurs cibles, propager de proche en proche |

**Règles d'assemblage :** une **capacité** est une séquence ordonnée dans un contenant (grimoire ou manuel d'arme), lue de gauche à droite. Modificateurs et conditions s'accumulent sur le prochain noyau ; un déclencheur encapsule tout ce qui le suit comme charge utile. La séquence entière se résout comme **une seule action**, coûtant `ticks du noyau + surcoûts`. Les slots croissent avec le niveau de l'arme ([[Structure compétences-modules-slots]]).

- **L'élément de la capacité dérive du vecteur de ses modules** — le Wu Xing s'applique intégralement ([[Wu Xing — cycles et vecteurs]]).
- **Une capacité qui touche pose UN segment de chaîne**, quel que soit le nombre de cibles ([[Jauge de chaîne Wu Xing]]).

**Exemples :**
- `[Ligne 4] + [Dégâts Feu]` → jet de flammes droit devant
- `[Portée +2] + [Anneau r1] + [Poussée]` → repousse tout ce qui entoure une tuile distante, sans toucher le centre
- `[Si plus haut] + [Cible unique] + [Dégâts Métal] + [À l'impact] + [Croix] + [Saignement]` → frappe plongeante qui éclabousse de saignement
- `[Tuile] + [À l'entrée] + [Enracinement Bois]` → glyphe qui immobilise, et pose un segment Bois en se déclenchant

Le même vocabulaire produit une attaque, un contrôle de zone, un piège et un soutien.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Structure compétences-modules-slots]]
- **Alimente** : [[Familles de capacités de la grille]], [[Modules]], [[Jauge de chaîne Wu Xing]]
- **Voir aussi** : [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Wu Xing — cycles et vecteurs]], [[Grimoires et manuels]], [[Sorts cataclysmiques]]
