---
aliases: ["H.9", "Annexe H.9", "Tests de conformité — élevage", "Tests de conformité", "spec élevage"]
tags: [technique, élevage, test, décidé]
domaine: technique
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Sept tests à ajouter à `spec`. Ce sont les garde-fous qui font tenir la promesse « une espèce = une fiche de données ».

## Les sept tests

1. **Déterminisme** — `insectesIci()` à graine fixe rend toujours la même liste.
   *(Le déterminisme seedé est une contrainte permanente du projet — [[Contraintes permanentes]].)*

2. **Distribution** — `heriter()` respecte **34/34/16/16 à 1 % près** sur 100 000 tirages ([[Règle d'anneau]]).

3. **Atteignabilité** — **toute variété d'une espèce est atteignable** par croisements successifs depuis deux sauvages quelconques.
   *(Sans ce test, une case du registre peut être impossible à remplir — et le joueur le découvre après cinquante couvées.)*

4. **Cohérence des fiches** — chaque espèce déclare des loci **compatibles avec son groupe**, et **toutes ses conditions existent dans `COND`** ([[Conditions de reproduction]]).
   *(Même exigence que la validation de schéma au boot — [[Décision — Pipeline de contenu]].)*

5. **Faisabilité** — pour chaque espèce, **au moins un couple valide est atteignable dans les conditions générables du monde**.
   > Sans ce test, une espèce impossible à reproduire ne se découvre qu'après trois heures de jeu.

6. **Généricité** — **aucun système ne lit un bloc de l'être sans tester sa présence** ([[Blocs de l'être]]).
   *(C'est le test qui interdit mécaniquement le `if (espèce === 'x')` — la règle d'or de [[Élevage — intention et familles]].)*

7. **Rendu** — le registre reste **lisible sur un écran de téléphone** à effectif maximal d'espèces ([[Vivarium — registre et paliers]]).

## Pourquoi ces tests-là

Les tests **3 et 5** sont les plus importants : ce sont les seuls qui attrapent une erreur de **contenu** (une fiche mal remplie) plutôt qu'une erreur de code. Dans un système où *ajouter une espèce = ajouter un fichier* ([[Décision — Pipeline de contenu]]), ce sont eux qui remplacent la relecture humaine.

Le test **6** est l'équivalent automatisé de la discipline de [[Data-driven design]] — il transforme un principe en garde-fou exécutable.

## Liens
- **Dépend de** : [[Intégration de l'élevage au moteur]], [[Règle d'anneau]], [[Conditions de reproduction]], [[Blocs de l'être]]
- **Alimente** : [[Ordre de vérification]], [[Décision — Pipeline de contenu]]
- **Voir aussi** : [[Élevage — intention et familles]], [[Loci — les dix types]], [[Vivarium — registre et paliers]], [[Contraintes permanentes]]
