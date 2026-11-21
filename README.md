# Battle Arena Test

A 2D platform fighter for 2 to 4 players. Every hit raises the target's damage percentage; the
higher it is, the farther the target flies. Knock your opponents out of the arena to take their
lives. The last fighter standing wins.

**Status:** milestone 1, the movement prototype: two players on one keyboard move around the
test arena. No fighting yet.

## Controls

- Player 1: W A S D, Space attacks (from milestone 2)
- Player 2: arrow keys, Enter attacks (from milestone 2)
- F1 info, F2 tuning panel, F5 restart

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
