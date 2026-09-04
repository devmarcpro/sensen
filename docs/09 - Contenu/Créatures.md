---
aliases: ["F.3", "Annexe F.3", "Créatures", "Bestiaire", "Races animales", "Catalogue des créatures"]
tags: [contenu, êtres, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 9
---

> [!warning] Restructuré le 2026-08-26
> L'ancien F.3 mélangeait **des espèces** (loup, ours) et **des humains à métier** (forgeron, bandit, roi) dans une même liste. Depuis [[Les trois axes — race, classe, fonction]], ce n'est plus tenable : un forgeron n'est pas une créature, c'est `humain · La Braise · artisan · résident`.
> **Cette note ne contient plus que des races animales.** Les humains sont désormais des **combinaisons** — voir [[Profils de PNJ]].

Le bestiaire : **19 races animales**, réelles. La menace vient des bêtes, des humains hostiles et de l'environnement.

*Format : nom — squelette — niv. combat approx — profil IA — recrutable — notes. Toutes suivent le schéma [[Schéma créature]], avec `race` = l'espèce. **Aucune créature fantastique — décision ferme** ([[Ouvert — Créatures fantastiques]]).*

## Plaines et forêts tempérées

Loup (quadrupède, nv 6, bete_sauvage, meutes 1d4+1, dressage) · Sanglier (quadrupède, nv 8, bete_sauvage acculée, dressage) · Cerf (quadrupède, nv 3, fuit, dressage) · Renard (quadrupède, nv 3, fuit, dressage) · Essaim d'abeilles (amorphe, nv 4, hostile près de la ruche, jamais — miel récoltable)

## Désert

Scorpion (quadrupède bas, nv 7, hostile, dressage, statut poison) · Vautour (volant, nv 5, hostile si blessé détecté, dressage) · Chameau sauvage (quadrupède, nv 6, fuit, dressage — monture endurante)

## Toundra et taïga

Ours polaire (quadrupède, nv 18, bete_sauvage, dressage, fourrure isolante) · Loup blanc (quadrupède, nv 8, meutes, dressage) · Renne (quadrupède, nv 4, fuit, dressage/élevage) · Morse (quadrupède, nv 12, bete_sauvage sur la côte, dressage)

## Marécage

Crocodile (quadrupède bas, nv 14, embuscade aquatique, dressage) · Nuée de moustiques (amorphe, nv 4, hostile, jamais, dégâts continus faibles + risque infection) · Serpent venimeux (amorphe, nv 8, hostile si approché, dressage, poison)

## Montagne

Aigle (volant, nv 7, bete_sauvage, dressage) · Ours brun (quadrupède, nv 16, bete_sauvage, dressage) · Bouquetin (quadrupède, nv 4, fuit, dressage/élevage) · Lynx (quadrupède, nv 9, embuscade, dressage)

## Ce qui étend le bestiaire

**Les espèces d'élevage** ([[Catalogue des groupes d'élevage]], Annexe H) — 35 groupes, chacun une fiche de données : insectes, poissons, serpents, vers à soie, ruches, tortues, phalènes… Ce sont des races au même titre, avec un bloc `génome` en plus.

**Les créatures de donjon** ([[Génération de donjon]]) : les niches sont occupées par les **humains hostiles** ([[Profils de PNJ]]) et les **bêtes tanières** (ours, loups) — un donjon est une ruine investie, pas une crypte magique. La haute corruption produit des bêtes réelles de plus haut niveau et des **variantes rares** ([[Monstres rares]]), pas d'autres espèces.

## Drop rare universel — la statue 1:1

Toute créature a une faible chance (défaut **0.5 %**, pondérable par race) de dropper une **statue d'elle-même à l'échelle 1:1** — un meuble décoratif ([[Meubles]]) généré automatiquement : le modèle assemblé exact de la créature (ses parties tirées, [[Squelette modulaire et points d'attache]]), **recolorisé en pierre** via le remapping de palette existant ([[Entités et pathfinding — performance]] — zéro asset à produire). Trophée de chasse ultime, objet de collection et de prestige (humeur/déco), valeur de vente ∝ niveau de la créature.

## Rappels de systèmes

**Profils d'IA ([[IA des créatures]]) :** `hostile`, `bete_sauvage`, `civil`, `garde`, `assaillant`, `compagnon`.

**Actions ([[Actions des créatures]]) :** 24 actions partagées par famille — morsures, charges télégraphiées, meute, embuscade, volants.

**Spawns nocturnes ([[Cycle jour-nuit et sommeil]]) :** les tables de spawn par biome ont un volet « nuit » — loups en chasse, prédateurs embusqués, humains hostiles en maraude.

**Viandes et parties dérivées :** [[Catalogue matériaux — Paramétriques]].

> [!success] Décidé le 2026-08-26 — les six adversaires du prototype, chiffrés
> Aucune fiche ne donnait de stats : voici celles de `data/creatures/` (six stats, PV = 20 + End × 4 — [[Stats de personnage]]), valeurs de premier équilibrage à ajuster au playtest :
>
> | Fiche | For | Dex | End | Vol | Per | Cha | PV | Actions / arme | IA |
> |---|---|---|---|---|---|---|---|---|---|
> | Loup | 7 | 12 | 5 | 3 | 12 | 2 | 40 | morsure, harcelement_meute, hurlement | hostile |
> | Sanglier | 12 | 6 | 10 | 4 | 8 | 2 | 60 | coup_de_defenses, charge | hostile |
> | Bandit | 11 | 10 | 9 | 7 | 9 | 8 | 56 | épée + cuirasse de cuir | hostile |
> | Chef de bande | 13 | 12 | 12 | 9 | 10 | 12 | 68 | épée, bouclier, casque de fer, mailles + cri_de_ralliement, enchainement (`chain_gauge`) | hostile |
> | Aigle | 5 | 15 | 4 | 3 | 16 | 2 | 36 | serres, pique_plongeant (volant) | hostile |
> | Scorpion | 6 | 9 | 6 | 2 | 8 | 1 | 44 | pique_venimeuse, pinces | hostile |
> | *Aventurier (joueur)* | 12 | 10 | 12 | 8 | 10 | 8 | 68 | épée, casque et cuirasse de cuir ; râtelier des 6 armes + bouclier | — |
>
> **Profil IA des bêtes dans les arènes :** le catalogue donne `bete_sauvage` au loup et au sanglier ; le prototype les met en **`hostile`** — ce sont des loups **en chasse** ([[Cycle jour-nuit et sommeil]] : « loups en chasse » la nuit) et un sanglier **acculé** dans sa gorge, ce que la spec exige pour tester l'encerclement et la charge. Le profil est un champ de la fiche, changer d'avis = éditer un JSON. La **détection** est `Perception` tuiles avec ligne de vue ([[IA des créatures]]).

> [!success] Codé le 2026-08-28 — étape 9.B : la faune de surface (`planete.faune`, biomes `faune` / `faune_nuit`)
> Champ `faune` (`[{id, density}]`) et `faune_nuit` par biome, sur le modèle de `vegetation` ; nouveaux : cerf et renard (profil `proie` : fuient, errent), le loup et le sanglier reprennent `bete_sauvage` de jour et le loup redevient `hostile` en **meute (1d4+1)** la nuit. Spawn (décision, la note ne chiffrait rien) : toutes les 200 ticks, si moins de **12 bêtes** dans la fenêtre, une bête (ou une meute) apparaît dans l'anneau **12-40 tuiles** hors ligne de vue, tirée dans la faune du biome de la tuile — **densité ×2 la nuit** avec le volet nuit ; **despawn** au-delà de 60 tuiles hors combat (jamais de suppression brutale sous les yeux). La Discrétion +4 est codée (2026-08-29 : elle réduit la portée de détection). Les 15 autres races du bestiaire s'ajoutent en données.

> [!success] Hypothèses posées et codées le 2026-09-04 — **massacrer la faune vide la forêt, et elle revient**
> Le point 76 laissait deux questions « à trancher avant de coder » ; le designer a demandé de finaliser les systèmes, et la file promettait des hypothèses écrites plutôt que d'attendre. Les voici, chacune une ligne :
> - **Tuer une bête paisible a un prix, et c'est la raréfaction — pas la réputation.** Personne ne regarde les bois : une réputation qui baisserait au fond d'une forêt serait une cause sans effet visible. À la place, chaque proie, fuyarde ou bête sauvage de la faune de surface tuée par le joueur baisse la **densité de faune de sa cellule** de `planete.faune.rarefaction.par_mort` (0,15), jusqu'au plancher (0,25) ; le tirage de faune de la cellule où l'on se trouve est multiplié par cette densité. On peut vider une clairière ; on la voit se vider.
> - **La faune revient par génération, pas par reproduction.** Comme les villages : la densité remonte de `retour_hebdo` (0,05) à chaque passage de semaine, jusqu'à 1. Aucune bête ne se reproduit dans le monde — c'est le vivarium qui reproduit, avec ses loci — et une bête hostile tuée (le loup de nuit) ne raréfie rien : on ne massacre pas ce qui chasse.
> - **La faim des prédateurs n'existe pas** : aucun système ne la porte, et la note n'en veut pas avant l'élevage.
> Codé sous `Monde.faune_densite` (sauvegardé), `Simulation._rarefier_faune`, `densite_faune`, `_regenerer_faune_hebdo` ; le tirage (`_tiquer_faune`) lit la densité de la cellule du joueur. Les chiffres sont des points de départ.

> [!success] Codé le 2026-08-28 — les 19 races animales
> Douze fiches de plus dans `data/creatures/` (le bestiaire en comptait sept) : essaim d'abeilles, vautour, chameau sauvage, ours polaire, loup blanc, renne, morse, crocodile, nuée de moustiques, serpent venimeux, ours brun, bouquetin, lynx — stats calées sur le niveau approximatif de la note (Force ≈ nv + 2 pour les grands prédateurs, Dextérité pour les embusqués), actions de créature du catalogue (dard d'essaim, becquetage/serres, ruade, coup de patte / masse écrasante / morsure puissante, mâchoire verrouillée / embuscade, nuée, morsure venimeuse, coup de tête / bond, griffure / bond), `depouille` en parties de créatures ; `rare_chance` par défaut pour les prédateurs, 0 pour les nuées (jamais recrutables, tag `nuee`). **Les biomes les reçoivent** : désert (vautour, chameau), toundra (ours polaire, loup blanc, renne, morse), taïga (loup blanc, renne), marécage (crocodile, moustiques, serpent), montagne (ours brun, bouquetin, lynx), plaine/forêt (essaim). Le dressage suit les tags existants (`bete`, `proie`) ; les montures (chameau) attendent les véhicules.

> [!success] Codé le 2026-08-29 — la statue 1:1, décidée depuis longtemps et jamais droppée
> Trouvé par un contrôle neuf : chercher les objets du catalogue qu'**aucune source ne donne** (ni recette, ni loot, ni boutique, ni dépouille, ni coffre de départ). Un seul survivait — `meuble_statue`, le « drop rare universel » de cette note, qui existait comme meuble et comme objet mais que rien au monde ne faisait tomber. Toute créature d'IA abattue a désormais **0,5 %** (`loot_rules.drops.statue.chance`, pondérable par fiche via `statue_mult`) de laisser sa **statue**, meuble décoratif (+3 d'humeur) nommé d'après elle (« Statue de loup »). **Décisions** : la valeur de vente « ∝ niveau de la créature » se lit sur la **moyenne de ses six stats × 12** (`valeur_par_stat`), le jeu n'ayant pas de niveau de créature explicite ; le modèle recolorisé en pierre attend les sprites (décision du designer : l'apparence plus tard) — la statue est pour l'instant le meuble générique, avec son nom et sa valeur propres.

> [!success] Décidé et codé le 2026-08-30 — sept types d'ennemis, vraiment différents
> **Instruction du designer** : « rajouter des types d'ennemis (tireurs, invocateurs, soigneurs, fuyards, tanks, essaims, embusqueurs), en données, intégrés aux thèmes de donjon et aux faunes ». Sept fiches (`data/creatures/`), six actions (`data/creature_actions/`) et six profils d'IA (`data/ai_profiles/`) :
>
> | Fiche | Rôle | Action / arme | IA | Où |
> |---|---|---|---|---|
> | Bandit archer | tireur | Tir à l'arc 1d6 perforant, portée 2-6 ; dague au contact | `tireur` : **recule** au contact | ruine |
> | Chaman bandit | invocateur | Appel des follets (1 feu follet, **2 au plus**, 120 ticks, télégraphié) + Flammèche | `invocateur` : soutient, recule | ruine |
> | Guérisseur bandit | soigneur | Onguent 2d4 sur l'allié le plus blessé (< 70 %, portée 3) | `soigneur` : soutient d'abord | ruine |
> | Brute | tank | Coup de masse 2d6 contondant, 30 % Au sol, télégraphié ; mailles, casque, bouclier, jauge de chaîne | `tank` : **ne fuit jamais** | ruine |
> | Rôdeur | embusqueur | Embuscade (+2 dés sur la première frappe), Discrétion 30 | `embusqueur` : **guette** tant que la cible est à plus de 3 tuiles | ruine, repaire |
> | Rat géant | fuyard | Morsure 1d4, 15 % Infection ; meute 1d3 | `fuyard` : fuit sous 50 % | ruine, repaire, plaines la nuit |
> | Chauve-souris | essaim | Morsure 1d3, 5 ticks ; meute 1d4+2, volante, 3 PV de fond | `hostile` | repaire, forêts la nuit |
>
> Deux effets d'action nouveaux dans le moteur : `soin` (dés) et `invoquer` (créature, n, max, durée) ; les stats suivent le barème de la table du 26 (PV = 20 + End × 4). Les tirages des salles piochent dans la liste du thème à parts égales : la ruine a désormais dix entrées, dont trois bandits sur dix.

> [!success] Décidé et codé le 2026-08-31 — cinq bêtes et deux rigs de plus (designer, point 37)
> Le Paperdoll ne branche jamais par type d'être : deux **rigs inédits en données pures** rejoignent `data/rigs/` — **serpentin** (tête + trois anneaux chaînés qui ondulent) et **arachnide** (huit pattes étagées autour d'un abdomen) — et cinq bêtes peuplent les silhouettes sous-employées : **serpent géant** (serpentin, ruine), **araignée géante** (arachnide, repaire), **sangsue géante** (amorphe, repaire), **aigle royal** (volant, ruine, par deux ou trois), **scarabée cuirassé** (quadrupède blindé, repaire). Toutes réutilisent les actions du catalogue (morsure venimeuse, mâchoire verrouillée, bond, serres, piqué plongeant, charge, pinces) et entrent dans les pools des deux thèmes de donjon. Le bestiaire reste **exclusivement réel** ([[Ouvert — Créatures fantastiques]], abandon du 26) : les deux premières esquisses — un limon et une harpie — ont été remplacées par une sangsue géante et un aigle royal avant le commit ; les nouveaux rigs servent des animaux, pas des monstres.

> [!success] Décidé et codé le 2026-08-31 — six créatures de folklore (designer, point 40)
> La règle « bestiaire exclusivement réel » est levée au profit d'une règle plus étroite : **folklore attesté uniquement, rien d'inventé** ([[Ouvert — Créatures fantastiques]]). Six entrées, une par silhouette déjà gréée, aucun rig nouveau : **kappa** (humanoïde, Japon, eau — repaire), **kitsune** (quadrupède, Japon, feu — repaire), **tsuchigumo** (arachnide, Japon, embuscade — repaire), **basilic** (serpentin, Europe, venin — ruine), **griffon** (volant, Antiquité, serres — ruine), **golem d'argile** (humanoïde, folklore juif, terre, sans dépouille — ruine). Toutes réutilisent les actions du catalogue et les pools des deux thèmes ; elles sont plus rares et plus dures que les bêtes du même étage (`rare_chance` doublée).

## Liens
- **Dépend de** : [[Schéma créature]], [[Les trois axes — race, classe, fonction]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[Profils de PNJ]], [[Catalogue matériaux — Paramétriques]], [[Monstres rares]], [[Actions des créatures]], [[Génération de donjon]]
- **Voir aussi** : [[Apprivoisement et recrutement]], [[Catalogue des groupes d'élevage]], [[Cycle jour-nuit et sommeil]], [[Ouvert — Créatures fantastiques]]
