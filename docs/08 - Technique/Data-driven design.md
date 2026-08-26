---
aliases: ["10", "10. Architecture technique", "Data-driven", "Data-Driven Design", "Godot", "Tags composants"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

L'intégralité du jeu est pilotée par des données, pas par du code en dur. Les systèmes réagissent aux tags présents, jamais à des identifiants codés en dur.

**Moteur cible : Godot.**

**Principe fondamental :** l'intégralité du jeu doit être pilotée par des données (data-driven), pas par du code en dur. Objectifs :
- Ajouter du contenu (matériaux, objets, monstres, biomes, modules de compétences, recettes, etc.) doit être aussi simple que créer/éditer une entrée de données, sans toucher au code.
- Les systèmes doivent interagir entre eux nativement, plutôt que via des cas particuliers codés en dur.

**Piste d'implémentation (à discuter) :** une architecture à base de **tags/composants** (façon ECS — Entity Component System), où :
- Un matériau, un objet, un monstre, etc. est une combinaison de composants de données (ex : `Dureté`, `Densité`, `Inflammable`, `Catégorie:Bois`, `Conducteur`, `Densité de mana`...).
- Les systèmes de jeu (feu, physique, craft, récolte, IA...) réagissent aux **tags/composants présents**, pas à des identifiants spécifiques codés en dur — ce qui permet aux systèmes d'interagir automatiquement entre eux (ex : le système de feu affecte tout objet possédant le tag `Inflammable`, qu'il s'agisse de bois, de tissu ou d'huile, sans code dédié à chaque cas).
- Le contenu (nouveaux matériaux, monstres, recettes, biomes...) se définit dans des fichiers de données (JSON ou équivalent) en assemblant ces composants.

**Portée :** le data-driven vise avant tout à accélérer le développement interne (ajout rapide de contenu par l'équipe) — pas une priorité de support au moddage communautaire pour l'instant.

**Décisions :**
- **Format : JSON confirmé** (tous les schémas de l'Annexe B font foi — voir [[Schéma matériau]], [[Schéma objet et recette]], [[Vocabulaire des modules — six axes]], [[Schéma créature]], [[Biomes — schéma]], [[Gabarit de quête]], [[Catalogue des couches de bruit]], [[Schéma royaume]], [[Salles et connecteurs]], [[Culture de nommage — schéma]], [[Composant et recette d'obtention]]).
- **Éditeur de contenu interne : non au lancement** — JSON édité à la main, avec la validation de schéma au boot + hot-reload F5 ([[Décisions d'architecture]]) comme filet ; un éditeur visuel n'est envisagé que si le volume de contenu le justifie plus tard.

**Contrainte permanente ([[Contraintes permanentes]]) :** *tout le contenu est de la donnée : aucune valeur de gameplay codée en dur, validation des schémas au boot, rechargement à chaud.*

**Tags dérivés automatiquement ([[Schéma matériau]]) :** flammabilité ≥ 50 → `inflammable`, etc. — les systèmes à tags réagissent aux tags, les formules fines à la valeur graduée.

**Règle de couplage ([[EventBus]]) :** *aucun système n'appelle directement un autre système de gameplay ; tout couplage passe par les données (tags) ou l'EventBus.*

**Risque ([[Risques majeurs]]) :** architecture data-driven à grande échelle — bien conçue dès le départ, sinon coûteuse à retrofit plus tard.

## Liens
- **Dépend de** : [[Contraintes permanentes]]
- **Alimente** : [[Arborescence du projet]], [[Décisions d'architecture]], [[EventBus]], [[Localisation]], tous les schémas de l'Annexe B
- **Voir aussi** : [[Schéma matériau]], [[Vocabulaire des modules — six axes]], [[IA des créatures]], [[Risques majeurs]], [[Ordre de construction]]
