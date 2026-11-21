# Checks that the project is set up the way the game design expects.
extends "res://tests/base_test.gd"


func test_main_scene_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene := load(path) as PackedScene
	assert_true(scene != null, "the main scene %s loads" % path)
	if scene != null:
		var root := scene.instantiate()
		assert_true(root != null, "the main scene instantiates")
		root.free()


func test_simulation_runs_at_60_ticks() -> void:
	var ticks: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	assert_eq(ticks, 60, "physics ticks per second")
