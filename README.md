# Battle Arena Test

A 2D platform fighter for 2 to 4 players. Every hit raises the target's damage percentage; the
higher it is, the farther the target flies. Knock your opponents out of the arena to take their
lives. The last fighter standing wins.

**Status:** milestone 4.5, more content: three fighters (Kade, Pip, Brum), each with a special
move of its own, seven arenas (Pebble, Terraces, Ferry, Flatiron, Cistern, Windlass, Kettle) and
a training arena, a fighter select with stat sheets and a device choice per player, an arena
select with live previews, a training mode, options (full screen, volumes, screen shake), mouse
control in every menu, 2 to 4 players on keyboard and gamepads, computer opponents in three
levels, shield, dodges, grabs and the ways out of combos. Everything is drawn and synthesized in
code, with upbeat electronic music that speeds up as the damage rises.

## Controls

- Player 1: W A S D, Space attacks, E special, left Shift or Ctrl shields
- Player 2: arrow keys, Enter attacks, Backspace special, right Shift or Ctrl shields
- Gamepads: stick or D-pad, A or Y jumps, X attacks, B special, shoulder buttons shield, Start
  pauses
- The direction held picks the attack and aims the special; in the shield, a direction rolls or
  dodges and attack grabs
- Esc pauses; F1 info and hitboxes, F2 tuning panel, F5 restart, F11 full screen

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
