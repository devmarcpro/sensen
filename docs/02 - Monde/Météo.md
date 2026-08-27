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

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Application des stats de matériau]], [[Simulation à ticks]]
- **Alimente** : [[Eau et liquides]], [[Agriculture et élevage]], [[Véhicules]], [[Catalogue matériaux — Météorologiques]], [[Dialogue PNJ]]
- **Voir aussi** : [[Cycle jour-nuit et sommeil]], [[Équipement — 14 slots]], [[Meubles]], [[Ouvert — Saisons]], [[Data-driven design]]
