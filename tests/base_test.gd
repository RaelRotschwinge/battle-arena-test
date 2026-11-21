# Base of every test file. A test file starts with: extends "res://tests/base_test.gd"
extends RefCounted

var failures: Array[String] = []


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append(message if message != "" else "expected true")


## Fails unless both values have the same type and are equal (1 and 1.0 count as different).
func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		var prefix := message + ": " if message != "" else ""
		failures.append("%sexpected %s, got %s" % [prefix, var_to_str(expected), var_to_str(actual)])
