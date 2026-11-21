# Battle Arena Test

A 2D platform fighter for 2 to 4 players. Every hit raises the target's damage percentage; the
higher it is, the farther the target flies. Knock your opponents out of the arena to take their
lives. The last fighter standing wins.

**Status:** milestone 4, content and feel: three fighters (Kade, Pip, Brum), three arenas
(Pebble, Terraces, Ferry) and the test arena, menus, 2 to 4 players on keyboard and gamepads,
computer opponents in three levels, shield, dodges, grabs and the ways out of combos, effects,
sounds and music made in code.

## Controls

- Player 1: W A S D, Space attacks, left Shift or Ctrl shields
- Player 2: arrow keys, Enter attacks, right Shift or Ctrl shields
- Gamepads: stick or D-pad, A or Y jumps, X or B attacks, shoulder buttons shield, Start pauses
- The direction held picks the attack; in the shield, a direction rolls or dodges and attack grabs
- Esc pauses; F1 info and hitboxes, F2 tuning panel, F5 restart

## Built with

- [Godot](https://godotengine.org) 4.7 (standard build, GDScript)

## Running

Open `project.godot` in Godot 4.7 and press F5.

## Tests

```
godot --headless --path . -s res://tests/run_tests.gd
```

The exit code is 0 when all tests pass. Test files are `tests/test_*.gd`; each extends
`res://tests/base_test.gd`.

## Documents

- [Game design](docs/GAME_DESIGN.md): rules, movement, combat, controls, milestones and open
  decisions.

## License

Not chosen yet.
