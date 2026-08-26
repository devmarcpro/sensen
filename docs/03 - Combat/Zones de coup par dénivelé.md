---
aliases: ["Zones de coup", "Zones par dénivelé", "Zones de coup dérivées du dénivelé"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

La zone du corps frappée n'est jamais visée : elle est une conséquence du dénivelé. C'est ce qui rend la hauteur de terrain mécaniquement centrale.

**Zones dérivées du DÉNIVELÉ**, jamais visées :
- attaquer une cible située **plus bas** donne la **tête** (**×2.5**) ;
- attaquer **plus haut** ne touche que les **jambes** (**×0.8**) ;
- à **hauteur égale**, le **torse** (**×1.0**).

La zone est une conséquence du positionnement — c'est ce qui rend la hauteur de terrain mécaniquement centrale ([[Hauteur de terrain ±10]]).

**Ce que ça remplace ([[Décisions fondatrices]]) :** le combat directionnel à la Mount & Blade est abandonné — zones dérivées du dénivelé, garde en posture frontale, télégraphe = icône d'interface.

**Application défensive ([[Armure par zone et constructions]]) :**
`dégâts_finaux = (dégâts_bruts × zone_mult − armure_zone)`, minimum 1.
**Zone nue = 0** : pas de casque, la tête prend le ×2.5 en plein.

Les 5 slots d'armure sont **mappés sur les zones de coup** ([[Équipement — 14 slots]]) : Casque (tête, la zone ×2.5) · Cuirasse (torse) · Brassards-gants (bras et mains) · Jambières (jambes) · Bottes (pieds).

Pour tout ce qui **n'a pas de zone** (explosions, sorts de zone, auras, environnement), on utilise la **moyenne du personnage** : casque 0.20 · cuirasse 0.35 · brassards 0.15 · jambières 0.20 · bottes 0.10.

**Affixes déclencheurs :** « au coup en [zone] : [étourdit/saigne] » ([[Loot — affixes, gemmes et rareté]]).

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Combat tactique sur grille]]
- **Alimente** : [[Armure par zone et constructions]], [[Équipement — 14 slots]], [[Pipeline de résolution du combat]]
- **Voir aussi** : [[Décisions fondatrices]], [[Garde en posture]], [[Loot — affixes, gemmes et rareté]], [[XP de combat]]
