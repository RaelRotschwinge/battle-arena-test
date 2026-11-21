# Headless test runner. Runs every res://tests/test_*.gd and exits with 0 when all tests pass,
# 1 otherwise:
#
#   godot --headless --path <project folder> -s res://tests/run_tests.gd
#
# A test file extends "res://tests/base_test.gd". Every method whose name starts with "test_" is
# one test and runs on a fresh instance of its file. A test fails on a failed assertion and on any
# engine or script error logged while it runs.
extends SceneTree

const TEST_DIR := "res://tests/"


class ErrorCounter extends Logger:
	var _count := 0
	var _mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_count += 1
		_mutex.unlock()

	func count() -> int:
		_mutex.lock()
		var value := _count
		_mutex.unlock()
		return value


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	for file_name in _test_files():
		var script := load(TEST_DIR + file_name) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s: the script does not load" % file_name)
			failed += 1
			continue
		for method in script.get_script_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue
			var errors_before := errors.count()
			var test_case = script.new()
			test_case.call(test_name)
			var failures: Array[String] = test_case.failures
			if errors.count() > errors_before:
				failures.append("an error was logged while the test ran (see above)")
			if failures.is_empty():
				passed += 1
				print("ok   %s :: %s" % [file_name, test_name])
			else:
				failed += 1
				for failure in failures:
					print("FAIL %s :: %s: %s" % [file_name, test_name, failure])
	OS.remove_logger(errors)
	print("%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 and passed > 0 else 1)


func _test_files() -> PackedStringArray:
	var files := PackedStringArray()
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append(file_name)
	files.sort()
	return files
