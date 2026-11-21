# Battle Arena: game design

The living design document of the game. Numbers are starting values to be tuned in play, not
fixed rules. Points not yet decided are listed under "Open decisions".

## Vision

A fast 2D platform fighter for 2 to 4 players on one screen. Matches are short, hits are easy to
read, and a fighter can always fight back towards the arena. Easy to pick up with a gamepad,
deep enough to keep playing.

**Pillars**

1. **Movement feels tight.** Responsive running, jumping and air control come before everything
   else.
2. **Every hit is readable.** Clear hit effects, hit pause and knockback show who hit whom.
3. **Couch first.** Local play with friends is the main mode; online comes later.
4. **Our own world.** Fighters, arenas, art and sound are original.

## Core rules

- **Damage percentage.** Every fighter starts a life at 0 %. Hits add damage; there is no upper
  limit.
- **Knockback.** A hit launches the target. The launch speed grows with the target's damage after
  the hit and with the attack's strength, and is lower for heavier fighters. Starting formula:

  ```
  launch_speed = base_knockback + knockback_growth * (damage_after_hit / 100) * (100 / weight)
  ```

  `base_knockback`, `knockback_growth` and the launch angle belong to each attack; `weight` to each
  fighter (100 is average).
- **Hitstun.** After a launch the target cannot act for a number of ticks that grows with the
  launch speed (starting value: `launch_speed * 0.4` ticks).
- **Blast zones.** A rectangle well outside the visible arena. A fighter whose body leaves it loses
  a life.
- **Lives.** 3 lives per fighter by default. The last fighter with lives left wins. A time mode
  (most knockouts in a set time) comes later.
- **Respawn.** After a lost life the fighter returns on a platform above the arena at 0 %, with
  2 seconds of invulnerability.

## Movement

| Move | Milestone | Notes |
|---|---|---|
| Walk and run | M1 | Run after a quick double tap or a full stick tilt |
| Jump | M1 | Short hop on a quick tap, full jump on hold |
| Double jump | M1 | One extra jump in the air, restored on landing |
| Air control | M1 | Steering in the air, slower than on the ground |
| Fast fall | M1 | Pressing down at the top of a jump makes the fall faster |
| Drop through | M1 | Down on a thin platform drops through it |
| Recovery move | M2 | Up and attack in the air: a move upwards to get back to the arena |
| Ledge grab | M3 | Holding the edge of the main platform for a moment |
| Shield and dodge | M3 | Blocks hits for a while; a dodge gives short invulnerability. Keys open (Open decisions, 4) |

## Combat

Attacks have startup, active and recovery ticks (60 ticks per second). Each attack has one or
more hitboxes; each fighter has hurtboxes. A hitbox that touches a hurtbox during its active ticks
deals damage and knockback once per attack.

| Attack | Milestone |
|---|---|
| Light attacks on the ground: neutral, side, up | M2 |
| Air attacks: neutral, forward, up | M2 |
| Ground pound (down and attack in the air) | M2 |
| Recovery move (up and attack in the air) | M2 |
| Back air; special moves (keys open, Open decisions 4) | M4 |
| Strong attacks (charged) | M4 |
| Grab and throw | open |

**Ground pound.** Down and attack in the air: the fighter stops in the air for a moment (starting
value: 6 ticks), then drops straight down fast (starting value: twice the fast-fall speed) until
it lands. It hits every fighter it meets on the way down. Landing ends it with a short recovery
(starting value: 12 ticks).

**Hit feel:** a short hit pause on both fighters (more for stronger hits), a hit effect, light
screen shake on strong hits.

## Fighters

- **M1 to M3:** one test fighter as a simple shape, used to tune movement and combat.
- **M4:** three original fighters with different weights and styles, for example a light and fast
  one, an average one and a heavy one. Their look, names and move sets are designed then.

## Arenas

- **Test arena (M1):** one solid main platform with open edges, two thin platforms above it that
  fighters can stand on and drop through, blast zones around it.
- **M4:** two to three original arenas with their own layout and look.

## Camera

One shared camera that keeps all fighters in view, zooms out as they spread and stops at the
edges of the blast zones.

## Controls

Two players share one keyboard with five keys each: player 1 uses W A S D and Space, player 2 the
arrow keys and Enter. Players 3 and 4 use gamepads; a gamepad can also take a keyboard player's
place. Every device has the same actions, so no player has more moves than another.

| Action | Keyboard, player 1 | Keyboard, player 2 | Gamepad |
|---|---|---|---|
| Move left and right | A, D | Left, Right | Left stick or D-pad |
| Jump, double jump | W | Up | A (bottom button) |
| Fast fall, drop through | S | Down | Stick or D-pad down |
| Attack | Space | Enter (both Enter keys) | X (left button) |
| Pause | Esc | Esc | Start |

**The direction held picks the attack.** No direction gives the neutral attack, left or right the
side attack, up the up attack, down the down attack. In the air the same keys give the air
attacks; up and attack is the recovery move, down and attack the ground pound (section "Combat").

**Up attack on the ground.** Up starts a jump after a short take-off (starting value: 3 ticks).
Pressing attack during the take-off gives the up attack instead of the jump.

Players join by pressing their attack key or button. Remapping keys comes later.

## Game modes

- **Versus (M2):** 2 to 4 players, everyone against everyone, lives.
- **Later:** teams, time mode, computer opponents, online versus.

## Technical design

- **Engine:** Godot 4.7, GDScript, standard build.
- **Fixed tick.** The game logic runs at 60 ticks per second in `_physics_process`. One match
  controller reads all inputs of a tick and advances the simulation by exactly one step.
- **Simulation apart from drawing.** The match state (positions, speeds, damage, lives, the
  current move and its tick) lives in plain GDScript classes. Scene nodes only draw that state and
  play effects and sounds.
- **Own collision.** Fighters do not use Godot physics bodies. Movement and collision against the
  arena are our own simple checks (fighters and platforms as boxes); hitboxes and hurtboxes too.
  Reason: full control over the feel, and the same input always gives the same result.
- **Ready for online.** Rules for the simulation from the first line: no unseeded random numbers,
  no clock time, no reading of input outside the per-tick input, and a match state that can be
  copied and restored. Rollback netcode can then re-run ticks later.
- **Display.** Base resolution 1920 x 1080, stretch mode `canvas_items` with aspect `expand`, the
  Compatibility renderer (light for 2D and keeps a web export possible).
- **Tests.** Unit tests for the simulation (movement, knockback, blast zones, lives) run headless
  on the command line with a small runner of our own, `tests/run_tests.gd`, no third-party addon.

**Planned folders**

```
project.godot
scenes/      match, menus
scripts/sim/ simulation: match state, fighters, collision, hits
scripts/view/ nodes that draw the state, effects, camera
fighters/    fighter data and art
arenas/      arena layouts and art
ui/          menus and HUD
tests/       unit tests and their runner
addons/      third-party addons, if any
docs/        this document, credits
```

## Milestones

| | Goal | Done when |
|---|---|---|
| **M0 Setup** | Godot project, folders, Git metadata, test runner, a first headless test | The empty project opens and the test passes |
| **M1 Movement** | Test fighter, test arena, all M1 moves, 2 players, shared camera | Two players move around and the feel is tuned |
| **M2 Combat** | Hitboxes, M2 attacks, damage, knockback, hitstun, blast zones, lives, respawn, win screen | A full 1-on-1 match can be played to the end |
| **M3 Match flow** | Main menu, joining, fighter and arena select, 4 players, pause, rematch, ledge grab, shield and dodge | A full evening of local matches works without restarts |
| **M4 Content and feel** | Three fighters, two to three arenas, effects, sounds, music | The game looks and sounds like itself |
| **M5 Online** | Rollback netcode, lobby, play over the internet | Two players on different machines play a match |

## Open decisions

1. **Art style:** pixel art, flat vector shapes or something else.
2. **Fighters:** how many at first, their concepts and names.
3. **Items:** none, or items that drop into the arena.
4. **Defence and specials:** how far shield, dodge, grab, throw and special moves go, and how they
   fit on five keys per player (for example key combinations).
5. **Teams:** team mode, and whether teammates can hit each other.
6. **Online:** peer-to-peer or a relay server; an existing Godot rollback addon or our own.
7. **Platforms:** Windows first; web, Linux or a store release later.
8. **Name:** the final title of the game.
9. **License:** none chosen yet; without one, the public code stays all rights reserved.
