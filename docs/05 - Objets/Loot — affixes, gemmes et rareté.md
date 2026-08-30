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

> [!success] Codé le 2026-08-28 — quatre inertes réveillés
> Leurs systèmes existent désormais, ils sortent de l'inertie : **nocturne** (`cond_nuit_vitesse`, pièces d'armure et arme) — la nuit (`est_nuit`), chaque pas coûte `pct` % de ticks en moins (jamais sous 1), pièces cumulées ; **du danger** (`cond_corruption`, arme) — si la corruption effective de la cellule (`Monde.corruption_de`, dérive comprise) ou celle du donjon atteint `seuil`, dégâts × (1 + pct %) ; **des sources** (`cond_densite_mana_cout`, arme et bijoux) — quand la couche `mana` de la surface au point du lanceur dépasse `effets_equipement.densite_mana_seuil` (0,6), le coût en mana baisse de `pct` % (rien en donjon : pas de couche) ; **du porteur** (`meca_capacite`) — `+kg` de capacité de poids, cumulé sur les pièces (`e.mecaniques.capacite_poids.n`, déjà lu par `poids_de`). Restent inertes : régénération, riposte à cadence, combos +2 dés.

> [!success] Codé le 2026-08-31 — les trois derniers inertes agissent, plus aucun affixe ne ment
> La **régénération** (`passif_regen` → mécanique `regen_sante`) était en fait déjà codée (1 PV toutes les `200 × 100 / pct` ticks hors combat, coupée sous le seuil de faim) — le « restent inertes » ci-dessus était en retard d'un correctif. Codés ce jour : la **riposte à cadence** (`cadence_riposte_des`, armure) — tous les `n` coups reçus, la **prochaine attaque** du porteur gagne `+des` dés ; le **combo Wu Xing** (`wuxing_combo_des`, arme, très rare) — quand le coup pose un segment en **engendrement** (le « combo » du cycle), l'attaque suivante gagne +2 dés (`parametres.des`, en données). Les bonus armés se lisent dans la prévisualisation et sont dépensés par le coup suivant, raté compris. Régression dans le test des affixes.

> [!success] Codé le 2026-08-29 — 43 gabarits : amplification et transmutation
> Deux gabarits de plus dans la famille Wu Xing, sur les **anneaux et amulettes** : `wuxing_amplification` (*part de X × N*) et `wuxing_transmutation` (*remplace X par Y*, deux éléments distincts garantis au tirage). Ils complètent les quatre opérations de [[Modificateurs d'affinité]] et ouvrent les *anneaux de transmutation* des [[Cinq accès au cycle]]. Le compte passe de 41 à **43**.

> [!success] Corrigé le 2026-08-29 — le loot tirait dans huit listes d'ids
> Même défaut que les boutiques : `loot_rules.contenants` portait `bases_armes`, `bases_armures`, `bases_gemmes`… — huit listes à tenir à la main, et deux implémentations copiées (`Loot._base_pour`, `Donjon._base_aleatoire`). Devenu `categories: {armes: {poids, filtre}, …}` : le poids de la catégorie et le **filtre** qui la définit. Toute arme de prototype ajoutée au jeu entre dans les coffres **le jour où elle existe**. **Décisions** : les doublons de pondération des anciennes listes (grimoire deux fois, fiole de soin deux fois) disparaissent — un filtre est un ensemble, la pondération se fait au niveau de la catégorie ; les boucliers rejoignent les armures ; la torche rejoint les outils (`tags_any: [prototype, lumiere]`) ; parties de bête, âmes et spécimens sont exclus des consommables lootables (`tags_none`).

> [!success] Décidé et codé le 2026-08-30 — le loot assemblé : jamais « une simple épée »
> **Instruction du designer** : « vérifier que le loot soit vraiment aléatoire — on ne loot pas une simple épée, on peut looter une épée avec un manche en chêne et une tête en cuivre de qualité 1,4 ». Vérifié : c'était faux — les coffres et les drops tiraient les **prototypes** (`proto_epee`, fer, sans composants ni qualité). Désormais `loot_rules.contenants.categories` : armes, armures et outils tirent les objets **assemblés** (`tags assemble` : `craft_*`), les boucliers (sans version assemblée) gardent leur prototype ; la torche reste dans les outils. À la génération (`Simulation._composer_loot`), chaque **slot** de l'objet (tête, manche, fixations ; plaque, sangles, fixations) reçoit une **recette de composant** tirée (donc une famille de matériau), un **matériau** de la famille — les minerais des étages ≤ profondeur pèsent `assemblage.poids_etage` (3) fois plus : du cuivre à l'étage 1, du fer à 2, de l'or à 3… — et une **qualité** tirée comme un artisan de niveau `niveau_base + niveau_par_profondeur × profondeur` (8 + 6/étage) ; le jet d'assemblage est borné comme à l'atelier. Le calcul des stats est **partagé** avec `_assembler` (`_appliquer_composition`) : Σ stat × poids, dureté avant qualité, Wu Xing composite, matériau de la tête, vitesse du manche. Le nom suit : « Épée en cuivre (correct 1,12) », l'infobulle liste les composants. Test : `test_loot_assemble`. **Réglage (23 h, après un parcours robot)** : des « Jambières de plaque en titane (pauvre 0,57) » à l'étage 2 — niveau d'artisan porté à 15 + 10/étage (qualités ≈ 0,7-1,7 à l'étage 2, le « 1,4 » du designer est courant), `poids_etage` 6, et `tiers_au_dela` (1) : un minerai d'un tier plus profond que l'étage + 1 n'apparaît pas. **Les boutiques suivent** (23 h 10) : le forgeron (PNJ et boutique), l'armurier et l'étal d'outils du marchand tirent des objets assemblés — composés à la génération comme le loot ; le tailleur garde ses prototypes de cuir et de tissu (pas encore de construction assemblée pour eux), les boucliers restent des prototypes. Un bloc de stock peut demander une **catégorie de matériau** (`materiaux: ["metal"]`) : la pièce maîtresse (tête, plaque) est alors tirée dans cette catégorie — le forgeron vend une masse en acier trempé au manche de bambou, pas une masse de basalte.

## Liens
- **Dépend de** : [[Effets d'équipement passifs]], [[Qualité d'artisanat]], [[Génération de donjon]], [[Modificateurs d'affinité]]
- **Alimente** : [[Trésors et artefacts]], [[Monstres rares]], [[Équipement — 14 slots]], [[Jauge de chaîne Wu Xing]], [[Cinq accès au cycle]]
- **Voir aussi** : [[Catalogue matériaux — Gemmes]], [[Effets d'équipement types]], [[Craft compositionnel]], [[Dérive de la corruption]], [[Localisation]], [[Ouvert — Fourchettes des gemmes]]
