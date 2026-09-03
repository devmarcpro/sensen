---
aliases: ["Armure par zone", "Constructions d'armure", "Matelassé Cuir Mailles Écailles Plaque"]
tags: [objets, équipement, combat, formule, décidé]
domaine: objets
statut: décidé
etape: 3
---

L'armure est une réduction plate par zone, et les « types » d'armure n'existent pas comme étiquettes : ils émergent des constructions.

**Armure = réduction plate par zone** (remplace la mitigation par dés, cause structurelle de l'écrasement des dégâts) :

`dégâts_finaux = (dégâts_bruts × zone_mult − armure_zone)`, minimum 1, avec
`armure_zone = dureté_composite / 4 × qualité × (1 + niveau_construction / 100)`.

**Zone nue = 0** : pas de casque, la tête prend le ×2.5 en plein. La garde reste **la** défense active ([[Garde en posture]]) ; l'armure est le filet.

**Les « types » d'armure n'existent pas comme étiquettes — ils émergent des CONSTRUCTIONS**, qui sont des recettes de composant ([[Composant et recette d'obtention]]) avec leur profil contre les types de dégâts :

| Construction | Matériaux typiques | Fort contre | Faible contre |
|---|---|---|---|
| Matelassé | tissus, fibres | contondant | perforant |
| Cuir | peaux (paramétriques) | tranchant (léger) | perforant |
| Mailles | anneaux de métal | tranchant | contondant |
| Écailles | métal, os, écailles | tranchant, perforant | contondant |
| Plaque | lingots, os massif | tranchant, perforant | — |

**La matrice, chiffrée le 2026-08-26** (elle manquait — « fort contre » n'avait aucune valeur). Elle multiplie **`armure_zone`**, jamais les dégâts bruts, et reste dans la **même bande compressée** que les multiplicateurs élémentaires :

| Construction | tranchant | perforant | contondant |
|---|---|---|---|
| Matelassé | 0.95 | **0.80** | **1.25** |
| Cuir | 1.10 | **0.85** | 1.00 |
| Mailles | **1.25** | **0.80** | 0.85 |
| Écailles | 1.20 | 1.10 | 0.85 |
| Plaque | **1.30** | 1.20 | 0.95 |

La formule complète devient :

`armure_zone = dureté_composite / 4 × qualité × (1 + niveau_construction / 100) × matrice[construction][type_dégâts]`

Bande **0.80 – 1.30** : lisible, jamais décisive seule. C'est ce qui donne corps à *« les flèches percent les mailles, la plaque les arrête »* — mailles/perforant **0.80** contre plaque/perforant **1.20**.

Le **matériau reste libre dans la construction** : la construction donne le profil, le matériau donne les chiffres (dureté, poids, isolation, élément). Le lourd/léger émerge de la densité, jamais d'une règle.

**Côté rendu, la même règle vaut ([[Squelette modulaire et points d'attache]]) : la construction est la forme, le matériau est la teinte.** On ne dessine donc pas une armure par objet, mais **une par construction** — 5 formes × 8 segments ≈ **40 sprites pour la totalité de l'armure du jeu**, les variantes de matériau venant du remapping de palette en shader ([[Palette de couleurs des matériaux]]).

**Vecteur défensif — par zone ET moyenne du personnage :**
- **Par zone** : un coup ciblé se résout contre le vecteur de **la pièce touchée** — blinder une zone contre un élément est un vrai choix, mais avec des multiplicateurs **compressés** (×1.20 / ×0.85 / ×0.95) qui ne justifient jamais de transporter une seconde panoplie.
- **Moyenne du personnage** (casque 0.20 · cuirasse 0.35 · brassards 0.15 · jambières 0.20 · bottes 0.10) : pour tout ce qui n'a pas de zone — explosions, sorts de zone, auras, environnement.

**Le garde-fou anti-swap est la compétence de construction elle-même** : un joueur qui a porté des mailles 40 heures a un niveau Mailles élevé et un niveau Plaque proche de zéro — enfiler des plaques « pour ce donjon-ci » le rendrait **objectivement plus fragile** malgré de meilleurs chiffres bruts. Changer de construction est un changement de *build*, jamais un ajustement tactique. Aucune interdiction à écrire.

**Dégâts à distance** : mêmes règles que la mêlée — trajectoire réelle, zone frappée, type perforant/contondant, matrice des constructions (les flèches percent les mailles, la plaque les arrête). **Dégâts magiques** : la réduction de zone ne s'applique qu'à **50 %** — la vraie défense magique est **l'alignement Wu Xing** de l'armure portée.

**XP de construction ([[XP de combat]]) :** l'armure gagne ce qu'elle **épargne** — `dégâts évités` versés à la compétence de construction de la pièce touchée. Une zone nue ne rapporte rien, et la compétence de construction augmente en retour la réduction de la pièce.

**Formule héritée (dés d'armure) :** voir [[Armures et poids porté]] — remplacée par la réduction plate ci-dessus, conservée pour référence.

> [!success] Tranché le 2026-09-03 — **le tissu, les vêtements et la tenue de mage** (designer)
> « Rajoute des équipements, notamment tout ce qui est vêtements, mage, etc. »
> **Le catalogue n'avait que de l'armure** — plaque, cuir, mailles, écailles, matelassé. Rien à se mettre quand on ne part pas se battre, et rien pour un personnage qui mise sur les sorts. Alors que la **matière existait déjà** pour ça : la soie d'araignée conduit le mana à **104** pour une densité de **1**, la laine isole, le lin ne pèse rien.
> **Une construction de plus** : `tissu`, la plus légère et la moins protectrice de la matrice (1,45 tranchant · 1,55 perforant · 1,50 contondant — plus le facteur est haut, moins l'armure vaut). Son intérêt n'est pas de protéger : c'est le **poids** et l'**isolation**.
> **Et la pièce qui manquait pour l'habiter** : l'**étoffe**, le grand pan d'un vêtement, là où une armure a une plaque. Un vêtement se lit alors comme tout le reste — étoffe · sangles · doublure, trois pièces.
> **Huit vêtements** : tunique, chausses, capuche, manchettes, chaussons pour l'habillement courant ; robe, coiffe, étole pour la tenue de mage. Tous se fabriquent à l'atelier de tissage.
>
> > [!bug] Quatre constructions sur cinq n'avaient pas de nom
> > Trouvé par accident en ajoutant le tissu : le gabarit `nom.armure_en` = « {base} de {construction} en {matériau} » lit `construction.<c>.nom`, et **seule la plaque en avait un**. Une cuirasse de mailles s'affichait donc « Cuirasse de construction.mailles.nom en Fer ». Les cinq ont désormais leur nom.
>
> > [!question] Ce que je n'ai pas tranché — **l'armure doit-elle gêner les sorts ?**
> > Aujourd'hui, non : rien ne lie ce qu'on porte au coût ou à la puissance d'un sort, et la conductivité de mana n'est lue que sur **l'arme tenue** (c'est ce que dit [[Application des stats de matériau]] : « via l'arme tenue »). Une robe de soie d'araignée n'aide donc pas encore un lanceur autrement que par son poids plume.
> > **Deux façons de le faire, si tu le veux** : (1) étendre la formule de conductivité aux pièces portées — une ligne, mais c'est modifier une formule décidée ; (2) une pénalité de sort liée au poids de l'armure, ce qui rendrait le tissu structurant pour un mage sans toucher à l'existant. Je penche pour la (2), qui crée un vrai choix au lieu d'un bonus de plus — mais c'est ta décision, pas la mienne.

> [!success] Tranché le 2026-09-03 — **chaque construction donne une stat** (designer)
> « Je me dis, est-ce que ça serait pas mal de donner des bonus de stats par type d'armure : un type d'armure améliore la force, les armures type mage la volonté, les vêtements le charisme, etc. »
> **Oui — et c'est ce qui répond à la question laissée ouverte deux heures plus tôt** (« l'armure doit-elle gêner les sorts ? »). Plutôt qu'une pénalité, une **identité positive** : chaque construction donne quelque chose, et c'est ce qu'elle donne qui décide de ce qu'on porte.
> **La condition pour que ça marche, et elle n'est pas négociable** : le bonus doit aller **contre le grain**, jamais avec. Si la plaque donnait à la fois la meilleure armure **et** le plus gros bonus, elle serait strictement supérieure et il n'y aurait plus de choix du tout — le système entier ne servirait qu'à rendre les guerriers plus forts. Donc : **plus une construction protège, moins elle donne**.
>
> | construction | stat | par pièce | pourquoi |
> |---|---|---|---|
> | **plaque** | force | +1 | porter l'acier, c'est déjà de la force |
> | **mailles** | endurance | +1 | le poids qu'on encaisse toute la journée |
> | **écailles** | perception | +1 | la vigilance de qui ne peut pas tourner la tête vite |
> | **cuir** | dextérité | +2 | la souplesse, sa raison d'être |
> | **matelassé** | endurance | +2 | le rembourrage, plus proche du corps |
> | **rituel** | **volonté** | +3 | la tenue de mage : rien pour le corps, tout pour l'esprit |
> | **tissu** | **charisme** | +3 | un vêtement ne protège pas, il vous présente |
>
> Une armure complète de plaque donne **+5 force** ; une tenue rituelle complète, **+15 volonté**. L'écart est voulu : la première protège, la seconde n'a que ça.
> **La tenue de mage se sépare des vêtements** : `rituel` (robe, coiffe, étole) contre `tissu` (tunique, chausses, capuche, manchettes, chaussons). Le designer distinguait les deux dans sa phrase — volonté pour le mage, charisme pour le vêtement — et il avait raison : ce ne sont pas les mêmes objets.
> **Les valeurs sont un premier jet**, mesurées et à juger : c'est le rapport entre elles qui compte, pas leur niveau absolu.

## Liens
- **Dépend de** : [[Zones de coup par dénivelé]], [[Équipement — 14 slots]], [[Composant et recette d'obtention]], [[Qualité d'artisanat]]
- **Alimente** : [[XP de combat]], [[Pipeline de résolution du combat]], [[Compétences — liste]]
- **Voir aussi** : [[Garde en posture]], [[Domination et multiplicateurs]], [[Armures et poids porté]], [[Application des stats de matériau]], [[Décisions fondatrices]], [[Craft compositionnel]]
