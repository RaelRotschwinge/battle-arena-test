# Tests of the device choice on the fighter select (game design, "Menus"): a slot may only choose
# devices no earlier slot has locked, locking moves a later slot off the device, a press of attack
# locks or joins.
extends "res://tests/base_test.gd"

const DeviceSlots := preload("res://ui/device_slots.gd")

const DEVICES := ["kb1", "kb2", "pad0", "pad1"]


func test_a_press_joins_the_next_slot_locked() -> void:
	var s := DeviceSlots.new()
	assert_eq(s.press("pad0", DEVICES), 0, "first slot")
	assert_true(s.locked(0) and s.device(0) == "pad0", "locked to the pad")
	assert_eq(s.press("kb1", DEVICES), 1, "second slot")
	assert_eq(s.owner_of("pad0"), 0, "the pad steers slot 0")
	assert_eq(s.press("pad0", DEVICES), -1, "a locked device joins no second slot")


func test_a_device_locked_by_an_earlier_slot_is_not_offered() -> void:
	var s := DeviceSlots.new()
	s.press("pad0", DEVICES)
	s.join(1, DEVICES)
	assert_true(not s.choices(1, DEVICES).has("pad0"), "player 2 cannot choose player 1's pad")
	assert_eq(s.device(1), "kb1", "player 2 gets a free device")
	for n in 6:
		s.cycle(1, 1, DEVICES)
		assert_true(s.device(1) != "pad0", "cycling skips the locked pad")


func test_switching_and_locking_frees_the_old_device() -> void:
	var s := DeviceSlots.new()
	s.press("pad0", DEVICES)
	s.join(1, DEVICES)
	s.cycle(0, 1, DEVICES)  # Player 1 moves off the pad: open now.
	assert_true(not s.locked(0), "changing the device opens the slot")
	while s.device(0) != "kb1":
		s.cycle(0, 1, DEVICES)
	assert_true(s.choices(1, DEVICES).has("pad0"), "an open choice blocks nothing")
	s.lock(0, DEVICES)
	assert_true(s.choices(1, DEVICES).has("pad0"), "the pad is free for player 2")
	assert_true(not s.choices(1, DEVICES).has("kb1"), "player 1's keys are not")


func test_an_earlier_slot_takes_a_device_over_from_a_later_one() -> void:
	var s := DeviceSlots.new()
	s.join(0, DEVICES)  # By mouse: open, on kb1.
	s.press("pad1", DEVICES)  # Player 2 joins with pad1, locked.
	assert_eq(s.owner_of("pad1"), 1, "pad1 steers player 2")
	while s.device(0) != "pad1":
		s.cycle(0, 1, DEVICES)
	assert_true(s.lock(0, DEVICES), "player 1 comes first and may lock it")
	assert_eq(s.owner_of("pad1"), 0, "now pad1 steers player 1")
	assert_true(not s.locked(1) and s.device(1) != "pad1", "player 2 moved on, open again")


func test_a_press_on_a_chosen_device_locks_that_slot() -> void:
	var s := DeviceSlots.new()
	s.join(0, DEVICES)
	s.join(1, DEVICES)
	while s.device(1) != "pad0":
		s.cycle(1, 1, DEVICES)
	assert_eq(s.press("pad0", DEVICES), 1, "the press locks player 2's choice")
	assert_true(s.locked(1), "locked")
	assert_true(not s.joined(2), "and joins no new slot")


func test_an_unplugged_pad_leaves_the_slot_open() -> void:
	var s := DeviceSlots.new()
	s.press("pad1", DEVICES)
	s.forget_missing(["kb1", "kb2", "pad0"])
	assert_true(s.joined(0) and not s.locked(0) and s.device(0) == "", "open, without a device")


func test_the_last_players_return_to_their_own_panels() -> void:
	var s := DeviceSlots.new()
	assert_eq(s.place(2, "kb2", DEVICES), 2, "back into panel 3")
	assert_true(s.locked(2) and not s.joined(0), "locked there, panel 1 stays empty")
	assert_eq(s.place(2, "pad0", DEVICES), 0, "a taken panel falls back to the first free one")


func test_a_slot_opened_by_mistake_stays_with_its_old_device() -> void:
	var s := DeviceSlots.new()
	s.press("kb1", DEVICES)
	s.cycle(0, 1, DEVICES)  # Switched by mistake: now kb2 is chosen, open.
	assert_eq(s.steering("kb1"), 0, "kb1 still steers player 1")
	assert_eq(s.press("kb1", DEVICES), 0, "attack on kb1 locks it again")
	assert_true(s.locked(0) and s.device(0) == "kb1", "back on kb1")
	s.cycle(0, 1, DEVICES)
	s.press("kb2", DEVICES)  # kb2 is chosen by player 1: this locks player 1 to kb2.
	assert_eq(s.owner_of("kb2"), 0, "the new device locked")
	assert_eq(s.steering("kb1"), -1, "the old one is free again")
