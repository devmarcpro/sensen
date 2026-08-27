---
aliases: ["C.6", "Annexe C.6", "Domaines de grimoires", "Domaines de magie", "Manuels"]
tags: [progression, combat, contenu, décidé]
domaine: progression
statut: décidé
etape: 3
---

Les 9 domaines de grimoires et 4 de manuels, avec leur mapping vers le Wu Xing.

- **Grimoires (9) :** Feu, Eau/Glace, Foudre, Terre, Vie (soin/nature), **Métal** (lames invoquées, perforation, affûtage — ajouté pour compléter le pentagramme Wu Xing), Arcane (pur mana, projectiles/boucliers), Espace (téléport, portée), Corruption (dégâts sur soi pour puissance — lié à la couche danger)
- **Mapping Wu Xing ([[Wu Xing — cycles et vecteurs]]) :** Feu→Feu · Eau/Glace→Eau · Terre→Terre · Métal→Métal · **Foudre et Vie→Bois** (le tonnerre du printemps et la croissance, attribution traditionnelle du Wu Xing) · Arcane/Espace/Corruption→hors cycle (neutres)
- **Manuels :** Frappes (effets d'attaque), Postures (buffs de maniement), Techniques (mobilité, contres), Maîtrise (modificateurs : multi-coups, portée...)

> *Note : le titre de la section C.6 annonce « 8 domaines de grimoires » tandis que la liste en énumère 9 (l'ajout du domaine Métal). Les deux formulations sont conservées telles quelles ; la liste fait foi. La décision de [[Grimoires et manuels]] parle de « 8 domaines de grimoires + 4 de manuels ».*

**Vecteurs canoniques ([[Domination et multiplicateurs]]) :**
```
  Domaines : Feu {feu:1} · Eau/Glace {eau:1} · Terre {terre:1}
    · Métal {metal:1} · Foudre et Vie {bois:1} (attribution
    traditionnelle : le tonnerre du printemps, la croissance)
    · Arcane {0.2 partout} — quasi neutre PAR CONSTRUCTION, sans
      règle d'exception · Espace {eau:0.6, metal:0.4}
    · Corruption {terre:0.5, feu:0.5}   (défauts à équilibrer)
```

**Une compétence par domaine ([[Compétences — liste]]).**

**Filtrage des livres ([[Grimoires et manuels]]) :** chaque livre généré tire son domaine, qui filtre les modules qu'il contient (champ `grimoire_domains` de [[Vocabulaire des modules — six axes]]).

**Contenu à produire :** [[Ouvert — Modules du domaine Métal]] (5 modules manquants au catalogue [[Modules]]).

**Question ouverte :** [[Ouvert — Répartitions Arcane Espace Corruption]].

> [!success] Codé le 2026-08-28 — le domaine Vie, première pierre
> Module **Renaissance** (`modules/renaissance.json`, noyau Bois → domaine Vie, 40 de mana, 20 ticks, effet `resurrection`) : assemblé avec la forme *Soi*, la capacité rappelle le compagnon dont l'**âme est dans le sac**, gratuitement — c'est le « sort de Vie de haut niveau » de [[Compagnons]] ; le ressuscité revient Affaibli. Le module se trouve dans les grimoires du domaine Vie.

## Liens
- **Dépend de** : [[Wu Xing — cycles et vecteurs]], [[Domination et multiplicateurs]]
- **Alimente** : [[Grimoires et manuels]], [[Modules]], [[Compétences — liste]]
- **Voir aussi** : [[Vocabulaire des modules — six axes]], [[Ouvert — Modules du domaine Métal]], [[Ouvert — Répartitions Arcane Espace Corruption]], [[Compagnons]]
