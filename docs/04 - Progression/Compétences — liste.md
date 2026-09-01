---
aliases: ["C.4", "Annexe C.4", "Compétences", "Liste des compétences"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

La liste de départ, ~30 compétences réparties en cinq familles.

- **Armes :** Épée, Hache d'armes, Masse, Lance, Dague, Arc, Arbalète, Bâton magique, Mains nues, Bouclier, Dual Wielding, Deux Mains
- **Magie :** Méditation (régén mana), Contrôle du Mana (surchauffe), + 1 compétence par domaine de grimoire (voir [[Domaines de grimoires et manuels]])
- **Récolte :** Minage, Bûcheronnage, Terrassement, Herboristerie, Collecte
- **Artisanat :** Forge, Menuiserie, Taille de pierre, Tissage, Alchimie, Cuisine, Enchantement
- **Vie :** Lecture, Négociation, Dressage, **Leadership** (capacité d'escorte, [[Compagnons]]), Agriculture, Élevage, Discrétion, Athlétisme (course/saut/nage)

**Esquive — redéfinie ([[Décision — Esquive active]]) :** mobilité de combat — réduit le coût de déplacement en combat (`3 ticks × (1 − min(0.33, N × 0.005))`, min 2) ; XP en se déplaçant sous menace. **Compétences supplémentaires citées ailleurs :** Encaissement ([[Pipeline de résolution du combat]], [[Double niveau combat et général]]), Navigation ([[Véhicules]], [[Double niveau combat et général]]), et les **compétences de construction d'armure** — Matelassé, Cuir, Mailles, Écailles, Plaque ([[Armure par zone et constructions]], [[XP de combat]]).

**Classification combat/général :** champ `category` par compétence — voir [[Double niveau combat et général]].

**Chaque compétence a son potentiel** ([[Potentiel]]) et suit la courbe unique de [[Progression par l'usage]].

**Mappage catégorie → compétence de récolte :** [[Catégories de matériaux]].

**Mappage fonction → compétence :** voir [[Fonctions]] (troisième axe de [[Les trois axes — race, classe, fonction]], ex-postes de travail).

> [!success] Décidé et codé le 2026-09-01 — Escalade et Nage, deux compétences de franchissement (designer, points 56 et 57)
> Une paroi n'est plus un mur ni un pas ordinaire : au-delà d'une marche, on **grimpe**, et le coût monte avec le **carré de la hauteur** (`escalade.ticks_par_niveau` × dh²) puis se divise par le facteur de la compétence **Escalade** et par la charge portée. Au-delà de `hauteur_max` (6 niveaux), la paroi reste infranchissable : la compétence rend les falaises longues, jamais gratuites. Sur le même modèle, chaque tuile d'eau coûte `nage_progressive.ticks_par_tuile` divisé par la compétence **Nage** et la charge — un nageur chargé rampe, un nageur entraîné file.
>
> Les deux compétences entrent au catalogue (`competences/escalade.json`, `nage.json`, catégorie *général*, sur Force et Endurance) et **progressent par l'usage** : grimper d'un dénivelé rapporte autant d'XP que sa hauteur, nager une tuile en rapporte une. Aucun chiffre n'est écrit dans le code : tout vit dans `combat_rules.deplacement`.

> [!success] Codé le 2026-09-01 — la compétence **Chasseur** décide ce qu'on tire d'une bête (designer, point 71)
> « compétence chasseur qui détermine si on obtient du loot spécifique à l'ennemi (dents, peau, yeux, fourrure etc), plus le niveau de compétence est élevé plus on en obtient ». Jusqu'ici la dépouille tombait **toujours**, sans jet ni compétence : tuer un ours donnait sa peau qu'on soit boucher ou mage. Chaque pièce de dépouille passe désormais un **jet de compétence universel** sur Chasseur, contre une difficulté qui monte avec la taille de la bête (ses PV) ; la réussite donne la pièce, et **une réussite large en donne plusieurs** (une pièce de plus par tranche de marge, plafonnée). Un novice repart souvent avec de la viande et rien d'autre ; un chasseur confirmé rapporte la peau, les crocs et les yeux. L'usage entraîne : chaque jet donne son XP, réussi ou non. Les réglages vivent dans `combat_rules.chasse`.


## Liens
- **Dépend de** : [[Progression par l'usage]]
- **Alimente** : [[Double niveau combat et général]], [[Potentiel]], [[Récolte]], [[Qualité d'artisanat]]
- **Voir aussi** : [[Domaines de grimoires et manuels]], [[Compagnons]], [[Armure par zone et constructions]], [[Catégories de matériaux]], [[Astrologie — cycle sexagésimal]], [[Effets d'équipement types]]
