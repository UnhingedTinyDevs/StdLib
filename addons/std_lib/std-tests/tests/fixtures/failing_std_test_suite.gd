extends StdTest
## Intentional failures used to verify result accounting without failing the outer suite.


func _test_assertion_failure() -> void:
	assert_eq(1, 2, "intentional mismatch")
	return


func _test_zero_checks_failure() -> void:
	return
