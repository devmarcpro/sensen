---
aliases: ["Monde fini", "Continents", "Îles", "Océan", "Plaques tectoniques", "Monde-planète", "Décision — Monde fini"]
tags: [monde, génération, structure, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!success] Décidé le 2026-08-26 — remplace le monde infini
> Le monde n'est plus un plan infini généré à la volée : c'est **une planète bornée**, faite de continents, d'îles et d'un océan qui les sépare. Répercuté dans [[Grille continue]], [[Carte du monde]], [[Génération par couches de bruit]], [[Unification macro-micro]], [[Génération des royaumes PNJ]], [[Véhicules]].

Le monde est fini et structuré comme la Terre — ce qui donne aux royaumes de vraies frontières et au bateau une vraie raison d'exister.

## Pourquoi

L'infini avait un coût caché : **rien n'y est rare**. Une terre illimitée rend l'expansion gratuite, la frontière arbitraire, la mer décorative. Trois conséquences de design en découlent directement du passage au fini :

1. **Les royaumes obtiennent des frontières qu'ils n'ont pas choisies.** Une côte, une chaîne, un détroit : la géographie décide où un royaume s'arrête, et non un rayon de croissance abstrait.
2. **La terre devient à somme nulle.** S'étendre, c'est prendre à quelqu'un. Le [[Royaume du joueur]] entre dans une carte déjà pleine.
3. **L'océan devient un obstacle, pas un raccourci.** Le bateau cesse d'être un bonus de vitesse : il est la seule clé d'un continent entier ([[Véhicules]]).

## La taille

| Échelle | Dimension | Note |
|---|---|---|
| tuile | 1 m | l'unité de jeu ([[Grille continue]]) |
| chunk | 32 × 32 tuiles | streaming |
| cellule | 128 × 128 tuiles | claim, zonage, case de carte |
| secteur | 64 × 64 cellules | unité de génération politique ([[Génération des royaumes PNJ]]) |
| **monde** | **16 × 16 secteurs** = **1024 × 1024 cellules** = **131 072 tuiles de côté** | ~131 km de côté |

**Terres émergées : ~35 %**, réparties en **5 à 7 continents** et plusieurs dizaines d'îles.

**Gain technique immédiat :** les coordonnées sont bornées. Un identifiant de cellule tient dans un `u32` (10 bits `x` + 10 bits `y`), une position de tuile dans deux `i32` sans risque de débordement, et la sauvegarde a une **taille maximale connue** — ce qui retire le premier risque listé dans [[Risques majeurs]].

*La taille est le seul cadran : elle vit dans `data/monde/planete.json` ([[Décision — Pipeline de contenu]]), pas dans le code.*

## Comment on obtient des continents — les plaques

Un simple masque d'atténuation aux bords donnerait une île unique, ronde et molle. On génère donc la **tectonique**, ce qui produit d'un coup les continents, les îles *et* les montagnes — et supprime une couche de bruit à accorder.

```
1. PLAQUES — hash(seed) place P = 24 germes de plaque (Voronoï) sur
   le carré du monde. Chaque plaque tire :
     - un TYPE : continentale (40 %) ou océanique (60 %)
     - un VECTEUR DE DÉRIVE (direction + vitesse)
   Toute plaque dont le germe est à moins de 2 secteurs du bord est
   FORCÉE océanique -> le monde est bordé d'océan, sans mur.

2. CONTINENTALITÉ — en un point p :
     base    = +1.0 si plaque continentale, -1.0 si océanique
     bordure = f(distance de p a la frontiere de plaque la plus proche)
     continentalite(p) = warp(base + bordure) + bruit basse frequence
   Le DOMAIN WARPING est obligatoire : sans lui les côtes suivent les
   arêtes de Voronoï et ça se voit immédiatement.
   Terre émergée si continentalite > seuil_mer, seuil calibré pour 35 %.

3. FRONTIÈRES DE PLAQUE — le type découle des deux vecteurs de dérive,
   et détermine le relief le long de la suture :
     convergente  continentale / continentale -> CHAÎNE DE MONTAGNES
        (ridged noise à son maximum sur la suture)          [Himalaya]
     convergente  océanique / continentale    -> CORDILLÈRE CÔTIÈRE
        + fosse au large + volcans                          [Andes]
     convergente  océanique / océanique       -> ARC INSULAIRE
        (chapelet d'îles volcaniques)                       [Japon]
     divergente                                -> DORSALE, rift, îles
        basses ; sur terre : vallée de rift et lacs allongés
     coulissante                               -> failles, relief bas

4. POINTS CHAUDS — hash(seed, i) place 8 à 14 points chauds,
   INDÉPENDANTS des plaques -> chapelets d'îles en plein océan.
   C'est la seule terre loin de tout : terre de fin de jeu. [Hawaï]

5. ÎLES CONTINENTALES — aucun code dédié : les fragments de plaque
   continentale que le seuil de mer sépare du corps principal SONT
   les grandes îles.                        [Madagascar, Britanniques]
```

**Conséquence sur [[Génération par couches de bruit]] :** la couche *activité sismique/volcanique* n'est plus un bruit libre — elle **dérive des frontières de plaque**. Une couche de moins à accorder, et le volcan se trouve désormais là où il devrait être.

Tout reste **déterministe et sans état** : la tectonique se calcule par `hash(seed, …)` en lecture pure, comme les graines de capitale. Interroger un point lointain ne demande toujours pas de générer le chemin qui y mène.

## Ce que ça change pour les royaumes

C'est le gain principal. [[Génération des royaumes PNJ]] fait déjà croître un territoire « en évitant hautes corruptions et montagnes ». Le monde fini ajoute quatre règles :

- **Le territoire ne franchit pas l'eau.** Un royaume est une **masse terrestre contiguë**. Sa frontière est une côte, une crête ou la frontière d'un voisin — jamais un rayon.
- **Un continent est un théâtre politique.** Deux royaumes de la même masse terrestre se touchent, se font la guerre par terre, ont des douanes communes ([[Lois et infractions]]). Deux royaumes séparés par la mer n'ont que le **commerce naval** et la **colonie** — aucune invasion terrestre possible.
- **Les royaumes insulaires sont différents par construction.** Une île qui ne porte qu'une seule graine de capitale donne un royaume isolé : **100 % de race dominante** au lieu de 90 %, une seule culture, des lois qui divergent ([[Gouvernance, lois et diplomatie]]). C'est le mécanisme le plus simple pour rendre une race lisible comme peuple ([[Races]], [[Réputation et relations]]).
- **Le détroit et l'isthme sont des lieux.** Les rares passages terrestres et les bras de mer étroits entre deux masses sont des positions stratégiques — un royaume qui en tient un contrôle un péage et une guerre.

**L'expansion devient un choix politique.** Le [[Royaume du joueur]] naît par claims dans une carte pleine : chaque cellule prise est prise à la wilderness ou à quelqu'un.

## Ce que ça change pour le bateau

Le bateau passe de **bonus de vitesse** à **porte**.

- **La barque** ([[Véhicules]]) reste côtière, fluviale et lacustre. En haute mer elle est un pari.
- **Le voilier** est ce qui ouvre un second continent. Le tirant d'eau, la surface de voile et la flottaison — déjà spécifiés — deviennent des arbitrages réels au lieu de chiffres décoratifs.
- **La haute mer est dangereuse par un système déjà écrit :** la [[Météo]] rend les voiliers ingouvernables en tempête, et le vent par cellule module déjà la vitesse. Aucune mécanique nouvelle : le large est simplement l'endroit où l'on ne peut pas débarquer en attendant que ça passe.
- **Le voyage rapide en mer ne s'ouvre que sur les routes maritimes déjà parcourues une fois** — cohérent avec le principe de [[Carte du monde]] : *le voyage rapide est un raccourci par-dessus un monde qui existe vraiment*.

**Le bord du monde n'est pas un mur :** l'anneau extérieur est un océan profond battu par une tempête permanente, qui repousse. Le joueur ne rencontre jamais une limite, seulement une mer qu'on ne franchit pas.

## Ce que ça résout

> [!success] La barrière du Dark Continent est trouvée
> [[Ouvert — Dark Continent]] laissait ouverte *« la nature de la barrière géographique »*. C'est **l'océan** : le Dark Continent est une masse terrestre réelle, la plus lointaine, atteignable par une seule traversée hauturière. L'expédition financée par le royaume prend son sens littéral — il faut une flotte, des vivres et un équipage, pas un laissez-passer.

## Ce qui ne change pas

- **Aucune coupure, aucun écran de chargement.** Le monde reste une grille continue ([[Grille continue]]) : fini ne veut pas dire découpé en zones.
- **Le danger reste une propriété du lieu** ([[Niveau de danger]]) — toujours aucun lien avec la distance à l'origine, toujours aucun scaling sur le joueur. Un continent lointain n'est pas dur *parce qu'il est loin*, mais parce que sa corruption est haute.
- **La matérialisation reste paresseuse** ([[LOD de simulation]]) : un continent jamais visité ne coûte rien.
- **Tous les chiffres de densité** de [[Unification macro-micro]] (village 4 %, donjon 6 %, camp 8 %, sanctuaire 3 %, filon 6 % par cellule) s'appliquent inchangés — aux cellules **terrestres**.

## Liens
- **Dépend de** : [[Grille continue]], [[Unification macro-micro]], [[Génération par couches de bruit]]
- **Alimente** : [[Carte du monde]], [[Génération des royaumes PNJ]], [[Véhicules]], [[Ouvert — Dark Continent]], [[Royaume du joueur]], [[Risques majeurs]]
- **Voir aussi** : [[Terrain spectaculaire]], [[Eau et liquides]], [[Météo]], [[Niveau de danger]], [[Biomes de départ]], [[Décision — Pipeline de contenu]], [[Décisions fondatrices]]
