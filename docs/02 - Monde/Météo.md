---
aliases: ["E.28", "Annexe E.28", "Météo", "Meteo"]
tags: [monde, simulation, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 8
---

> [!warning] Héritage voxel
> Trois détails héritage : `mod_altitude (-1/20 blocs)` et `mod_profondeur` (cavernes) à recalibrer sur les 21 niveaux et les étages de donjon ; la neige « bloc fin 4px » suppose la subdivision — en grille, un état de tuile suffit. Tout le reste (fonction pure, états, température, effets) tient.
> — Classement complet : [[Héritage voxel — audit]].

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
      + mod_nuit (-8, E.21) + mod_altitude (-1/20 blocs au-dessus
      de la surface de référence) + mod_profondeur (+stable sous
      terre : les cavernes lissent vers une T moyenne)
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
             pondéré par hauteur ET conductivité électrique du bloc
             sommital (A.4.5) → un PARATONNERRE émergent : un mât de
             fer/cuivre au point haut capte la foudre et protège
             (aucun système dédié — les stats des matériaux suffisent).
             Impact : dégâts zone 3d8, ignition (flammabilite), les
             entités dans l'eau connexe prennent la propagation (E.22).
  Neige    : couche de NEIGE au sol (bloc fin 4px auto-posé sur les
             surfaces exposées, paresseusement au chargement — comme
             la régénération 3.3), fond au redoux/sources de chaleur.
  GEL      : température < -5 prolongée → la SURFACE des blocs d'eau
             calmes devient GLACE (bloc réel, marchable, friction 5,
             cassable → re-eau) ; appliqué paresseusement au
             chargement de la zone selon la météo courante. Les lacs
             gelés ouvrent des raccourcis saisonniers ; la pêche/
             navigation s'arrêtent.
  Blizzard : neige + froid extrême (-25) + visibilité 3 blocs +
             vent fort — voyager devient dangereux, s'abriter devient
             le gameplay.
  Canicule : +18, cultures flétrissent SANS arrosage manuel (7.4),
             l'eau peu profonde s'évapore (niveaux d'écoulement
             uniquement, jamais les sources, E.22), risque d'ignition
             spontanée des blocs flammabilite >= 80 exposés.
  Tempête  : vent violent (véhicules à voiles ingouvernables, E.24),
             projectiles déviés, arrachage des blocs très fragiles
             exposés (durete <= 3 ET non-abrités : paille, chaume —
             budget : quelques blocs/cellule max, jamais destructeur
             de bases en dur).
  Vent     : direction/force par cellule — DÉJÀ consommé par les
             voiles (E.24) ; la tempête/le calme plat en sont les
             extrêmes.

MATÉRIAUX : Glace et Neige ajoutés au catalogue (F.1) — matériaux
  réels à part entière (constructibles : la glace est un vrai bloc,
  transparent, glissant ; fond près des sources de chaleur).
DONNÉES : data/weather_states.json (états, modificateurs, effets) —
  ajouter un état météo = une entrée, zéro code (section 10).
SAISONS : non incluses pour l'instant ; la génération temporelle est
  conçue pour accueillir une modulation saisonnière plus tard
  (multiplier le bruit temporel par une courbe annuelle) — question
  ouverte, gros impact agriculture si activé.
```

*Saisons : voir [[Ouvert — Saisons]].*

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Application des stats de matériau]], [[Simulation à ticks]]
- **Alimente** : [[Eau et liquides]], [[Agriculture et élevage]], [[Véhicules]], [[Catalogue matériaux — Météorologiques]], [[Dialogue PNJ]]
- **Voir aussi** : [[Cycle jour-nuit et sommeil]], [[Équipement — 14 slots]], [[Meubles]], [[Ouvert — Saisons]], [[Data-driven design]]
