---
aliases: ["Contraintes permanentes", "Contraintes", "4 règles"]
tags: [index, architecture, décidé]
domaine: index
statut: décidé
etape: 0
---

Les quatre règles d'architecture à respecter dès la première ligne de code. Coût quasi nul si respectées d'emblée, réécriture complète sinon.

## 1. Une partie solo EST une partie multijoueur hébergée dont la porte est fermée.

Ce n'est pas du contenu réseau — c'est une discipline d'architecture, et elle ne coûte presque rien si elle est respectée dès le départ. Elle coûte une réécriture complète si elle est ajoutée après.

- **Serveur autoritaire, même en solo** : toute la logique de jeu vit côté serveur ; le client envoie des *intentions* et affiche un *état*. En solo les deux tournent dans le même processus, **jamais dans le même code**. ([[Réseau]])
- **Aucun système de gameplay ne lit l'input directement.** Le client produit « je veux attaquer cette tuile », le serveur décide.
- **L'état du monde est sérialisable en permanence** — même exigence que la sauvegarde, payée une fois pour deux usages. ([[Sauvegarde]])
- **Déterminisme** : génération seedée, résolution par ticks, aucun recours au delta de frame dans la logique. ([[Simulation à ticks]], [[Optimisation — principes]])
- **Rien ne suppose « un seul joueur »** : pas de singleton `Player`, pas de caméra qui pilote la logique, pas de pause globale.
- **Les temporalités parallèles sont une notion du modèle dès le départ** ([[Temporalités parallèles]]) : une horloge du monde, une par combat, une par donjon. Écrire une horloge unique globale en solo garantit de tout réécrire plus tard.

*Ce qui reste légitimement en étape 11 : le transport réseau, la découverte de parties, la latence, la reconnexion, l'interpolation. Cela s'ajoute sans rien casser — à condition que ce qui précède soit respecté.* ([[Multijoueur]])

## 2. Une brique à la fois

Chacune avec un critère de sortie formulé **AVANT** de commencer. ([[Ordre de construction]], [[Ordre de vérification]])

## 3. Une seule langue au départ

Mais **toutes les chaînes affichables passent par `tr()` dès le premier écran**. ([[Localisation]])

## 4. Tout le contenu est de la donnée

Aucune valeur de gameplay codée en dur, validation des schémas au boot, rechargement à chaud. ([[Data-driven design]], [[Décisions d'architecture]])

## Liens
- **Dépend de** : [[Décisions fondatrices]]
- **Alimente** : [[Réseau]], [[Sauvegarde]], [[Simulation à ticks]], [[Localisation]], [[Data-driven design]], [[Temporalités parallèles]], [[Ordre de construction]]
- **Voir aussi** : [[Décisions d'architecture]], [[Multijoueur]], [[Ordre de vérification]], [[Risques majeurs]], [[Optimisation — principes]]
