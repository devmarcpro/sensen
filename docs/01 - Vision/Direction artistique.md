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
- **Les personnages** : sprites en couches (paperdoll) — corps, tête, équipement visible par slot, teintes par instance. Le pipeline modulaire de [[Schéma unifié créature-PNJ]] survit intégralement : ce sont les mêmes bibliothèques de parties, en 2D au lieu de .vox.
- **Identité visuelle : chinoise assumée** — c'est ce qui distingue réellement Sensen, bien plus qu'une perspective. Palette d'encre et de brumes, architecture, motifs, calligraphie dans l'UI, pentagramme Wu Xing. Les jeux du genre sont tous vaguement médiévaux-européens ; celui-ci ne l'est pas.
- **La lisibilité prime sur le réalisme** : contours nets, silhouettes distinctes, couleurs élémentaires cohérentes (les cinq éléments ont leurs teintes, partout — jauge, effets, gemmes, tooltips).
- **Effets** : peu d'animation, beaucoup de feedback d'interface — chiffres flottants, flashs brefs, particules courtes. L'effort visuel passe dans l'**UI de lisibilité** (timeline, prévisualisations, journal), qui est le vrai game feel d'un tactique.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Piliers d'inspiration]]
- **Alimente** : [[Squelette modulaire et points d'attache]], [[Écrans d'interface]], [[Palette de couleurs des matériaux]]
- **Voir aussi** : [[Identité visuelle chinoise]], [[Combat tactique sur grille]], [[Hauteur de terrain ±10]]
