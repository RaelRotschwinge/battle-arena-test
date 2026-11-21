# Battle Arena Test

A 2D platform fighter for 2 to 4 players. Every hit raises the target's damage percentage; the
higher it is, the farther the target flies. Knock your opponents out of the arena to take their
lives. The last fighter standing wins.

**Status:** milestone 2, the combat prototype: two players on one keyboard fight a full match
with three lives each on the test arena.

## Controls

- Player 1: W A S D, Space attacks
- Player 2: arrow keys, Enter attacks
- The direction held picks the attack
- F1 info and hitboxes, F2 tuning panel, F5 restart

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
