---
aliases: ["B.3.1", "Annexe B.3.1", "Fonctionnalité", "data/functionalities"]
tags: [objets, données, schéma, décidé]
domaine: objets
statut: décidé
etape: 0
---

Le profil mécanique porté par la fonctionnalité d'un objet — ce qui fait qu'une épée est une épée, indépendamment de ses matériaux.

Profil mécanique porté par la fonctionnalité d'un objet (référencée par le champ `functionality` de [[Schéma objet et recette]], et choisie à la table de sculpture — [[Tables de sculpture]]). Utilisé par les formules [[Stats d'armes]]/[[Armures et poids porté]].

```json
{
  "id": "epee",
  "name_key": "functionality.epee.name",
  "kind": "arme",
  "hands": 1,
  "combat_skill": "epee",
  "degats_des": "2d6",
  "crit_range": 20,
  "vitesse_base": 2.0,
  "portee": 1.5,
  "type_degats": "tranchant",
  "poids_reference": 40
}
```

Pour une armure : `"kind": "armure"`, avec `"equip_slot"` et `"facteur_slot"` à la place des champs d'attaque. Pour un meuble/objet non combattant : `"kind": "mobilier"` etc., sans champs de combat.

**Fonctionnalités de véhicule ([[Véhicules]]) :** `kind: "vehicule"` — Charrette, Char à voile, Draisine mécanique, Barque, Voilier.

**Table des profils d'armes de lancement :** [[Stats d'armes]].

## Liens
- **Dépend de** : [[Schéma objet et recette]], [[Data-driven design]]
- **Alimente** : [[Stats d'armes]], [[Armures et poids porté]], [[Tables de sculpture]], [[Véhicules]]
- **Voir aussi** : [[Pipeline de résolution du combat]], [[Compétences — liste]], [[Localisation]]
