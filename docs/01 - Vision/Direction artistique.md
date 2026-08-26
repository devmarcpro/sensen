---
aliases: ["9", "9. Direction artistique", "DA", "Direction artistique"]
tags: [vision, art, décidé]
domaine: vision
statut: décidé
etape: 1
---

Comment le jeu se donne à voir : isométrique, tuiles teintées, billboards paperdoll, et l'effort visuel placé dans la lisibilité plutôt que l'animation.

**Vue isométrique, tuiles 3D basses, personnages en billboards paperdoll pixel art** (façon Dofus/Wakfu).

- **Le terrain** : tuiles instanciées, teintées par matériau, avec des faces latérales visibles pour lire le dénivelé (l'échelle de hauteur doit être immédiatement lisible — c'est une information tactique, pas une décoration).
- **Les personnages** : sprites en couches (paperdoll) — un **rig articulé de 14 segments** pour les humanoïdes ([[Squelette modulaire et points d'attache]]), équipement visible par slot, teintes par instance. Le pipeline modulaire de [[Schéma unifié créature-PNJ]] survit intégralement : ce sont les mêmes bibliothèques de parties, en 2D au lieu de .vox.
- **Les orientations ne sont pas redessinées** : les 8 directions viennent de l'**ordre de calque**, des décalages d'ancrage et du miroir horizontal. Une seule passe de sprites — et l'animation (marche, frappe, garde) vient de la rotation des segments autour de leurs articulations, **sans dessiner de frames**. C'est ce qui rend le paperdoll tenable en solo : ≈ 130 sprites pour tous les humains du jeu et toute leur armure.
- **Identité visuelle : chinoise assumée** — c'est ce qui distingue réellement Sensen, bien plus qu'une perspective. Palette d'encre et de brumes, architecture, motifs, calligraphie dans l'UI, pentagramme Wu Xing. Les jeux du genre sont tous vaguement médiévaux-européens ; celui-ci ne l'est pas.
- **La lisibilité prime sur le réalisme** : contours nets, silhouettes distinctes, couleurs élémentaires cohérentes (les cinq éléments ont leurs teintes, partout — jauge, effets, gemmes, tooltips).
- **Effets** : peu d'animation, beaucoup de feedback d'interface — chiffres flottants, flashs brefs, particules courtes. L'effort visuel passe dans l'**UI de lisibilité** (timeline, prévisualisations, journal), qui est le vrai game feel d'un tactique.

> [!success] Décidé le 2026-08-26 — les teintes des cinq éléments
> Les couleurs traditionnelles du Wu Xing, utilisées partout (jauge, effets, gemmes, tooltips) : **Bois** vert `(0.25, 0.70, 0.35)` · **Feu** rouge `(0.90, 0.25, 0.15)` · **Terre** jaune-ocre `(0.85, 0.70, 0.20)` · **Métal** blanc `(0.90, 0.90, 0.92)` · **Eau** bleu profond `(0.15, 0.30, 0.75)`. Déclarées dans `data/wuxing.json` (`teintes`), lues par le rendu — jamais recopiées dans le code.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Piliers d'inspiration]]
- **Alimente** : [[Squelette modulaire et points d'attache]], [[Écrans d'interface]], [[Palette de couleurs des matériaux]]
- **Voir aussi** : [[Identité visuelle chinoise]], [[Combat tactique sur grille]], [[Hauteur de terrain ±10]]
