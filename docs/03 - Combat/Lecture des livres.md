---
aliases: ["A.7", "Annexe A.7", "Lecture", "Lecture des livres"]
tags: [combat, progression, formule, décidé]
domaine: combat
statut: décidé
etape: 3
---

La formule de lecture d'un livre : un jet de compétence universel, un livre consommé dans tous les cas.

```
Jet : 1d20 + N_lecture/2 + Perception/4  vs  DD = 10 + difficulte_livre/2
Réussite        → modules_obtenus = max(1, floor(nb_modules_du_livre
                    * min(1, N_lecture / difficulte_livre)))
Réussite de 10+ → tous les modules du livre + bonus d'XP
Échec           → effet mineur (étourdissement 5 s, perte de mana)
Échec de 10+ ou 1 naturel → effet grave (confusion, téléportation,
                    invocation hostile de niveau ≈ difficulté)
XP de lecture = difficulte_livre * 5 (succès) ou * 2 (échec)
Le livre est consommé dans tous les cas (section 5).
```

**Données extensibles :** la table détaillée des effets d'échec vit en données (`data/reading_failures.json`).

**Signal :** `book_read` sur l'EventBus, écouté par les modules et les effets d'échec ([[EventBus]]).

**Statuts déclenchés en cas d'échec :** Étourdi, Confusion ([[Statuts]]).

## Liens
- **Dépend de** : [[Jet de compétence universel]], [[Grimoires et manuels]], [[Stats de personnage]]
- **Alimente** : [[Modules]], [[Statuts]]
- **Voir aussi** : [[Compétences — liste]], [[EventBus]], [[Meubles]], [[Mana]], [[Tooltips contextuels]]
