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
  fighter (100 is average). The launch speed is in pixels per tick.
- **Hitstun.** After a launch the target cannot act for a number of ticks that grows with the
  launch speed (starting value: `launch_speed * 1.5` ticks). In hitstun the target falls with half
  the gravity and the launch fades slowly, so strong hits carry it far. A target that hits the
  ground fast in hitstun bounces off it once; slower, it lands and can act again.
- **Blast zones.** A rectangle well outside the visible arena. A fighter whose body leaves it loses
  a life.
- **Lives.** 3 lives per fighter by default. The last fighter with lives left wins. A time mode
  (most knockouts in a set time) comes later.
- **Respawn.** After a lost life the fighter returns on a platform above the arena at 0 %. The
  platform holds it until its player presses a key, at most 2 seconds; the key acts at once.
  Leaving the platform gives 2 seconds of invulnerability, shown by blinking. On the platform the
  fighter cannot be hit either.

## Movement

| Move | Milestone | Notes |
|---|---|---|
| Walk and run | M1 | Run after a quick double tap or a full stick tilt |
| Jump | M1 | Short hop on a quick tap, full jump on hold: letting go of up while rising cuts the jump |
| Double jump | M1 | One extra jump in the air, restored on landing. It always adds its full height, also while the first jump still rises |
| Air control | M1 | Steering in the air, slower than on the ground |
| Fast fall | M1 | Pressing down at the top of a jump makes the fall faster |
| Drop through | M1 | Down on a thin platform drops through it |
| Ledge grab | M1 | A falling fighter next to a ledge hangs on it (see below) |
| Wall jump | M1 | Pressing against a wall and up jumps off the wall (see below) |
| Recovery move | M2 | The up air: up and attack in the air carries the fighter up, once per time in the air (section "Combat") |
| Shield and dodge | M3 | Blocks hits for a while; a dodge gives short invulnerability. Keys open (Open decisions, 4) |

**Ledges.** The top corners of the main platform are ledges. A fighter falling past one close
enough grabs it and hangs beside the wall, facing the arena; the double jump and the wall jumps
come back. On the ledge, up jumps off it, toward the arena climbs up (starting value: 12 ticks),
down or away lets go. Hanging longer than 5 seconds lets go by itself, and after letting go no
ledge can be grabbed for half a second. A ledge holds one fighter at a time. A fighter rising
past a ledge does not grab it.

**Walls.** The sides of solid platforms are walls. Pressing against a wall in the air and pressing
up jumps off it, up and away from the wall, without using the double jump. Up without pressing
against the wall is the double jump. Three wall jumps per time in the air; landing or grabbing a
ledge gives them back.

The starting values of all movement numbers are in `scripts/sim/fighter_stats.gd`; the tuning
panel (F2) changes them while playing.

## Combat

Attacks have startup, active and recovery ticks (60 ticks per second). Each attack has one
hitbox; each fighter's body is its hurtbox. A hitbox that touches a hurtbox during its active
ticks deals damage and knockback once per attack. Hits that land in the same tick all count, so
two fighters hitting each other at once both get hit (a trade). A fighter hanging on a ledge can be
hit and is knocked off it.

| Attack | Keys | Milestone |
|---|---|---|
| Jab | Attack on the ground, no direction | M2 |
| Side attack | Left or right and attack on the ground; the fighter turns to that side | M2 |
| Uppercut | Up and attack on the ground, in either order, also attack during the take-off of a jump. It comes out at once and reaches from the chest to above the head, so it also hits a fighter standing in the attacker | M2 |
| Low kick | Down and attack on the ground: a quick, flat sweep to both sides at once, pushes the opponent away low; fighters standing in each other can hit each other with it | M2 |
| Neutral air | Attack in the air, no direction: hits all around, launches away from the attacker | M2 |
| Forward air | Left or right and attack in the air; the fighter turns to that side | M2 |
| Up air | Up and attack in the air: hits upward, the first one in a time in the air carries the fighter up (see below) | M2 |
| Ground pound | Down and attack in the air (see below) | M2 |
| Back air; special moves (keys open, Open decisions 4) | | M4 |
| Strong attacks (charged) | | M4 |
| Grab and throw | | open |

The starting values of every attack (ticks, hitbox, damage, knockback and angle) are in
`scripts/sim/attacks.gd`. Starting KO points of the side attack, against a fighter that steers
back: about 100 % near the edge, about 155 % from the middle of the arena; the uppercut about
125 %.

**Air attacks** allow steering and fast fall, but no jumps while they last. Landing during one ends
it with a short landing lag (starting value: 2 ticks). Grabbing a ledge ends it too.

**Up air and recovery.** Up and attack in the air is an upward hit and can be used as often as any
other air attack. The first one in a time in the air also carries the fighter up while its hitbox
is out (starting value: 13 pixels per tick for 11 ticks, never slower than the fighter already
rises), with steering; this lift is the recovery move. Landing, grabbing a ledge or being hit
gives the lift back. The double jump stays available.

**Ground pound.** Down and attack in the air: the fighter stops in the air for a moment (starting
value: 4 ticks), then drops straight down fast (starting value: twice the fast-fall speed) until
it lands. It hits every fighter it meets on the way down and launches it downward; a fighter on
the ground bounces up. Landing ends it with a short recovery (starting value: 6 ticks).

**Hit feel:** a short hit pause on both fighters (starting value: 3 ticks plus half a tick per
point of damage) in which the target shakes, a hit effect, light screen shake on strong hits and
on a knockout. Keys pressed during the hit pause count right after it.

**Match end.** When only one fighter has lives left, the win screen names the winner; after a
second, an attack key starts a new match.

## Fighters

- **M1 to M3:** one test fighter as a simple shape, used to tune movement and combat.
- **M4:** three original fighters with different weights and styles, for example a light and fast
  one, an average one and a heavy one. Their look, names and move sets are designed then.

## Arenas

- **Test arena (M1):** one solid main platform with open edges, ledges at both top corners and
  walls high enough for wall jumps, two thin platforms above it that fighters can stand on and
  drop through, blast zones around it.
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

**The direction held picks the attack.** On the ground, no direction gives the jab, left or right
the side attack, up the uppercut, down the low kick. In the air, no direction gives the neutral
air, left or right the forward air, up the up air, down the ground pound (section "Combat").

**No exact timing needed.** The controls forgive presses that come a little early or late:

- **Buffer.** A press of attack or up that cannot act at once (during an attack, a landing lag,
  the take-off of a jump or hitstun) waits up to 8 ticks and acts as soon as it can. Attacks and
  jumps chain without waiting for the right tick.
- **Direction after attack.** A direction pressed up to 2 ticks after attack still picks the
  attack, so attack and direction need not be pressed in the same tick.
- **Up held from a jump does not count.** Up is also the jump key, so up counts for an attack only
  when it was pressed shortly before (starting value: 6 ticks). Holding up for a full jump and
  pressing attack gives the neutral or forward air, not the up air.
- **Attack and up together.** Attack and up pressed in the same tick give the uppercut (on the
  ground) or the up air, not a jump. Attack pressed during the take-off of a jump (starting value:
  3 ticks) gives the uppercut at once instead of the jump.

Players join by pressing their attack key or button. Remapping keys comes later.

**Testing aids:** F1 shows the fighters' state, their hurtboxes and hitboxes and the blast zone,
F2 opens the tuning panel, F5 restarts the match.

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
| **M3 Match flow** | Main menu, joining, fighter and arena select, 4 players, pause, rematch, shield and dodge | A full evening of local matches works without restarts |
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
