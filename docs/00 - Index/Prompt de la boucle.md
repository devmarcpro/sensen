---
aliases: ["Prompt de la boucle", "Consigne de la boucle"]
tags: [index, méthode, décidé]
domaine: index
statut: décidé
etape: 0
---

# Prompt de la boucle

> [!info] À coller derrière `/loop` (revu le 2026-09-01)
> Ce fichier n'est pas du design : c'est la consigne de travail autonome. Le prompt vit ici pour qu'une seule version fasse foi.

## Le prompt

```
il reste plein de choses à voir, attente de 60 secondes entre chaque passe

Tu développes Sensen seul pendant que je suis ailleurs. À chaque passe, choisis
UNE chose et va jusqu'au bout : coder, vérifier, noter, commiter, pousser.

Où chercher, dans cet ordre :
1. Ma file dans « 00 - Index/Vers la production ». Elle prime sur tout.
2. Sinon, un écart entre le coffre et le code : une note décrit un
   comportement que le jeu n'a pas, ou le code fait ce qu'aucune note ne dit.
   Lis le coffre, ouvre le jeu, compare.
3. Sinon, regarde le jeu sous un angle neuf : joue une scène, prends une
   capture, lis-la vraiment. Les défauts se voient à l'écran, pas dans le code.

Trois natures de contraintes, à ne jamais mélanger :
- REFUSÉ, ne jamais ajouter : tacle, boss à mécaniques, PA/PM, initiative,
  relances, cases de départ.
- DÉCIDÉ, à respecter et faire vivre sans y toucher : horloge à ticks et
  action-time, résolution simultanée, no-limit des modules, loot et boutiques
  assemblés, temps à l'action en donjon, sauvegarde partout.
- PAS À TOI DE TRANCHER : équilibrage, game-feel, réécriture de design.
  Consigne dans « À juger » et continue — ne bloque jamais sur une question.

Méthode, non négociable :
- Les notes de docs/ font foi, le callout le plus récent gagne. Toute décision
  nouvelle = un callout daté écrit AVANT le code.
- Tout en données : un JSON par entrée, schéma validé au démarrage, aucun
  nombre en dur. GDScript typé, commentaires en français, pas de GDExtension.
- Pas d'assets pour l'instant (c'est une phase, pas un dogme).
- Ne touche jamais à .obsidian/.
- Avant de pousser : la suite complète en tâche de fond (jamais pendant que tu
  édites un script de test), tools/audit_donnees.py, tools/i18n_couverture.py,
  tools/check_vault.py, et une capture d'écran REGARDÉE. Si un écran change,
  refais sa capture du README.
- Une pré-version tous les ~10 commits, **avec son exécutable** : construire depuis le tag
  (`git checkout <tag>`, export « Windows Desktop », retour sur main), zipper, joindre à la release.
  Une release sans binaire n'est pas une release — vérifier avec `gh release view <tag> --json assets`.
- Un test ciblé se lance avec --seul <fragment> : 20 secondes au lieu de 7
  minutes. Ne reste jamais bloqué à attendre la suite complète.

Dis-moi en fin de passe ce que tu as trouvé et changé, en une poignée de
lignes. Pas de plan, pas d'options : agis.
```

## Liens
- **Voir aussi** : [[Vers la production]], [[Ordre de vérification]]
