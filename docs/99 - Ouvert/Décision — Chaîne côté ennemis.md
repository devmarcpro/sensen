---
aliases: ["Décision — Chaîne côté ennemis", "Ouvert — Chaîne côté ennemis", "Chaîne ennemis", "chain_gauge"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Tranché sur délégation du designer (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable au playtest comme toute décision.

**La décision : pas de jauge pour le tout-venant — une jauge pour les élites et les boss.**

- Les **créatures ordinaires n'ont pas de jauge de chaîne** : leur menace vient du nombre, du placement et de leurs actions ([[Décision — Vocabulaire d'attaque des créatures]]). Simple, lisible, et l'IA n'a pas à savoir construire une chaîne.
- Les **élites humaines** (chef de bande, ermite, pillard — flag `chain_gauge: true` dans [[Schéma créature]], défaut `false`) et les **boss de donjon** ([[Génération de donjon]] : la créature de la `boss_room`) **ont une jauge de 5 segments**, exactement les mêmes règles que le joueur ([[Jauge de chaîne Wu Xing]] — même objet de code, zéro système nouveau), **affichée sous leur barre de vie**.
- **L'interruption devient un jeu défensif** : tout contrôle qui interrompt (Étourdi, Choc statique — [[Modules]]) **retire le dernier segment posé** de la jauge adverse. Lire la barre du boss et couper sa rotation avant le 5ᵉ acte est une décision tactique de premier ordre.
- L'IA des porteurs de jauge privilégie les transitions d'engendrement dans son scoring utility (considération `chain_bonus` — une donnée du profil, pas du code).

## Liens
- **Dépend de** : [[Jauge de chaîne Wu Xing]], [[Schéma créature]], [[Trous connus du combat]]
- **Alimente** : [[IA des créatures]], [[Écrans d'interface]], [[Génération de donjon]], [[Statuts de contrôle et anti-stunlock]]
- **Voir aussi** : [[Modules]], [[Attaque lourde et télégraphe]], [[Créatures]]
