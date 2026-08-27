---
aliases: ["E.19", "Annexe E.19", "Tooltips contextuels", "Onboarding", "Tutoriel"]
tags: [progression, interface, décidé]
domaine: progression
statut: décidé
etape: 1
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : deux déclencheurs voxel retirés (« premier bloc en main + Shift grille fine », « première subdivision → explication des résolutions »), remplacés par le déclencheur de construction générique.

L'onboarding sans script : des tooltips déclenchés par les événements, jamais un verrou de progression.

```
data/tutorials/*.json : { "id", "trigger": {signal EventBus + conditions},
  "text_key", "once": true, "delay_ticks", "category" }
Exemples :
  premier arbre visé → tooltip récolte/outils
  premier élément de construction en main → placement + ghost preview (4.1)
  premier livre ramassé → lecture, risque d'échec
  première créature hostile détectée → bascule mode tactique (5.0)
  faim < 60 la première fois → manger
  premier module obtenu → écran d'assemblage (slots)
  premier claim → rôles de cases (3.3)
  premier PNJ recrutable (relation proche du seuil) → recrutement
Moteur : un système léger abonné à l'EventBus ; état "vu" par profil
joueur (E.10). Catégories désactivables ; "mode vétéran" = tout off.
Aucun contenu de jeu verrouillé derrière un tutoriel — information
pure, jamais de progression conditionnée.
```

**Même principe pour l'UI de craft ([[Craft compositionnel]]) :** *la recette EST le tutoriel — cohérent avec E.19 (information pure, jamais de verrou).*

> [!success] Codé le 2026-08-27
> `scenes/ui/tutoriels.gd` s'abonne aux signaux EventBus cités par `data/tutorials/*.json` (`trigger.signal` + `conditions`, `text_key`, `once`, `category`) et affiche le texte via un rappel du client (dans le journal, préfixé 💡). Quatre tooltips de combat : bascule tactique, télégraphe, premier segment, fin de combat. L'état « vu » tient la session en attendant le profil joueur ([[Sauvegarde]]).

## Liens
- **Dépend de** : [[Début de partie]], [[EventBus]], [[Data-driven design]]
- **Alimente** : [[Craft compositionnel]], [[Écrans d'interface]]
- **Voir aussi** : [[Localisation]], [[Sauvegarde]], [[Grimoires et manuels]], [[Rôles de cases]], [[Faim]]
