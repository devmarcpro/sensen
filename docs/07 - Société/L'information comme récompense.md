---
aliases: ["L'information comme récompense", "Paliers d'information", "Information PNJ"]
tags: [société, décidé]
domaine: société
statut: décidé
etape: 9
---

L'information est la récompense principale de la relation, avant les prix. Deux axes se dévoilent par paliers.

**Ce qu'on sait du PNJ** — sa fiche s'ouvre progressivement :
- **< 0** : apparence seule
- **0-19** : nom, métier, royaume
- **20-49** : âge, signe, humeur, niveau approximatif
- **50-74** : liens familiaux, compétences chiffrées, équipement
- **75-89** : préférences de cadeau **explicites** (au lieu d'être devinées), spécialités, opinions sur les autres PNJ
- **90-100** : historique complet et relations exactes

Un PNJ hostile ne cache rien : il ne se confie simplement pas.

**Ce qu'il sait du monde** — filtré par **métier** autant que par palier (sinon tous les PNJ deviennent le même distributeur ; le filtrage par métier existe déjà en [[Dialogue PNJ]]) :
- **20-49** : informations locales actionnables (qui vend quoi, quel sol pour quelle culture, les lois du royaume et leurs sévérités)
- **50-74** : informations **à valeur marchande** — position d'un filon majeur, tanière d'une bête rare, **quelle ville possède quel hall de guilde ou boutique** (l'unicité par ville, [[Génération des royaumes PNJ]], rend cette information précieuse), position d'un donjon non découvert
- **75-89** : **savoirs transmissibles** — un artisan **enseigne une recette de composant exotique** (troisième source du craft compositionnel, avec le loot et l'achat — [[Craft compositionnel]]), un érudit indique un domaine, un alchimiste une potion
- **90-100** : **faveurs personnelles** — devient recrutable même si sa condition ne le prévoyait pas, offre un objet personnel, révèle un secret du royaume

Les informations débloquées sont **persistées** et **partageables en coop**.

**Révélation des couches de bruit ([[Génération par couches de bruit]]) :** les couches cachées (mana, ressources) se révèlent notamment par les **rumeurs de PNJ** — au même titre que les effets `detection_filons`/`detection_tresors` et les informations vendues par la guilde des Prospecteurs.

**Ciblage volontaire d'une recette ([[Craft compositionnel]]) :** l'enseignement par un artisan à haute relation est le moyen **volontaire** de cibler une recette précise (contre le hasard du loot).

> [!success] Codé le 2026-08-28 — étape 9.C
> La fiche d'un PNJ s'ouvre par paliers dans l'écran de dialogue : < 0 apparence seule ; 0-19 nom, métier, village ; 20-49 âge, signe, niveau approximatif ; 50-74 compétences chiffrées, équipement ; 75-89 préférences (tags aimés) ; 90-100 tout, et **recrutable hors condition** (drapeau posé, le recrutement lui-même attend 9.D). Ce qu'il sait du monde : à **≥ 50**, *Parler* peut livrer une **rumeur** (une fois par semaine et par PNJ) qui **révèle une cellule à POI** non explorée dans un rayon de 6 cellules (donjon ou filon majeur — filtré par métier : un garde parle de donjons, un forgeron de filons) ; l'enseignement de recettes exotiques par un artisan à ≥ 75 est branché sur `e.recettes_connues`.

## Liens
- **Dépend de** : [[Réputation et relations]], [[Dialogue PNJ]]
- **Alimente** : [[Craft compositionnel]], [[Apprivoisement et recrutement]], [[Génération par couches de bruit]]
- **Voir aussi** : [[Génération des royaumes PNJ]], [[Astrologie — cycle sexagésimal]], [[Âge des PNJ]], [[Habitat des PNJ]], [[Voie de rédemption]], [[Multijoueur]]
