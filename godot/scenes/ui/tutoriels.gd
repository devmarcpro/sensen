class_name Tutoriels
extends Node
## L'onboarding sans script (Tooltips contextuels, E.19) : un système léger abonné à l'EventBus,
## piloté par `data/tutorials/` — un déclencheur = un signal + des conditions, un texte, une fois.
## Information pure : rien n'est verrouillé derrière un tutoriel. L'état « vu » vivra dans le
## profil joueur (Sauvegarde) ; ici il tient la session.

var afficher: Callable          # comment montrer le texte (le client décide : journal, bulle…)
var vus: Dictionary = {}        # id → true
var actifs := true              # « mode vétéran » = tout off


func _ready() -> void:
	# Un abonnement par signal distinct, avec le nom du signal en argument lié.
	var signaux := {}
	for t: Dictionary in GameData.catalogues.get("tutorials", {}).values():
		signaux[str(t.trigger.signal)] = true
	for nom: String in signaux.keys():
		if EventBus.has_signal(nom):
			EventBus.connect(nom, _sur_evenement.bind(nom))


## Les arguments du signal sont reçus en position ; le nom du signal est lié en dernier.
func _sur_evenement(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null, e: Variant = null) -> void:
	var args := [a, b, c, d, e]
	var nom: String = ""
	for i in range(args.size() - 1, -1, -1):
		if args[i] is String and not str(args[i]).is_empty():
			nom = str(args[i])
			break
	if not actifs or nom.is_empty():
		return
	for id: String in GameData.catalogues.get("tutorials", {}).keys():
		var t: Dictionary = GameData.catalogues["tutorials"][id]
		if str(t.trigger.signal) != nom or (t.get("once", true) and vus.has(id)):
			continue
		if not _conditions_ok(t.trigger.get("conditions", {}), args):
			continue
		vus[id] = true
		if afficher.is_valid():
			afficher.call(tr(t.text_key))


## Conditions : `cle` = le premier argument String du signal doit valoir cette clé (journal).
func _conditions_ok(conditions: Dictionary, args: Array) -> bool:
	if conditions.has("cle"):
		return args.size() > 0 and str(args[0]) == str(conditions.cle)
	return true
