---
aliases: ["Ouvert — Fourchettes des gemmes", "Fourchettes gemmes", "Pools d'affixes"]
tags: [ouvert, objets, loot, décidé-par-défaut]
domaine: objets
statut: décidé-par-défaut
etape: 3
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** les fourchettes des gemmes, le plafond de **+15 par compétence**, et la **taille des pools d'affixes**.

**Valeurs par défaut posées ([[Loot — affixes, gemmes et rareté]]) :**
- Rubis/Saphir/Émeraude/Topaze/Onyx : +[1-3] dégâts élémentaires OU +[4-10] domaine
- Diamant : +[0.03-0.08] qualité · Améthyste : mana ou Méditation · Grenat : PV ou Force/Endurance · Opale : durée des statuts ou Volonté/Charisme · Ambre : endurance ou compétence physique
- Taille en affinité : misérable +0.04 → mythique +0.28
- **Plafond : +15 par compétence toutes gemmes confondues**

**Ce qui en dépend :** l'équilibre de la règle d'or « l'atelier améliore, le donjon transforme » — si les gemmes montent trop, l'atelier concurrence le dungeon crawling ; la viabilité de la voie de purification par sertissage ([[Modificateurs d'affinité]]).

**Question liée :** la taille des pools d'affixes (combien de gabarits par famille sur les six familles).

**Implémentable sans :** oui — la structure en générateurs paramétrés est posée, seules les valeurs bougent.

## Le défaut : les fourchettes de A.12 sont retenues telles quelles

Toutes les valeurs de [[Loot — affixes, gemmes et rareté]] sont implémentables sans changement — y compris le **plafond de +15 par compétence** toutes gemmes confondues.

**Taille des pools d'affixes au lancement (fixée) :** **6 gabarits par famille × 6 familles = 36 gabarits**. Comme chaque gabarit porte des fourchettes tirées à la génération ([[Loot — affixes, gemmes et rareté]] : *« une attaque sur [2-4] porte [élément] » = 15 variantes d'une seule ligne*), 36 gabarits produisent **plusieurs centaines d'affixes distincts** — largement de quoi tenir jusqu'au premier playtest de loot (étape 3).

## Liens
- **Dépend de** : [[Loot — affixes, gemmes et rareté]], [[Catalogue matériaux — Gemmes]]
- **Alimente** : [[Modificateurs d'affinité]], [[Qualité d'artisanat]]
- **Voir aussi** : [[Effets d'équipement types]], [[Trésors et artefacts]], [[Décisions fondatrices]]
