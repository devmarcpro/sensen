---
aliases: ["6.2", "6.2 Équipement", "14 slots", "Équipement", "Slots d'équipement"]
tags: [objets, équipement, décidé]
domaine: objets
statut: décidé
etape: 3
---

La grille de 14 slots — et le principe directeur : l'armure est permanente, l'arme est situationnelle.

**Principe directeur** — l'armure est **permanente**, l'arme est **situationnelle**. Le système de rotation situationnelle existe déjà et s'appelle le **râtelier** ([[Cinq accès au cycle]]) ; l'armure définit l'identité durable du personnage. Le jeu ne doit jamais récompenser le transport de cinq panoplies.

**La grille (14 slots) :**
- **Armure (5), mappée sur les zones de coup** ([[Zones de coup par dénivelé]]) : Casque (tête, la zone ×2.5) · Cuirasse (torse) · Brassards-gants (bras et mains) · Jambières (jambes) · Bottes (pieds, + effets de déplacement).
  *Chaque slot peint exactement les segments du rig qu'il protège* ([[Squelette modulaire et points d'attache]]) : Casque → tête · Cuirasse → torse · Brassards-gants → bras haut, bras bas, main · Jambières → jambe haut, jambe bas · Bottes → pied. **L'affichage de l'équipement est gratuit** — le rig *est* la grille d'armure.
- **Mains (2)** : principale et secondaire, chacune acceptant arme, bouclier, torche, lanterne, grimoire ou outil. Le combat lit **les slots**, jamais « l'objet en main ». Deux Mains occupe les deux ; dual wielding = deux armes ; bouclier en secondaire (règles de la garde-bouclier : [[Décision — Boucliers]]).
- **Munitions (1)** : carquois (munitions compositionnelles : pointe + hampe — [[Composants]]).
- **Bijoux (3)** : 2 anneaux (effets mineurs) · 1 amulette (effet majeur unique — le slot du build).
- **Utilitaires (3)** : dos (**cape** = stats/isolation **OU sac** = capacité, jamais les deux) · 2 accessoires portés.

**Emplacements par morphologie ([[Schéma créature]]) :** quadrupède = tête, torse, selle, amulette, 2 accessoires · volant = tête, torse, amulette, 2 accessoires · amorphe = amulette, 2 accessoires (`equip_slots`).

**Extension de jauge de chaîne ([[Jauge de chaîne Wu Xing]]) :** l'amulette exceptionnelle est l'une des trois sources de +1 segment.

**Anneaux de transmutation ([[Modificateurs d'affinité]]) :** l'un des [[Cinq accès au cycle]] occupe les 2 slots d'anneaux.

**Pools d'effets par slot ([[Effets d'équipement types]]) :** anneaux/amulettes tirent 1-2 effets, armes/armures 0-1.

**Règles d'armure :** voir [[Armure par zone et constructions]].

> [!bug] Corrigé le 2026-09-01 — le jeu n'avait que 9 des 14 slots (designer)
> « il manque des slots d'équipement non ? on avait pas décidé qu'il y en aurait plus que ça ? ». Exact, et c'est un écart avec cette note même : l'écran d'inventaire n'affichait que **neuf** emplacements — deux mains, casque, cuirasse, jambières, deux anneaux, amulette, carquois. Manquaient les **brassards-gants**, les **bottes**, le **dos** (cape ou sac) et les **deux accessoires**. Le rig, lui, connaissait déjà `brassards` et `bottes` dans ses `slots_segments` : l'armure se serait peinte toute seule, il n'y avait simplement aucun objet à y mettre ni de case pour l'y poser. Les quatorze sont désormais là, avec deux armures assemblées de plus (brassards, bottes) et deux objets de dos qui portent la décision « cape **ou** sac, jamais les deux ».


## Liens
- **Dépend de** : [[Zones de coup par dénivelé]], [[Craft compositionnel]]
- **Alimente** : [[Armure par zone et constructions]], [[Effets d'équipement passifs]], [[Loot — affixes, gemmes et rareté]]
- **Voir aussi** : [[Cinq accès au cycle]], [[Modificateurs d'affinité]], [[Schéma créature]], [[Armures et poids porté]], [[Composants]], [[Effets d'équipement types]], [[Décision — Boucliers]]
