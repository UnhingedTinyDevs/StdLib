class_name StdRandomStream
extends RandomNumberGenerator
## A deterministic named random stream with common game-oriented helpers.
##
## Instances are created and cached by [code]StdRandom.stream[/code]. Each stream
## advances independently, so draws in one subsystem do not shift another.
## A stream is also a [RandomNumberGenerator] and can be passed directly to
## APIs such as [code]StdBag.new[/code] and [code]StdGrid2D.random_free_cell[/code].


var _dice_re: RegEx


#region Engine Methods
func _init() -> void:
	_dice_re = RegEx.new()
	var _error: int = _dice_re.compile("^(\\d*)d(\\d+)([+-]\\d+)?$")
	return
#endregion Engine Methods


#region Public API
## A normally distributed pseudo-random float.
func gaussian(mean: float = 0.0, deviation: float = 1.0) -> float:
	return self.randfn(mean, deviation)


## True with the given probability. Values outside [code]0..1[/code]
## are clamped with a warning. The exact edges consume no draw.
func chance(probability: float) -> bool:
	if is_nan(probability):
		push_warning("chance probability is NAN, treating it as 0")
		return false
	if probability < 0.0 or probability > 1.0:
		push_warning("chance probability %f outside 0..1, clamping" % probability)
		probability = clampf(probability, 0.0, 1.0)
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return self.randf() < probability


## A uniformly random element of [param items], or [code]none[/code]
## when the array is empty.
func pick(items: Array) -> StdOption:
	if items.is_empty():
		return StdOption.none()
	return StdOption.some(items[self.randi_range(0, items.size() - 1)])


## Shuffles [param items] in place with this stream (Fisher-Yates).
func shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = self.randi_range(0, i)
		var swapped: Variant = items[i]
		items[i] = items[j]
		items[j] = swapped
		pass
	return


## Rolls dice notation: [code]"3d6+2"[/code], [code]"d20"[/code],
## [code]"2d8-1"[/code] (case-insensitive, surrounding whitespace
## ignored). On success the ok value is the total ([int]). Errs on
## malformed notation or zero dice/sides.
func roll(notation: String) -> StdResult:
	var matched: RegExMatch = _dice_re.search(notation.strip_edges().to_lower())
	if matched == null:
		return StdResult.err("invalid dice notation '%s'" % notation)
	var count: int = 1 if matched.get_string(1).is_empty() else int(matched.get_string(1))
	var sides: int = int(matched.get_string(2))
	var modifier: int = 0 if matched.get_string(3).is_empty() else int(matched.get_string(3))
	if count < 1:
		return StdResult.err("dice count must be at least 1, got %d" % count)
	if sides < 1:
		return StdResult.err("dice must have at least 1 side, got %d" % sides)
	var total: int = modifier
	for _i: int in count:
		total += self.randi_range(1, sides)
		pass
	return StdResult.ok(total)
#endregion Public API
