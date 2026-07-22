@abstract
class_name StdLinkedListBase
extends IStdListCollection
## Abstract base that stores shared size state for linked-list implementations.


var _size: int = 0


#region Public API
## Returns the number of values in the list.
func size() -> int:
	return _size


## Returns [code]true[/code] if the list contains no values.
func is_empty() -> bool:
	return _size == 0
#endregion Public API
