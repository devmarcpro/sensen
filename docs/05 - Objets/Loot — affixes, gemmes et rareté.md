---
aliases: ["A.12", "Annexe A.12", "Loot", "Affixes", "Gemmes", "Rareté", "Sertissures"]
tags: [objets, loot, décidé]
domaine: objets
statut: décidé
etape: 3
---

La règle d'or du loot — « l'atelier améliore, le donjon transforme » — et tout ce qui en découle : affixes générateurs, gemmes comme nombres plats, grille de rareté.

```
RÈGLE D'OR : « L'ATELIER AMÉLIORE, LE DONJON TRANSFORME. »
  Les effets fabricables sont petits, chiffrés, génériques.
  Les effets qui changent la FAÇON DE JOUER sont LOOT-ONLY :
  jamais craftables, jamais reproductibles, jamais transférables.
  Rien ne doit concurrencer le dungeon crawling.

AFFIXES = GÉNÉRATEURS PARAMÉTRÉS, jamais des effets fixes.
  Chaque entrée du pool est un gabarit à fourchettes tirées à la
  génération : « une attaque sur [2-4] porte [élément] » = 15
  variantes d'une seule ligne de données. Le BUDGET DE RARETÉ
  module les fourchettes (un tirage exceptionnel pioche dans le
  meilleur tiers) : les joueurs comparent deux drops du MÊME affixe.
  Six familles :
    RYTHMIQUES  « une attaque sur [2-4] porte [élément] » ·
                « une sur [3-5] gagne +[1-3] dés » ·
                « tous les [4-7] coups : ignore [50-100] % d'armure »
    CONDITIONNELS (lus sur les COUCHES DE BRUIT continues, jamais
                sur l'étiquette de biome — seuils physiques valables
                partout, y compris en donjon) :
                « [nuit/jour] : +[10-20] % vitesse » ·
                « sous [30-60] % PV : +[1-3] dés » ·
                « contre les cibles [élément] : +[15-35] % » ·
                « corruption ≥ [40-70] : +[15-30] % » (l'arme qui
                aime le danger) · « profondeur ≥ N : +[1-2] dés » ·
                « densité de mana ≥ seuil : −[15-30] % coût »
    WU XING     « les coups touchés avancent l'élément dans le
                cycle » · « +[20-40] % [élément] au vecteur » ·
                « +1 segment de chaîne » (rare) · « les combos
                donnent +2 dés au lieu de +1 » (très rare)
    DÉCLENCHEURS « au coup en [zone] : [étourdit/saigne] » ·
                « à la parade : rend [3-8] endurance » ·
                « à la mise à mort : +[8-15] % vitesse [3-6] s »
                (inversés en armure : « quand le porteur est touché »)
    MÉCANIQUES  vol de vie [3-8] % · +[1-2] allonge · garde −[20-40] %
                d'endurance · +[10-30] capacité
  Les affixes d'armure utilisent LES MÊMES six familles avec des
  gabarits dédiés par slot (champ slots_valides) — aucun pool séparé.
  Implémentation : StatModifiers (source affixe:<uid>) + compteurs
  par objet + abonnements EventBus. Trois mécanismes existants.

GEMMES = TOUS LES BONUS PLATS (jamais une règle)
  Tailler une gemme CHOISIT sa spécialisation, et la QUALITÉ DE
  TAILLE (A.3) détermine la valeur dans la fourchette :
    Rubis→Feu · Saphir→Eau · Émeraude→Bois · Topaze→Terre ·
    Onyx→Métal : +[1-3] dégâts élémentaires OU +[4-10] domaine
    Diamant : +[0.03-0.08] qualité · Améthyste : mana ou Méditation
    Grenat : PV ou Force/Endurance · Opale : durée des statuts ou
    Volonté/Charisme · Ambre : endurance ou compétence physique
  TROISIÈME OPTION — TAILLE EN AFFINITÉ : aucun nombre, mais AJOUT
    au vecteur (A.4.6) selon la qualité : misérable +0.04 →
    mythique +0.28. Seule voie par laquelle l'atelier touche à
    l'identité élémentaire, et elle est EXCLUSIVE.
    → PURIFIER : sertir son élément déjà dominant concentre le
      vecteur (l'artisanat devient la voie de purification que les
      armes mixtes cherchaient).
    → BASCULER : sertir massivement un autre élément peut renverser
      la dominante d'une arme MIXTE. Sur une arme PURE, jamais :
      la pureté reste une propriété du craft, pas quelque chose
      qu'on achète.
  Plafond : +15 par compétence toutes gemmes confondues.

SERTISSURES ET INFUSION
  Nombre de slots (0-3) tiré au loot — une arme à 3 slots VIDES est
  un loot précieux en soi. Désertir DÉTRUIT la gemme.
  Infusion : 1 max par objet, pose un grant_tag utilitaire (vision
  nocturne, pas silencieux) — utile, jamais transformateur.

NOM ET PROVENANCE : tout loot rare+ reçoit un nom généré dont les
  gabarits consomment LES PARAMÈTRES TIRÉS (l'élément donne « de
  givre »/« de braise », un n bas « fervente », un gros pourcentage
  « du colosse ») + une métadonnée d'origine (donjon, date, monstre
  rare). Chaque objet raconte d'où il vient.

GRILLE DE RARETÉ (suit la profondeur d'étage / corruption) :
  commun 0 affixe 0 slot · inhabituel 1 / 0-1 · rare 1-2 / 1-2 +nom
  · exceptionnel 2-3 (budget renforcé) / 2-3 dont une occupée
  · artefact : effets uniques hors pools, NI sertissable NI
    infusable (fini par nature).

FLUX — pourquoi le crawling reste roi : le donjon est la SEULE
source des affixes, des artefacts, des parchemins de recettes
exotiques et de leurs doublons, des grimoires, des gemmes rares.
L'atelier consomme ce que le donjon fournit — jamais l'inverse.
```

**Questions ouvertes :** [[Ouvert — Fourchettes des gemmes]] (fourchettes, plafond +15 par compétence, taille des pools d'affixes).

> [!success] Codé le 2026-08-27 — affixes générateurs, rareté par profondeur, effets passifs
> `data/affixes/` : **36 gabarits** (`tools/gen_affixes.py`), six familles + une sixième « passif » qui porte les pools de [[Effets d'équipement types]] pour les bijoux (stat, compétence, mécanique, tag) — un seul mécanisme, pas de pool séparé. Chaque gabarit déclare ses `parametres` (fourchettes, tirage d'élément, listes), `effet.type`, `meilleur` (le sens du bon tirage : le **budget** de rareté pioche dans le meilleur tiers avec une probabilité 0.33 pour rare, 0.67 pour exceptionnel — `data/loot_rules.json`), `slots_valides`. `systems/loot/generateur.gd` produit une **instance** (uid, rareté, affixes tirés avec compteurs, sertissures vides, nom = gabarit + paramètres tirés, provenance) ; l'instance rejoint le catalogue fusionné de la simulation. **Grille de rareté** telle quelle, poids par étage dans `loot_rules.json`. Résolus dans le combat : cadence (élément, dés, perçant, saignée, parade), sous X % PV, contre élément, profondeur, cycle qui avance, ajout/purification du vecteur (normalisation de [[Modificateurs d'affinité]]), +1 segment, statut par zone, parade qui rend, hâte à la mise à mort, touché → statut, vol de vie, allonge, garde −%, endurance max, armure, matchups défensifs. **Inertes** (chargés, tirés, sans prédicat) : nuit, corruption, densité de mana, capacité de poids, régénération, riposte à cadence, combos +2 dés — chacun attend un système absent, signalé dans le nom même de l'objet. **Effets passifs** : les stats et compétences *effectives* (`stats_eff`, `competences_eff`) sont recalculées à chaque changement d'équipement (`(base + Σ add)`, clamp des maxima avec plancher 1 PV — [[Effets d'équipement passifs]]). Reste pour la suite de l'étape : coffres et drops dans le donjon, sac et ramassage, monstres rares, gemmes/sertissage, grimoires/lecture.

> [!success] Codé le 2026-08-27 (fin) — gemmes, sertissures, livres, coffres, monstres rares
> **Gemmes** : dix bases (`items/gemme_*.json`), chacune avec ses tailles possibles ; la taille est **choisie à la génération** (spécialisation) et la **qualité de taille** (`0.7 + 0.15 × étage + aléa`, bornée 0.5-2.0) place la valeur dans la fourchette — élémentaires : +[1-3] dégâts plats de l'élément, +[4-10] au domaine, ou **affinité** +[0.04-0.28] (AJOUT normalisé sur le vecteur de l'arme tenue) ; Diamant qualité, Améthyste mana/Méditation, Grenat PV/Force/Endurance, Opale durée/Volonté/Charisme, Ambre endurance/Athlétisme/Esquive. **Sertir** (`T`, 5 ticks) dans un emplacement libre d'un objet porté ; **plafond +15 par compétence** toutes gemmes confondues ; désertir (destruction de la gemme) attend une UI. Coffres, butin et monstres rares : voir [[Donjons — structure et intégration]] et [[Monstres rares]]. **Hors code** : les artefacts (donjons majeurs, étape 8 pour la surface), l'infusion, la provenance datée (pas de calendrier), le nom qui combine deux affixes (le premier nomme).

## Liens
- **Dépend de** : [[Effets d'équipement passifs]], [[Qualité d'artisanat]], [[Génération de donjon]], [[Modificateurs d'affinité]]
- **Alimente** : [[Trésors et artefacts]], [[Monstres rares]], [[Équipement — 14 slots]], [[Jauge de chaîne Wu Xing]], [[Cinq accès au cycle]]
- **Voir aussi** : [[Catalogue matériaux — Gemmes]], [[Effets d'équipement types]], [[Craft compositionnel]], [[Dérive de la corruption]], [[Localisation]], [[Ouvert — Fourchettes des gemmes]]
