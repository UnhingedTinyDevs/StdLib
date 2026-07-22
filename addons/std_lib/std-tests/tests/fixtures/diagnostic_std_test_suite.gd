extends StdTest
## Fixture that emits one intentionally unexpected warning.


func _test_unexpected_warning() -> void:
	push_warning("nested unexpected warning")
	assert_true(true, "test continues after warning")
	return
