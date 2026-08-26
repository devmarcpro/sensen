---
aliases: ["E.6", "Annexe E.6", "Abstraction hors-site", "Hors-site", "Rapport de retour"]
tags: [société, technique, décidé]
domaine: société
statut: décidé
etape: 10
---

Niveau 3 du LOD de simulation : résolution par formules, jamais de simulation accélérée. Un rapport attend le joueur à son retour.

```
Quand aucun joueur n'est dans une zone chargée contenant un claim actif :
les entités du claim sont désinstanciées vers un état abstrait
{pnj: [...], jobs, stocks, defense_totale}.
Au retour du joueur (ou toutes les heures in-game en tâche de fond) :
  résolution par formules, PAS de simulation :
  production = Σ (rendement_job(pnj) * heures * facteur_humeur)
     rendement_job = f(compétence du PNJ, richesse de la zone assignée)
  ventes boutique = débit_client(trafic local) * attractivité_prix (A.8)
  raid éventuel (E.7) résolu en un jet : force_raid vs defense_totale
     defense_totale = Σ gardes (niveau_combat * équipement) + tourelles
     + bonus murs. Victoire → dégâts mineurs listés ; défaite → pertes
     de stocks/structures proportionnelles, jamais de wipe total.
Un rapport (journal) est présenté au joueur à son retour.
```

**Facteur humeur ([[Habitat des PNJ]]) :** `humeur/100 × 1.5` borné [0.4, 1.2].

**Niveau 3 du LOD ([[LOD de simulation]]) :** *aucun joueur dans la zone — résolution à gros grain par période, pas de PNJ individuels actifs.*

**Chantier transversal ([[Risques majeurs]]) :** l'abstraction hors-site est un chantier à concevoir en profondeur ; il impacte l'agriculture/élevage, les boutiques passives et la régénération des cases sauvages.

**Résolution d'une nuit sautée ([[Cycle jour-nuit et sommeil]]) :** le monde est résolu par l'abstraction pour la durée sautée — cultures poussent, boutiques hors-site vendent, timers avancent.

**Rapport hebdomadaire de dette ([[Entretien et taxes]]) :** même mécanisme que le journal.

**Localisation ([[Localisation]]) :** les rapports d'abstraction sont des textes générés — une clé de gabarit par langue avec placeholders, jamais de concaténation.

**Coût ([[Simulation du monde — performance]]) :** résolution par formules à l'échéance ou au retour du joueur — jamais de simulation de fond.

## Liens
- **Dépend de** : [[LOD de simulation]], [[Habitat des PNJ]], [[Agriculture et élevage]]
- **Alimente** : [[Défense et raids]], [[Raids et menaces]], [[Boutique passive]], [[Population et exploitation]], [[Cycle jour-nuit et sommeil]]
- **Voir aussi** : [[Prix suggéré]], [[Entretien et taxes]], [[Sauvegarde]], [[Localisation]], [[Simulation du monde — performance]], [[Risques majeurs]], [[Écrans d'interface]]
