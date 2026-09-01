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

> [!success] Décidé le 2026-08-28 — les ressources récoltables sont des billboards (instruction du designer)
> « Je veux que les ressources récoltables soient des sprites billboard (arbres, plantes). » Les arbres et les plantes sauvages ne sont plus des blocs de terrain : ce sont des **billboards dessinés par code** (`scenes/entities/vegetal.gd`, pas d'asset), comme les paperdolls — une silhouette de `data/vegetaux/` (feuillu, conifère, palme, buisson, herbe) teintée par le matériau de l'essence (palette), triée en profondeur avec les êtres. Les rochers et filons restent des blocs (ce sont des reliefs). Côté simulation rien ne change : un arbre est un contenu de tuile qui bloque le passage et la vue, une plante un contenu franchissable ; les deux se récoltent (hache, faucille).

> [!info] Précisé le 2026-09-01 — le full code est un choix d'étape, pas un dogme (designer)
> Le « tout est dessiné par code, aucun asset » qui traverse ces notes est **l'état actuel du projet, pas une interdiction définitive** : le designer compte **ajouter des assets plus tard**. Ce qui suit reste donc vrai pour le prototype — chaque forme est un polygone, chaque texture viendra d'un shader — mais aucune décision ne doit être écrite comme si les images étaient bannies pour toujours. En pratique : ce qui est dessiné par code doit rester **remplaçable** par une image (une silhouette, un portrait, une tuile), et les catalogues de données doivent continuer à décrire *quoi* dessiner plutôt que *comment*.

> [!success] Codé le 2026-09-01 — le décor a un grain (designer, point 50)
> Les surfaces n'étaient que des aplats de la couleur du matériau. Elles reçoivent maintenant une **texture calculée**, dans l'esprit de Voxen : un `ShaderMaterial` posé sur le calque du monde (`shaders/grain.gdshader`) module la couleur d'origine par un **grain fin** — une case de `taille_grain` unités du monde = une teinte, tirée d'un hachage déterministe — et par une **variation douce** basse fréquence, pour que la roche ne soit ni un aplat ni du bruit. La couleur du matériau n'est jamais remplacée : elle est **modulée**, donc la palette des données reste la source.
>
> **Précision du designer (4 h 05) : le grain doit suivre le relief, pas rester plat.** C'est corrigé — chaque face porte désormais des **UV dans son propre plan** (le sol : les coordonnées de la tuile ; une paroi : sa longueur et sa hauteur), et le shader lit ces UV. Le grain épouse donc l'inclinaison isométrique : sur le sol, les grains sont des losanges ; sur un mur, ils descendent avec la paroi.
>
> Le grain est calculé à partir de ces UV : il est fixé au monde, ne « nage » pas quand la caméra bouge, et ne coûte rien (une passe de fragment, pas de texture en mémoire). Ses quatre chiffres vivent dans `styles.json → grain` — un `actif: false` rend les aplats d'avant.

> [!failure] Annulé le 2026-09-01 — pas de rendu pixelisé (designer)
> Le rendu en basse résolution agrandie a été codé puis **retiré sur décision du designer**, avec le zoom de la carte. Ce que l'essai a montré, pour mémoire : à 640 × 360 le pixel est franc mais l'interface mange l'écran (une police de 13 px occupe le triple de sa place relative) ; à 960 × 540 l'équilibre est meilleur mais le pixel se voit à peine. Le jeu reste donc rendu **net**, à la résolution de la fenêtre. Le grain procédural des matières (points 50 et 58), lui, demeure : c'est lui qui donne la texture, pas la résolution.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Piliers d'inspiration]]
- **Alimente** : [[Squelette modulaire et points d'attache]], [[Écrans d'interface]], [[Palette de couleurs des matériaux]]
- **Voir aussi** : [[Identité visuelle chinoise]], [[Combat tactique sur grille]], [[Hauteur de terrain ±10]]
