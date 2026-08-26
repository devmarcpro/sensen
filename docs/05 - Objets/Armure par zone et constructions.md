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

Le **matériau reste libre dans la construction** : la construction donne le profil, le matériau donne les chiffres (dureté, poids, isolation, élément). Le lourd/léger émerge de la densité, jamais d'une règle.

**Vecteur défensif — par zone ET moyenne du personnage :**
- **Par zone** : un coup ciblé se résout contre le vecteur de **la pièce touchée** — blinder une zone contre un élément est un vrai choix, mais avec des multiplicateurs **compressés** (×1.20 / ×0.85 / ×0.95) qui ne justifient jamais de transporter une seconde panoplie.
- **Moyenne du personnage** (casque 0.20 · cuirasse 0.35 · brassards 0.15 · jambières 0.20 · bottes 0.10) : pour tout ce qui n'a pas de zone — explosions, sorts de zone, auras, environnement.

**Le garde-fou anti-swap est la compétence de construction elle-même** : un joueur qui a porté des mailles 40 heures a un niveau Mailles élevé et un niveau Plaque proche de zéro — enfiler des plaques « pour ce donjon-ci » le rendrait **objectivement plus fragile** malgré de meilleurs chiffres bruts. Changer de construction est un changement de *build*, jamais un ajustement tactique. Aucune interdiction à écrire.

**Dégâts à distance** : mêmes règles que la mêlée — trajectoire réelle, zone frappée, type perforant/contondant, matrice des constructions (les flèches percent les mailles, la plaque les arrête). **Dégâts magiques** : la réduction de zone ne s'applique qu'à **50 %** — la vraie défense magique est **l'alignement Wu Xing** de l'armure portée.

**XP de construction ([[XP de combat]]) :** l'armure gagne ce qu'elle **épargne** — `dégâts évités` versés à la compétence de construction de la pièce touchée. Une zone nue ne rapporte rien, et la compétence de construction augmente en retour la réduction de la pièce.

**Formule héritée (dés d'armure) :** voir [[Armures et poids porté]] — remplacée par la réduction plate ci-dessus, conservée pour référence.

## Liens
- **Dépend de** : [[Zones de coup par dénivelé]], [[Équipement — 14 slots]], [[Composant et recette d'obtention]], [[Qualité d'artisanat]]
- **Alimente** : [[XP de combat]], [[Pipeline de résolution du combat]], [[Compétences — liste]]
- **Voir aussi** : [[Garde en posture]], [[Domination et multiplicateurs]], [[Armures et poids porté]], [[Application des stats de matériau]], [[Décisions fondatrices]], [[Craft compositionnel]]
