---
aliases: ["E.28", "Annexe E.28", "Météo", "Meteo"]
tags: [monde, simulation, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> `mod_altitude` recalibré par classe d'altitude de cellule et `mod_profondeur` → `mod_donjon` (valeurs décidées : [[Décision — Altitude sur 21 niveaux]]). Neige/gel exprimés en états de tuile.

La météo est une fonction pure du temps et du lieu, jamais une simulation — et elle porte de vraies mécaniques (température ressentie, foudre, gel, canicule).

```
GÉNÉRATION — la météo est une FONCTION PURE, jamais une simulation :
  meteo(cellule, temps) = f(bruit spatial lent + bruit temporel,
  filtrés par température/humidité locales (3.0))
  → un état parmi : clair, nuageux, brouillard, pluie, orage, neige,
  vent fort, + extrêmes rares : TEMPÊTE, BLIZZARD, CANICULE.
  Évaluée à la demande (zones chargées, carte du monde, E.6/E.18) —
  coût nul pour le reste du monde, déterministe et reproductible.
  Cohérence spatiale : le bruit spatial est lent → un front de pluie
  couvre plusieurs cellules et "se déplace" avec le temps.
  Les EXTRÊMES sont ANNONCÉS 1 jour in-game à l'avance : ciel visible
  + les PNJ en parlent (gabarits météo, E.23 — raccord existant).

TEMPÉRATURE RESSENTIE (joueur ET PNJ) :
  T = temp_biome (3.0) + mod_météo (neige -15, canicule +18...)
      + mod_nuit (-8, E.21) + mod_altitude (par classe d'altitude de
      la cellule — Proposition — Altitude sur 21 niveaux)
      + mod_donjon (+stable : les étages lissent vers une T moyenne)
  Zone de confort : [5, 30]. Hors zone : malus progressifs
  (vitesse, régén) puis dégâts froid/chaleur par palier — contrés par
  l'ISOLATION de l'équipement (A.4.5, formule déjà calibrée), les
  sources de chaleur locales (cheminée F.6 : déjà "annule le malus de
  froid dans la pièce" ; lave, torches à petit rayon), l'ombre et
  l'eau en canicule. Le biome extrême devient un vrai contenu :
  la toundra exige la fourrure, le désert tue à midi en canicule.

EFFETS PAR ÉTAT :
  Pluie    : cultures arrosées (+15 % vitesse de pousse, 7.4),
             feux éteints, +1 niveau d'eau dans cavités (E.22),
             visibilité -20 % (détection E.16)
  Orage    : pluie + FOUDRE RÉELLE : impacts aléatoires, ciblage
             pondéré par hauteur ET conductivité électrique de la tuile
             la plus haute (A.4.5) → un PARATONNERRE émergent : un mât de
             fer/cuivre au point haut capte la foudre et protège
             (aucun système dédié — les stats des matériaux suffisent).
             Impact : dégâts zone 3d8, ignition (flammabilite), les
             entités dans l'eau connexe prennent la propagation (E.22).
  Neige    : couche de NEIGE au sol (état de tuile auto-posé sur les
             surfaces exposées, paresseusement au chargement — comme
             la régénération 3.3), fond au redoux/sources de chaleur.
  GEL      : température < -5 prolongée → les tuiles d'eau
             calmes deviennent GLACE (tuile réelle, marchable, friction 5,
             cassable → re-eau) ; appliqué paresseusement au
             chargement de la zone selon la météo courante. Les lacs
             gelés ouvrent des raccourcis saisonniers ; la pêche/
             navigation s'arrêtent.
  Blizzard : neige + froid extrême (-25) + visibilité 3 tuiles +
             vent fort — voyager devient dangereux, s'abriter devient
             le gameplay.
  Canicule : +18, cultures flétrissent SANS arrosage manuel (7.4),
             l'eau peu profonde s'évapore (niveaux d'écoulement
             uniquement, jamais les sources, E.22), risque d'ignition
             spontanée des tuiles flammabilite >= 80 exposées.
  Tempête  : vent violent (véhicules à voiles ingouvernables, E.24),
             projectiles déviés, arrachage des tuiles très fragiles
             exposées (durete <= 3 ET non-abritées : paille, chaume —
             budget : quelques tuiles/cellule max, jamais destructeur
             de bases en dur).
  Vent     : direction/force par cellule — DÉJÀ consommé par les
             voiles (E.24) ; la tempête/le calme plat en sont les
             extrêmes.

MATÉRIAUX : Glace et Neige ajoutés au catalogue (F.1) — matériaux
  réels à part entière (constructibles : la glace est une vraie tuile,
  transparente, glissante ; fond près des sources de chaleur).
DONNÉES : data/weather_states.json (états, modificateurs, effets) —
  ajouter un état météo = une entrée, zéro code (section 10).
SAISONS : ACTIVÉES à l'étape 10, avec l'élevage et l'agriculture
  (Décision — Saisons activées à l'étape 10) : 1 an = 120 jours =
  4 saisons de 30 jours, courbe annuelle sur la température, champ
  `saison` exposé par l'horloge du monde. Aucun système nouveau.
```

*Saisons : voir [[Ouvert — Saisons]].*

> [!success] Codé le 2026-08-28 — étape 8.4, `data/weather_states/` (10 états), `Simulation.meteo()`
> **Fonction pure** : `meteo(cellule, temps) = f(bruit spatial lent + bruit temporel, filtrés par température et humidité locales)` (`planete.meteo`) — évaluée à la demande, déterministe, jamais simulée ; un front couvre plusieurs cellules et se déplace. Les 10 états en données : clair, nuageux, brouillard, pluie, orage, neige, vent fort, tempête, blizzard, canicule, chacun avec `temp_mod`, `visibility_mult`, `effects` (tags). **Température ressentie** : `T = temp_biome (couche température → −15…+40 °C) + mod_météo + mod_nuit (−8) + mod_altitude (colline −3, montagne −6, haute montagne −10)`, zone de confort [5, 30] ; hors zone, l'**isolation** de l'équipement compense (Σ isolation / 10 °C), puis **régénération d'endurance ÷ 2** et, au-delà de 10 °C hors zone, **1 PV par 300 ticks** (décision : la note dit « malus progressifs puis dégâts par palier » sans chiffres). La visibilité multiplie la portée de vue. Les changements d'état sont annoncés au journal ; l'annonce **1 jour à l'avance** des extrêmes est codée (la météo de demain se lit au même point). Pluie (+1 niveau d'eau), neige et gel comme états de tuile, foudre, évaporation et arrachage attendent l'automate d'eau.

> [!success] Codé le 2026-08-28 — neige et gel comme états de la grille
> Deux drapeaux sur la grille chargée, recalculés à chaque pas d'horloge au camp (`_maj_etats_meteo`) : **`neige`** (l'état météo porte l'effet `neige`) → **chaque pas coûte `deplacement.neige_surcout` (+1)** ; **`gel`** (température au centre de la cellule, saison, météo et nuit comprises, **< 0 °C**) → **l'eau devient glace** : plus de nage, plus de souffle, coût de pas normal — la mer gelée se traverse à pied. Décision : les états sont **globaux à la cellule chargée** (la météo est déjà par cellule), pas par tuile ; la pluie (+1 niveau d'eau), la foudre, l'évaporation et l'arrachage attendent toujours l'automate d'eau. Le client teinte la neige (sol blanchi) et la glace (eau pâle). `meteo_force` (chaîne vide par défaut) impose un état aux tests et aux arènes.

> [!success] Codé le 2026-08-28 — la foudre de l'orage
> À chaque **heure d'orage** au camp (`_tiquer_differes`, même cadence que la pluie — l'orage arrose aussi les creux), **un impact** (`Simulation._foudre`) : `eau.foudre_candidats` (40) tuiles tirées dans un rayon `eau.foudre_portee_joueur` (24) autour du joueur, **pondérées par la hauteur** (× 10) **et par la conductivité électrique** du matériau de la tuile si c'est un relief/mur (`materials.*.conductivite_electrique`) — un mur de fer ou de cuivre au point haut capte la foudre : **paratonnerre émergent**, aucun système dédié. Impact (`_frapper_foudre`) : **3d8** (`eau.foudre_des`) à toute entité sur la tuile et ses 8 voisines, puis **propagation dans l'eau connexe** (voir *Eau et liquides*). Décisions : un seul impact par heure (la note dit « impacts aléatoires » sans nombre — un par heure se lit, dix se subissent) ; l'**ignition attend** (pas encore de feu de tuile) ; la glace ne conduit pas ; en donjon, pas de foudre.

> [!success] Codé le 2026-08-28 — le feu de tuile : ignition, propagation, extinction
> **`Simulation.feux`** (idx → `{reste}`), joué toutes les `feu.periode_ticks` (10) sur l'horloge du monde, au camp comme en donjon. **S'enflamme** (`_enflammer`) une tuile dont le matériau brûle : arbre, plante, plante sauvage, culture, mur ou porte construits (`materials.*.flammabilite` du matériau de la tuile ; une culture vaut 60, une plante sauvage 50), ou un sol nu dont le matériau de sol brûle (paille) — jamais un liquide, ni sous le gel. **Causes** : la **foudre** (tuile d'impact), la **canicule** (effet météo `ignition` : chaque heure, `feu.canicule_chance` = 15 % qu'une tuile inflammable au hasard autour du joueur prenne), une **explosion** (les tuiles du rayon, chance = flammabilité). **Propagation** : à chaque pas, chaque feu tente ses 4 voisines, chance `flammabilité / 100 × feu.propagation` (0,35), **× `feu.vent_mult`** (2) sous un état météo à effet `vent` ou `tempete`. **Brûler** : un être sur une tuile en feu prend `feu.degats` (1d6, élément feu) par pas et le statut **Brûlure** ; l'IA **contourne** les tuiles en feu (`Grille.dangers`, ignoré par `chemin` et le pas glouton) et **en sort** d'un pas si elle s'y trouve ; le chemin automatique du joueur les contourne aussi. **Fin** : après `feu.duree_ticks` (80) la tuile est consumée — contenu retiré, terrain mémorisé (repousse hors claim), journal. **Extinction** : un état météo à effet `eteint_feux` (pluie, orage) éteint tout à la première passe ; la neige aussi. Le client dessine les flammes (couche additive) et un halo la nuit. Décisions : durée fixe plutôt que « jusqu'à épuisement du combustible » ; pas de fumée ; la lave attend toujours.

> [!success] Codé le 2026-08-29 — l'arrachage de la tempête
> Le dernier effet météo qui attendait. À chaque **heure de tempête** (état à effet `arrache_fragiles`), `Simulation._arrachage` tire `feu.arrachage_tuiles` (3) tuiles au hasard autour du joueur (`portee` 20) : une tuile est arrachée si son matériau a une **dureté ≤ `arrachage_durete`** (3 — paille, chaume, tissu, papier) **et** qu'elle est **exposée**, c'est-à-dire qu'aucune de ses quatre voisines plus haute qu'elle ne la protège. Le contenu part (terrain mémorisé, donc il repousse hors claim), le journal le dit. Décisions, prises pour tenir la promesse de la note (« jamais destructeur de bases en dur ») : **budget de trois tuiles par heure** au plus ; **rien de ce qui a une dureté supérieure à 3** — un mur de pierre, de brique ou de bois ne bouge pas ; et une tuile **abritée par un voisin plus haut** est épargnée, ce qui récompense de construire adossé. Un toit n'existe pas encore dans le modèle : l'abri se lit horizontalement.

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Application des stats de matériau]], [[Simulation à ticks]]
- **Alimente** : [[Eau et liquides]], [[Agriculture et élevage]], [[Véhicules]], [[Catalogue matériaux — Météorologiques]], [[Dialogue PNJ]]
- **Voir aussi** : [[Cycle jour-nuit et sommeil]], [[Équipement — 14 slots]], [[Meubles]], [[Ouvert — Saisons]], [[Data-driven design]]
