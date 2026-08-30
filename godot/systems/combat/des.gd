class_name Des
extends RefCounted
## Jets de dés XdY (Pipeline de résolution du combat). Le host tire tous les dés ; le RNG est
## seedé par tick pour la reproductibilité en debug (Réseau).

var _rng := RandomNumberGenerator.new()


func _init(graine: int = 0) -> void:
	_rng.seed = graine


## Re-seed déterministe : graine de partie ⊕ tick courant.
func seeder_tick(graine: int, tick: int) -> void:
	_rng.seed = hash([graine, tick])


## "2d6" → somme de 2 dés à 6 faces. "2d6+1" accepté. "3" → constante 3. Vide → 0.
func jet(notation: Variant, des_bonus: int = 0) -> int:
	if notation == null:
		return 0
	var s := str(notation).strip_edges()
	if s.is_empty():
		return 0
	var parts := Des.analyser(s)
	var total: int = parts.bonus
	for i in parts.n + des_bonus:
		total += _rng.randi_range(1, parts.faces) if parts.faces > 0 else 0
	return total


func entier(min_v: int, max_v: int) -> int:
	return _rng.randi_range(min_v, max_v)


func reel() -> float:
	return _rng.randf()


## Décompose "XdY+Z" en {n, faces, bonus}. "5" → {n:0, faces:0, bonus:5}.
static func analyser(s: String) -> Dictionary:
	var r := {"n": 0, "faces": 0, "bonus": 0}
	var reste := s
	var plus := reste.find("+")
	if plus >= 0:
		r.bonus = int(reste.substr(plus + 1))
		reste = reste.substr(0, plus)
	var d := reste.find("d")
	if d < 0:
		r.bonus += int(reste)
		return r
	r.n = int(reste.substr(0, d))
	r.faces = int(reste.substr(d + 1))
	return r


## La notation multipliée : « 3d6 » × 2 → « 6d6 », « 1d4+1 » × 3 → « 3d4+3 », « 5 » × 2 → « 10 » (noyau répété).
static func multiplier(notation: String, n: int) -> String:
	var p := analyser(notation)
	if p.faces == 0:
		return str(p.bonus * n)
	return "%dd%d" % [p.n * n, p.faces] + ("+%d" % (p.bonus * n) if p.bonus > 0 else "")


## Fourchette [min, max] d'une notation, avec dés en plus.
static func fourchette(notation: Variant, des_bonus: int = 0) -> Vector2i:
	if notation == null:
		return Vector2i.ZERO
	var p := analyser(str(notation))
	var n: int = p.n + des_bonus
	if p.faces == 0:
		return Vector2i(p.bonus, p.bonus)
	return Vector2i(n + p.bonus, n * p.faces + p.bonus)


## Un jet sur un générateur donné (le loot est semé) : « 1d2 », « 3 », « 2d4+1 ».
static func jet_rng(notation: String, rng: RandomNumberGenerator) -> int:
	var p := analyser(notation)
	if p.faces == 0:
		return int(p.bonus)
	var total: int = int(p.bonus)
	for i in int(p.n):
		total += rng.randi_range(1, int(p.faces))
	return total
