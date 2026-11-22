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
  launch_speed = (base_knockback + knockback_growth * (damage_after_hit / 100) * (100 / weight))
                 * knockback_scale
  ```

  `base_knockback`, `knockback_growth` and the launch angle belong to each attack; `weight` to each
  fighter (100 is average); `knockback_scale` (starting value: 1.35) scales every launch. The
  launch speed is in pixels per tick.
- **Hitstun.** After a launch the target cannot act for a number of ticks that grows with the
  launch speed (starting value: `launch_speed * 1.5` ticks); a weak hit (launch slower than 9)
  stuns at least 12 ticks plus one per point of damage, so light hits can start combos at low
  damage. In hitstun the target falls with 60 % of the gravity and the launch fades slowly, so
  strong hits carry it far. A target that hits the
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
| Special move | The special key, one per fighter; the direction aims or steers it (section "Special moves") | M4.5 |
| Strong attacks | No key for them for now (Open decisions 4) | open |

The starting values of the test fighter's attacks (ticks, hitbox, damage, knockback and angle)
are in `scripts/sim/attacks.gd`; each fighter in `fighters/` changes them. Hard computer players
knock each other out at about 135 % on average, off the top, the sides and the bottom. The
uppercut comes out at once and launches up; it is a combo starter more than a finisher.

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
point of damage, 6 ticks more for a hit that launches at 25 pixels per tick or faster) in which
the target shakes, a hit effect, light screen shake and a trail behind the target on strong hits,
a burst on a knockout, sparks on a blocked hit and a ring on a parry. Dust rises where fighters
land, jump and turn. A damage of 100 % or more pulses in the HUD. Keys pressed during the hit
pause count right after it.

**Match end.** When only one fighter has lives left, the winner is shown, then the results
screen with every player's knockouts, falls, self-knockouts and damage dealt, and the choices
Rematch, Change fighters and Main menu.

## Special moves

Every fighter has one special move of its own on the special key (E or Q, Backspace or Numpad 0,
gamepad B). It is built on a kind of move players of the genre love (a shot, a dash, a spin),
in our own form. The direction held only aims or steers it; it never picks another move. Like
attack and jump, a press that cannot act yet waits 8 ticks; the special comes out of the shield at
once; on a ledge and in hitstun it does nothing. No cooldowns: each special is limited by how it
works (one shot at a time, once per time in the air) and by its recovery. The fighter select
screen shows each fighter's special and the player's own key for it.

| Fighter | Special | What it does | Limits and counterplay |
|---|---|---|---|
| Kade | Spark | After 10 ticks throws an orb (r 18 px) that flies 9 px per tick for 50 ticks (about 450 px): 5 %, a light launch. A fresh up or down aims it 45 degrees (down in the air only). Recovery 18 ticks on the ground, 14 in the air; no help to recover | One orb at a time: the key does nothing while it flies. It vanishes on a hit, a shield, a wall, another fighter's shot, or an attack that meets it. Slower than a run, so it can be jumped, dodged or outrun. A parry sends it back as the parrier's own |
| Pip | Swoop | Stops for 6 ticks (feathers flare), then dashes 12 ticks at 18 px per tick (216 px) the way held, in eight directions (else forward): 6 %, launches forward and up. Brings Pip home | Once per time in the air (back on landing, a ledge, a wall jump, a hit). It stops at a fighter, a shield or a wall. Recovery 28 ticks on the ground, 20 in the air (6 fewer on a hit); landing in it, 12 ticks. Pip can be hit all the way |
| Brum | Whirl | After 6 ticks spins for 18 ticks with fists on both sides: three light hits (3 % each, they keep the target in the spin), then one that launches (6 %). On the ground Brum creeps 3 px per tick; in the air the spin carries him 7 px per tick sideways and 6 px per tick up (about 126 px across, 108 up) | Once per time in the air. Recovery 34 ticks on the ground (a whiff is a free punish), 20 in the air, 14 when landing in it. A shield and a grab beat it |

Shots are part of the match state, like the fighters, so a match with shots in flight still
replays the same. The combo search (section "Ways out of combos") uses the specials too.

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
- **Combo guard.** From the fourth hit in a row taken in hitstun, each hit gives 15 % less
  hitstun (at least 40 %). Normal play does not feel it; it cuts endless combos.
- **Stale moves.** The same attack used again and again does less: each copy among the
  attacker's last 8 hits takes 7 % off its damage (at most 40 %) and a third of that off its
  knockback.

The test `tests/test_combos.gd` searches the longest true combos (the target never got free in
between) from several damages: against a defender that uses these ways out, no combo is longer
than 4 hits or takes a life from below 80 %. Since M4.5 it searches with every fighter and its
special too: against a defender that gets out, the longest true combos have 2 to 3 hits (for
example Pip's down throw, Swoop, forward air from 0 %), 3 hits against one that does nothing,
and none takes a life.

## Computer opponents

Computer players press the same keys a player would and see the others as they were a reaction
time ago. Three levels; harder levels decide better and react faster, they get no extra strength:

| | Easy | Medium | Hard |
|---|---|---|---|
| Reaction | 28 ticks | 16 ticks | 9 ticks |
| Defence | Shields a fifth of the attacks it sees | Shields half, dodges a third | Shields, dodges, grabs shields |
| Launched | No DI, no tech | DI and tech half the time | DI and tech most of the time, jumps out of hitstun early |
| Other | Backs off after two hits in a row and after being hit, leaves fighters on a ledge or just respawned alone, keeps far from the edge | | Prefers strong attacks against a damaged target |

All levels recover to the stage (double jump, up air lift, wall jumps, the special when it moves
the fighter, hard also the air dodge) and never walk off the edge by themselves. They use their
special when it fits (a Spark from a distance, a Swoop into a target a dash away, a Whirl up
close), now and then by level, double jump after a target on a high platform, drop through a thin
platform to a target below, and (medium and hard) walk out of a vent that is about to burst. Their chances come from the tick, so the same match
plays out the same way (`scripts/sim/cpu_player.gd`).

## Menus

- **Main menu:** Play, Controls (a page of all keys and moves), Quit.
- **Choose your fighters:** four panels side by side, one per player. Each keyboard layout and
  each gamepad joins with its attack key or button and picks a fighter with left and right (Kade,
  Pip, Brum or Random, rolled anew at every match start); attack again is ready, the shield key or
  B steps back. Several players may pick the same fighter. Each panel shows the fighter as it
  looks in the match on a ring in the player's color, its name, role and difficulty (one to three
  stars), its stat sheet (section "Fighters"), one line about it, and its special: name, the
  player's own key and what it does. Computer players fill the next empty panels with the
  fighters no player picked first. Ready players change the rules at the bottom with the
  directions: lives (1 to 5), computer players and their level, hazards on or off. Attack goes on
  to the arena once everyone who joined is ready and there are two fighters at least. The screen
  remembers the last setup.
- **Choose the arena:** a big live preview of the arena under the cursor (moving platforms move,
  vents puff and burst) with its name, size, platforms and what makes it different, and a grid
  of live tiles: the seven arenas, Training (the test arena) and Random (any arena but Training,
  not the last one played; the default). Every player who joined moves the one cursor; attack
  starts the match, the shield key or B goes back to the fighters with the picks kept.
- **Pause:** Esc or Start; only the player who paused works the menu: Resume, Restart, Change
  fighters, Main menu.
- **Results:** after the match (section "Combat", "Match end"); Rematch is one press and keeps the
  arena; Change fighters goes through both select screens again.

## Fighters

Three original fighters (M4), each with the full move set, one trait and one special move of its
own (M4.5). Every fighter is a file in `fighters/` that changes the test fighter's values and
moves; `fighters/roster.gd` lists them. The plain test fighter stays for the tests.

| | Kade | Pip | Brum |
|---|---|---|---|
| Idea | The all-rounder: no weakness, no trick | Small, quick, floaty | Heavy hitter, slow |
| Role, difficulty | All-rounder, 1 star | Rushdown, 3 stars | Heavy hitter, 2 stars |
| Look | Round head, green body, a scarf trailing behind | Round blue body, pointed beak, flapping wings | Wide red-brown body, square head, big gold fists |
| Body | 60 x 100 | 50 x 84 | 74 x 116 |
| Weight | 96 | 98 | 110 |
| Run | 10 | 12.5 | 8 |
| Jumps in the air | 1 | 2 | 1 |
| Up-air lift | 13 px/tick, 10 ticks | 11 px/tick, 8 ticks | 10 px/tick, 8 ticks |
| Trait | The strongest forward air, the longest lift | A neutral air that hits three times | Its side attack shrugs off hits under 12 % while it winds up (armor); grabs and strong hits break through |
| Special | Spark: an orb, one at a time | Swoop: a dash in eight directions | Whirl: a four-hit spin |

**Stat sheet.** Four stats from 1 to 5 pips, each worked out from the fighter's values by a fixed
rule (`fighters/stat_sheet.gd`), so the sheet follows every change and a new fighter fits in:

| Stat | Rule | Kade | Pip | Brum |
|---|---|---|---|---|
| Power | Average damage of side attack, forward air and uppercut: 6 % is 1 pip, 12 % is 5 | 3 | 2 | 5 |
| Speed | Run speed: 7.5 is 1 pip, 12.5 is 5 | 3 | 5 | 1 |
| Weight | Weight: 85 is 1 pip, 110 is 5 | 3 | 3 | 5 |
| Recovery | 1, plus 1 per jump in the air, 1 for a lift of 130 px or more, 1 for an air speed of 6 or more, 1 for an air special that moves the fighter | 4 | 5 | 3 |

Balance with the specials (hard computer against hard computer, every pair 8 times on the test
arena, Terraces, Ferry, Flatiron, Cistern and Kettle, 96 matches each fighter): Kade wins 49, Pip
56, Brum 39; knockouts at about 135 to 165 % (Brum the latest). One against one lasts 2.5 to 4
minutes, four hard computer players 2 to 3.5 minutes. Kade is strongest on Flatiron and Ferry,
Pip on Terraces and Cistern, Brum on Kettle. Computer players are only a guide; people playing
decide.

## Arenas

Seven arenas and the test arena for training (`arenas/`, listed in `arenas/arena_list.gd`). Every
arena has ledges and room for four fighters; moving platforms and hazards follow from the tick
alone, so a match replays the same.

| Arena | Kind | Layout | Feel |
|---|---|---|---|
| Pebble | Small | An island 700 wide, one thin platform | Short distances, early knockouts: whoever guards the edges wins |
| Terraces | Large, platforms | A stage 1520 wide, three thin platforms on two levels | Long fights, play up and down |
| Ferry | Medium, moving | An island 1100 wide, two thin platforms and a third that sails from side to side (12 seconds there and back) and carries whoever stands on it | The best spot keeps moving |
| Flatiron | Flat | One island 1300 wide, nothing else | Nowhere to hide: pure spacing; the place to learn the game |
| Cistern | Walls | A floor 1140 wide between two pillars 80 wide that stand 260 px higher; the ledges are on the pillars' outer corners, their inner faces are walls to jump off; one thin platform | A stone bowl: wall jumps, ambushes from the pillar tops, close fights |
| Windlass | Medium, moving | An island 1000 wide, a thin platform on each side and a lift in the middle that rises and sinks 150 px each way (14 seconds) | Ride it high to threaten, drop low to hold the floor |
| Kettle | Large, hazard | A stage 1400 wide, three thin platforms and two vents in the floor | A party stove for four: the floor erupts on a clock you can read |
| Test arena | Training | The M1 arena with walls high enough to jump off | Training; random picks leave it out |

**Kettle's vents** are the only hazard. Each vent idles, then glows and puffs for 1.5 seconds,
then bursts for half a second: a column of steam 160 wide up to 400 px high that throws everyone
in it straight up once (6 %, a fixed launch that never knocks anyone out by itself, no credit to
anyone). The two vents take turns (8 seconds per round). A shield takes the burst. The rule
"Hazards" (fighter select, on by default) turns them off: then the vents stay cold.

## Camera

One shared camera that keeps all fighters in view, zooms out as they spread and stops at the
edges of the blast zones.

## Controls

Two players share one keyboard with seven keys each: player 1 uses W A S D, Space, E and the
left Shift or Ctrl, player 2 the arrow keys, Enter, Backspace and the right Shift or Ctrl. Players
3 and 4 use gamepads; a gamepad can also take a keyboard player's place. Every device has the same
actions, so no player has more moves than another.

| Action | Keyboard, player 1 | Keyboard, player 2 | Gamepad |
|---|---|---|---|
| Move left and right | A, D | Left, Right | Left stick or D-pad; the stick tilted all the way runs |
| Jump, double jump | W | Up | A or Y; stick or D-pad up too |
| Fast fall, drop through | S | Down | Stick or D-pad down |
| Attack | Space | Enter (both Enter keys) | X |
| Special move | E (or Q) | Backspace (or Numpad 0) | B |
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
chooses and the shield key or B goes back (B is the special only in a match). Remapping keys
comes later. Some keyboards cannot read many keys held at once ("ghosting"); with two players on
one keyboard, up to five keys each can be held, so a cheap keyboard may drop a key now and then.

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
  current move and its tick, shots in flight) lives in plain GDScript classes. Scene nodes only
  draw that state and play effects and sounds.
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
| **M4.5 More content** | A special move per fighter, four more arenas (one with a hazard), an arena select with live previews, stat sheets on the fighter select | Every fighter plays differently and every arena changes how a match plays |
| **M5 Own twist** | A twist of our own that sets the game apart from others in its genre, found in a brainstorming session first | The twist is in the game and changes how a match plays |
| **M6 Online** | Rollback netcode, lobby, play over the internet | Two players on different machines play a match |

## Open decisions

1. **Art style:** flat vector shapes drawn in code for now (decided 2026-11-21); pixel art is
   planned later, so the shapes stay simple.
2. **Fighters:** how many at first, their concepts and names.
3. **Items:** none, or items that drop into the arena.
4. **Grab, throw and special moves:** whether they come and on which keys. Decided on 2026-11-21:
   one extra key per player for shield and dodge, no special-move key for now. Later the same day
   the owner asked for one special move per fighter: it lies on a key of its own (section
   "Special moves"); to be confirmed by the owner. Strong (charged) attacks stay open.
5. **Sound:** a few simple sounds generated in code for now (decided 2026-11-21); free sound packs
   may replace them later.
6. **Teams:** team mode, and whether teammates can hit each other.
7. **Online:** peer-to-peer or a relay server; an existing Godot rollback addon or our own.
8. **Platforms:** Windows first; web, Linux or a store release later.
9. **Name:** the final title of the game.
10. **License:** none chosen yet; without one, the public code stays all rights reserved.
