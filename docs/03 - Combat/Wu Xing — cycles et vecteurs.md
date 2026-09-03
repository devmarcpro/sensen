---
aliases: ["5.2", "5.2 Wu Xing", "Wu Xing", "Cinq éléments", "Vecteur élémentaire"]
tags: [combat, wuxing, décidé]
domaine: combat
statut: décidé
etape: 0
---

Les cinq éléments définis par leurs relations, et le format unique — un vecteur, jamais un élément unique — que parle tout le jeu.

Le système élémentaire du jeu est le **Wu Xing daoïste** — cinq éléments (**Bois, Feu, Terre, Métal, Eau**) définis par leurs **relations** plutôt que par leur nature, via deux cycles en pentagramme :

- **Cycle d'engendrement (生)** : Bois → Feu → Terre → Métal → Eau → Bois (le bois nourrit le feu, le feu crée la terre par ses cendres, la terre produit le métal, le métal enrichit l'eau, l'eau fait croître le bois).
- **Cycle de domination (克)** : Bois ⊳ Terre ⊳ Eau ⊳ Feu ⊳ Métal ⊳ Bois (le bois perce la terre, la terre endigue l'eau, l'eau éteint le feu, le feu fond le métal, le métal tranche le bois).

Aucun élément n'est supérieur : chacun **domine un élément, est dominé par un autre, en nourrit un troisième**. C'est un ciseaux-feuille-pierre à cinq branches avec une couche coopérative.

**Tout porte un VECTEUR élémentaire, jamais un élément unique** : `{metal: 0.75, bois: 0.25}`. Les armes, les armures, les créatures, les modules, les lieux et les matériaux parlent ce format unique — un domaine « métaphysique » n'est pas hors cycle, il est un mélange (Arcane est équilibré à 20 % sur les cinq, donc mathématiquement quasi neutre *par construction*, sans règle d'exception).

**Application au combat (formules en [[Domination et multiplicateurs]]) :**
- **Domination = efficacité** : attaque contre l'élément qu'elle domine → **×1.5** ; contre celui qui la domine → **×0.65** ; contre celui qu'elle engendre → **×0.8** (on n'attaque pas bien ce qu'on nourrit). Sur des vecteurs mixtes, moyenne pondérée : les mix ont des multiplicateurs **adoucis**, c'est leur identité.
- **Côté défense, les multiplicateurs sont compressés** (×1.20 / ×0.85 / ×0.95) : un mauvais matchup défensif est un désagrément, jamais un mur — l'armure est un choix d'identité permanent, pas une variable à optimiser avant chaque donjon ([[Armure par zone et constructions]]).
- **Les dégâts dépendent des composantes ET des niveaux** : `Σ (proportion_e × (1 + niveau_élément_e / 100))`. Une arme mixte exige d'investir dans ses deux éléments pour égaler une arme pure ; en échange, son vecteur amortit les mauvais matchups.
- **JAUGE DE CHAÎNE** — le cœur du combat : voir [[Jauge de chaîne Wu Xing]].
- **Deux voies équivalentes** : la **rotation parfaite** (5 éléments dans l'ordre → coup final ×2.40, multiplicateur maximal, exige un arsenal et une exécution sans faute) et la **construction/détonation** (4 coups rapides d'une arme légère puis une frappe lourde en 5ᵉ → ×1.65 sur une base bien supérieure). Placer sa plus grosse frappe en dernier est la stratégie centrale du système.
- **Un buff peut résoudre la chaîne** : il reçoit le bonus sur sa durée et sa magnitude (×0.7 pour compenser l'absence de risque) — les builds de soutien ont un accès plein au système central.
- **L'élément d'une ARME est celui de sa TÊTE** (les poids de slots [[Stats et qualité de l'assemblage]] garantissent qu'elle domine). Une arme **mono-élément** se fabrique en engageant tous ses composants dans la même famille — le coût est matériel et réel (un manche métallique est dense et conducteur, une tête en bois est faible).
- **Les ARMES FANTOMATIQUES sont pures par nature** : voir [[Armes fantomatiques]].
- **Alignement des cibles** : dérivé du champ `elements` ([[Schéma créature]]) ou des tags pour une créature ; du **vecteur composite des composants** pour un personnage équipé ([[Stats et qualité de l'assemblage]]). L'armure de plates face à un mage de Feu est un vrai handicap.
- **MODIFICATEURS D'AFFINITÉ** : voir [[Modificateurs d'affinité]].
- **Cinq accès au cycle, chacun payé dans une monnaie différente** : voir [[Cinq accès au cycle]].
- **Lisibilité obligatoire** : l'alignement de la cible et le multiplicateur prévu s'affichent au survol ; la jauge de chaîne est toujours visible sous le réticule ; l'écran d'assemblage montre le pentagramme.

**Au-delà du combat (le Wu Xing comme grammaire transversale) :** voir [[Wu Xing hors combat]].

**Questions ouvertes :** [[Ouvert — Répartitions Arcane Espace Corruption]], [[Ouvert — Compensation de l'arme mixte]].

> [!success] Codé depuis l'étape 0 — trace ajoutée le 2026-09-04
> `data/wuxing.json` porte les cinq éléments, `engendre` et `domine` ; l'élément d'une capacité est le **vecteur** de ses modules (`plan.elements`), l'arme mixte garde son vecteur complet, et la jauge de chaîne pose un segment par capacité qui touche (`Simulation._poser_segment`). Voir [[Jauge de chaîne Wu Xing]].

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Identité visuelle chinoise]]
- **Alimente** : [[Jauge de chaîne Wu Xing]], [[Domination et multiplicateurs]], [[Modificateurs d'affinité]], [[Armes fantomatiques]], [[Cinq accès au cycle]], [[Wu Xing hors combat]], [[XP de combat]]
- **Voir aussi** : [[Craft compositionnel]], [[Armure par zone et constructions]], [[Domaines de grimoires et manuels]], [[Palier industriel]], [[Ouvert — Répartitions Arcane Espace Corruption]], [[Ouvert — Compensation de l'arme mixte]]
