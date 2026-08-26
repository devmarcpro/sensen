---
aliases: ["E.27", "Annexe E.27", "Génération des royaumes", "Royaumes PNJ", "Graines de capitale", "Unicité par ville"]
tags: [société, monde, technique, décidé]
domaine: société
statut: décidé
etape: 10
---

Des îlots de civilisation générés déterministiquement par secteur — un royaume est un événement, la majorité du monde est sauvage, et la géographie décide de ses frontières.

```
STRUCTURE DU MONDE — les royaumes sont des ÎLOTS DE CIVILISATION
séparés par de vastes terres sauvages sans lois (14.4 : hors royaume =
aucune loi, aucune douane — la "wilderness" est l'anarchie de fait).
La majorité du monde est sauvage ; un royaume est un événement.

GÉNÉRATION DÉTERMINISTE PAR GRAINES DE CAPITALE :
  Le monde (16x16 secteurs, fini - Décision Monde fini) est découpé
  en SECTEURS de 64x64 cellules. Les secteurs entièrement océaniques
  ne portent aucune graine. Par secteur terrestre :
  hash(seed, secteur) → 0 à 2 "graines de capitale", placées sur les
  cellules du secteur les plus favorables : basse corruption (bruit
  danger), eau/côte à proximité, terrain praticable (altitude modérée),
  biome hospitalier. Aucun réseau global à calculer : chaque secteur
  se résout seul, ses graines sont connaissables sans générer le
  terrain (lecture pure des couches de bruit) — la carte du monde
  peut donc afficher les royaumes lointains avant toute visite.

TAILLE (tirée à la graine, toute la gamme voulue) :
  hameau-État    : capitale-village seule                (40 %)
  cité-État      : capitale 1 cellule + 1-3 villages     (30 %)
  petit royaume  : capitale 1-2 cellules, 1-2 villes,
                   3-6 villages                          (20 %)
  grand royaume  : capitale 2-4 CELLULES (ville traversant
                   les frontières de cellules — le monde continu
                   3.2 le permet nativement), 2-4 villes,
                   6-12 villages                         (10 %)
  Territoire : cellules contiguës autour de la capitale (croissance
  par coût : le territoire s'étend en évitant hautes corruptions et
  montagnes) ; villes/villages placés dans le territoire le long des
  routes générées (E.2). Deux royaumes proches bornent leurs
  territoires l'un contre l'autre (frontière) ; sinon le territoire
  s'arrête et la wilderness commence.

FRONTIÈRES NATURELLES (Décision — Monde fini, continents et océan) :
  LE TERRITOIRE NE FRANCHIT JAMAIS L'EAU. Un royaume est une masse
  terrestre contiguë ; sa frontière est une CÔTE, une CRÊTE ou le
  voisin — jamais un rayon. Trois conséquences :
   - UN CONTINENT EST UN THÉÂTRE POLITIQUE. Deux royaumes de la même
     masse se touchent, se font la guerre par terre, partagent des
     douanes (14.4). Deux royaumes séparés par la mer n'ont que le
     commerce naval et la colonie : aucune invasion terrestre.
     Le champ diplomacy (B.9) distingue donc voisin TERRESTRE
     (tension, guerre, traité) et voisin MARITIME (commerce, embargo).
   - ROYAUME INSULAIRE : une île portant une seule graine donne un
     royaume isolé -> 100 % de race dominante au lieu de 90 %, une
     seule culture, lois plus divergentes. C'est le mécanisme le plus
     simple pour rendre une race lisible comme PEUPLE (12.2/B.9).
   - DÉTROITS ET ISTHMES : les rares passages terrestres entre deux
     masses et les bras de mer étroits sont des positions
     stratégiques — un royaume qui en tient un lève un péage et
     attire une guerre. Marqués comme POI de type "passage".
  LA TERRE EST FINIE, DONC L'EXPANSION EST À SOMME NULLE : s'étendre,
  c'est prendre à la wilderness ou à quelqu'un.

IDENTITÉ (déterministe à la graine) :
  - Race dominante : choisie selon le biome de la capitale (affinités
    déclarées dans les données de race — ex. nains → montagnes) ;
    ~90 % de la population générée est de la race dominante, ~10 %
    d'autres races, et TOUT rôle de gouvernance/leadership_role est
    exclusivement de la race dominante (12.2/B.9).
  - **Culture (12.5/B.11) :** tirage pondéré par `race_affinity` parmi
    les 7 cultures (C.9) selon la race dominante du royaume — un
    royaume humain peut tirer n'importe quelle culture (sino,
    nordique, latine...), un royaume nain penche vers le nordique.
    Détermine ensuite noms de PNJ, noms de villes et titres des rôles
    de leadership (E.31).
  - Gouvernance : tirage pondéré par la race/culture (données),
    puis taxes, tarifs, lois (dont absurdes, E.26), palette
    architecturale (9.2) et nom du royaume généré (gabarits par
    langue, 10.1 — distinct du nom des villes, qui suit E.31).
  - COMMERCES ET HALLS DE GUILDE : chaque ville tire ALÉATOIREMENT
    ses types de boutiques (forgeron, alchimiste, libraire, tailleur,
    épicier...) et ses halls de guilde parmi les 12 (7.3) — avec la
    règle : MAXIMUM UN EXEMPLAIRE DE CHAQUE TYPE PAR VILLE. Nombre
    tiré selon la taille (hameau 0-1 boutique, capitale 5-8 boutiques
    + 2-4 halls). Conséquence voulue : aucune ville n'a tout —
    trouver "la ville qui a un hall des Enchanteurs" est une vraie
    information (rumeurs E.23, guilde Exploration), et le voyage
    inter-villes reste utile à haut niveau.
  - Relations initiales entre royaumes voisins : tirage pondéré par
    compatibilité de gouvernance et de race (deux dictatures
    frontalières = tension probable) → champ diplomacy (B.9).

MATÉRIALISATION PARESSEUSE — un royaume "existe" en données dès que
  son secteur est interrogé (carte du monde), mais ses villes/PNJ ne
  sont INSTANCIÉS qu'à l'approche du joueur (E.2 première visite,
  puis LOD E.18). Un royaume jamais visité ne coûte rien.
LE ROYAUME DU JOUEUR naît différemment (14.4) : par ses claims —
  même schéma B.9, gouvernance choisie par le joueur à la fondation (14.4).
```

## Liens
- **Dépend de** : [[Décision — Monde fini, continents et océan]], [[Unification macro-micro]], [[Schéma royaume]], [[Culture de nommage — schéma]], [[Races]], [[Niveau de danger]]
- **Alimente** : [[Gouvernance, lois et diplomatie]], [[Génération de noms]], [[Halls de guilde]], [[Villages PNJ — repeuplement et décimation]], [[L'information comme récompense]]
- **Voir aussi** : [[Carte du monde]], [[LOD de simulation]], [[Quêtes et guildes]], [[Lois et infractions]], [[Cultures de nommage]], [[Localisation]], [[Direction artistique]]
