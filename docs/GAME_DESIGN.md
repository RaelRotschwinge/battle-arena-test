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
| Shield, dodges, grab | M3 | The shield key: shield, roll, spot dodge, air dodge, grab (section "Defence") |

**Ledges.** The top corners of the main platform are ledges. A fighter falling past one close
enough grabs it and hangs beside the wall, facing the arena; the double jump, the air dodge and
the wall jumps come back. The first grab since landing or being hit makes the fighter
invulnerable for half a second; grabbing again without that gives nothing, so hanging on and off
the ledge protects no one. On the ledge:

- up or jump jumps off it,
- toward the arena climbs up (starting value: 12 ticks, invulnerable),
- attack climbs up into a getup attack that hits both sides (invulnerable until it hits),
- the shield key climbs up into a roll onto the arena,
- down or away lets go.

Hanging longer than 3 seconds lets go by itself, and after letting go no ledge can be grabbed for
half a second. A ledge holds one fighter at a time: a fighter that grabs a ledge someone hangs on
takes it over, and the one hanging falls off (no ledge hogging). A fighter rising past a ledge
does not grab it.

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
| Back air | Left or right against the way the fighter faces and attack in the air: a kick backward; the fighter does not turn | M3 |
| Dash attack | Attack while running: a lunge that carries the fighter on | M3 |
| Getup attack | Attack on a ledge (section "Movement") | M3 |
| Grab and throws | Attack while shielding grabs; the direction held throws (section "Defence") | M3 |
| Special moves, strong attacks | No key for them for now (Open decisions 4) | open |

The starting values of every attack (ticks, hitbox, damage, knockback and angle) are in
`scripts/sim/attacks.gd`. Starting KO points of the side attack, against a fighter that steers
back: about 100 % near the edge, about 155 % from the middle of the arena; the uppercut about
125 %.

**Facing in the air.** A fighter keeps the way it faces in the air. Left or right toward it gives
the forward air, against it the back air.

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

**Match end.** When only one fighter has lives left, the winner is shown, then the results
screen with every player's knockouts, falls, self-knockouts and damage dealt, and the choices
Rematch, Change fighters and Main menu.

## Defence

All defence lies on one extra key per player, the shield key. The starting values are in
`scripts/sim/fighter_defense.gd` (60 ticks per second).

| Move | Keys | What it does |
|---|---|---|
| Shield | Hold the shield key on the ground | A bubble blocks every hit. It shrinks while held and from blocked damage, regrows when let go. Blocked hits push the shield back and hold it for a moment. Letting go lowers it in 6 ticks; a jump, dodge or grab comes at once |
| Parry | Press the shield key just before a hit (5 ticks) | No shield damage; the attacker stands frozen for 12 ticks, a free punish |
| Shield break | The shield runs empty | The fighter stands dizzy for 2 seconds, then gets part of its shield back |
| Roll | In the shield, left or right | Rolls 150 px that way, invulnerable in the middle, and faces back the way it came. It stops at the edge |
| Spot dodge | In the shield, down | Invulnerable in place for a moment |
| Air dodge | The shield key in the air, with or without a direction | Dashes 130 px the way held (or stays in place), invulnerable for most of it; once per time in the air, back on landing, a ledge grab, a wall jump or being hit. Landing during it slides on with a short lag (a waveland) |
| Grab | Attack while shielding | Grabs a fighter in front, also one behind a shield; it does not catch a dodging fighter. The direction held throws: forward, back, up, or down (a low pop-up that starts combos at low damage). Without a direction it throws forward after a third of a second |

**No exact timing needed.** A direction pressed up to 3 ticks before the shield key rolls or
dodges at once, so the two keys need not come in the same tick. A direction held for a while
(walking) gives a plain shield. A press of the shield key that cannot act yet waits like attack
and jump (8 ticks). Dodges in a row protect less long each (3 ticks less per dodge within
1.5 seconds), so rolling again and again is no safe escape.

## Ways out of combos

A launched fighter is never helpless:

- **Directional influence (DI).** The direction held at the end of the hit pause bends the launch
  by up to 15 degrees: across the launch the most. Holding toward the arena and up survives
  longer; holding away gets out of combos.
- **Drift.** In hitstun the fighter steers a little (up to 3 pixels per tick).
- **Early way out.** After 80 % of the hitstun, a double jump or an air dodge ends it.
- **Tech.** The shield key pressed just before (10 ticks) hitting the ground in hitstun is a
  tech: no bounce, the fighter gets up invulnerable, rolling with a direction held. Against a
  wall the fighter stops on it and can wall jump at once. A press opens no new tech window for
  half a second, so pressing all the time does not work. Without a tech a fast fighter bounces.
- **Combo guard.** From the third hit in a row taken in hitstun, each hit gives 15 % less hitstun
  (at least 40 %). Normal play does not feel it; it cuts endless combos.
- **Stale moves.** The same attack used again and again does less: each copy among the
  attacker's last 8 hits takes 7 % off its damage (at most 40 %) and a third of that off its
  knockback.

The test `tests/test_combos.gd` searches the longest true combos (the target never got free in
between) from several damages: against a defender that uses these ways out, no combo is longer
than 4 hits or takes a life from below 80 %.

## Computer opponents

Computer players press the same keys a player would and see the others as they were a reaction
time ago. Three levels; harder levels decide better and react faster, they get no extra strength:

| | Easy | Medium | Hard |
|---|---|---|---|
| Reaction | 28 ticks | 16 ticks | 9 ticks |
| Defence | Shields a fifth of the attacks it sees | Shields half, dodges a third | Shields, dodges, grabs shields |
| Launched | No DI, no tech | DI and tech half the time | DI and tech most of the time, jumps out of hitstun early |
| Other | Backs off after two hits in a row and after being hit, leaves fighters on a ledge or just respawned alone, keeps far from the edge | | Prefers strong attacks against a damaged target |

All levels recover to the stage (double jump, up air lift, wall jumps, hard also the air dodge)
and never walk off the edge by themselves. Their chances come from the tick, so the same match
plays out the same way (`scripts/sim/cpu_player.gd`).

## Menus

- **Main menu:** Play, Controls (a page of all keys and moves), Quit.
- **Choose your fighters:** one screen. Each keyboard layout and each gamepad joins with its
  attack key or button and picks a fighter with left and right; attack again is ready, the shield
  key or B steps back. Ready players change the match below with the directions: the arena
  (random by default, not the last one), lives (1 to 5), the number of computer players and
  their level. Attack starts the match once everyone who joined is ready and there are two
  fighters at least. The screen remembers the last setup.
- **Pause:** Esc or Start; only the player who paused works the menu: Resume, Restart, Change
  fighters, Main menu.
- **Results:** after the match (section "Combat", "Match end"); Rematch is one press.

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

Two players share one keyboard with six keys each: player 1 uses W A S D, Space and the left
Shift or Ctrl, player 2 the arrow keys, Enter and the right Shift or Ctrl. Players 3 and 4 use
gamepads; a gamepad can also take a keyboard player's place. Every device has the same actions,
so no player has more moves than another.

| Action | Keyboard, player 1 | Keyboard, player 2 | Gamepad |
|---|---|---|---|
| Move left and right | A, D | Left, Right | Left stick or D-pad; the stick tilted all the way runs |
| Jump, double jump | W | Up | A or Y; stick or D-pad up too |
| Fast fall, drop through | S | Down | Stick or D-pad down |
| Attack | Space | Enter (both Enter keys) | X or B |
| Shield, dodges, grab | Left Shift or left Ctrl | Right Shift or right Ctrl | Shoulder buttons and triggers |
| Pause | Esc | Esc | Start |

Ctrl is there because Windows offers its Sticky Keys after Shift is pressed five times in a row.
A gamepad's jump button jumps without counting as up for an attack, so jump and attack give an
air attack, not the up air.

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

Players join by pressing their attack key or button (section "Menus"). In menus, attack or A
chooses and the shield key or B goes back. Remapping keys comes later.

**Testing aids:** F1 shows the fighters' state, their hurtboxes and hitboxes and the blast zone,
F2 opens the tuning panel of the first player's fighter, F5 restarts the match.

## Game modes

- **Versus (M2, M3):** 2 to 4 players and computer opponents, everyone against everyone, lives.
- **Later:** teams, time mode, online versus.

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
scenes/      the main scene and the match scene
scripts/sim/ simulation: match state, fighters, collision, hits, defence, computer players
scripts/view/ nodes that draw the state, effects, camera, sounds, input devices
fighters/    fighter data and the roster
arenas/      arena layouts and the arena list
ui/          the main node and the menus
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
| **M3 Match flow** | Main menu, joining, fighter and arena select, 4 players with gamepads, computer opponents, pause, rematch, shield and dodge, ways out of combos | A full evening of local matches works without restarts |
| **M4 Content and feel** | Three fighters, two to three arenas, effects, sounds, music | The game looks and sounds like itself |
| **M5 Own twist** | A twist of our own that sets the game apart from others in its genre, found in a brainstorming session first | The twist is in the game and changes how a match plays |
| **M6 Online** | Rollback netcode, lobby, play over the internet | Two players on different machines play a match |

## Open decisions

1. **Art style:** flat vector shapes drawn in code for now (decided 2026-11-21); pixel art is
   planned later, so the shapes stay simple.
2. **Fighters:** how many at first, their concepts and names.
3. **Items:** none, or items that drop into the arena.
4. **Grab, throw and special moves:** whether they come and on which keys. Decided on 2026-11-21:
   one extra key per player for shield and dodge, no special-move key for now.
5. **Sound:** a few simple sounds generated in code for now (decided 2026-11-21); free sound packs
   may replace them later.
6. **Teams:** team mode, and whether teammates can hit each other.
7. **Online:** peer-to-peer or a relay server; an existing Godot rollback addon or our own.
8. **Platforms:** Windows first; web, Linux or a store release later.
9. **Name:** the final title of the game.
10. **License:** none chosen yet; without one, the public code stays all rights reserved.
