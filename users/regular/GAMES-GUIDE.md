# Games Collection Guide for Kids (Ages 8 and Under)

This is a curated collection of **free, open-source, ad-free** games from nixpkgs that are safe and appropriate for children. All games are installable on macOS and run natively without requiring internet access or creating accounts.

## Quick Start

To add ALL games to the girls profile:

```nix
# In hosts/sevastopol/default.nix or girls-darwin.nix
imports = [
  ../../users/regular/girls-games-collection.nix
];
```

Or add individual games by copying specific packages from the collection file.

---

## 🎓 Educational Games (Highest Priority)

### GCompris ⭐ ESSENTIAL

**Ages:** 2-10 | **Activities:** 180+

The premier educational software suite with activities covering:

- Math (counting, arithmetic, algebra basics)
- Reading and literacy
- Science experiments
- Geography and history
- Memory and logic puzzles
- Computer skills (keyboard, mouse)

**Why it's great:** Comprehensive, professionally designed, used in schools worldwide. Your kids can learn while having fun for hours. Has difficulty levels for different ages.

**Best for:** All ages 2-10, varied skill development

---

### TuxPaint ⭐ HIGHLY RECOMMENDED

**Ages:** 3-12 | **Type:** Digital Art

Open-ended creative drawing program with:

- Simple, intuitive interface
- Magic effects and stamps
- No complicated tools to confuse kids
- Sound effects for engagement
- Save and print artwork

**Why it's great:** Encourages creativity without the complexity of professional art software. Kids can create without getting frustrated.

**Best for:** Artistic expression, fine motor skills, creativity

---

### TuxType

**Ages:** 5-10 | **Type:** Typing Tutor

Learn touch typing through gameplay with Tux the penguin:

- Progressive difficulty
- Fun animations and sounds
- Tracks progress
- Essential computer skill

**Why it's great:** Makes learning to type enjoyable instead of boring. Critical skill for school and life.

**Best for:** Building essential typing skills

---

### KTurtle

**Ages:** 8+ | **Type:** Programming Introduction

Visual programming using Logo/Turtle graphics:

- Draw shapes by commanding a turtle
- Learn basic programming concepts
- Immediate visual feedback
- Step-by-step tutorials included

**Why it's great:** First step into programming. Kids see their code create art immediately.

**Best for:** Ages 8+ interested in how computers work

---

## 🧩 Logic & Puzzle Games

### Atomix / Katomic

**Ages:** 7-10 | **Type:** Chemistry Puzzle

Build molecules by moving atoms into correct positions.

**Educational value:** Teaches molecular structure, spatial reasoning, chemistry basics

**Difficulty:** Medium - requires planning ahead

---

### Palapeli

**Ages:** 4-10 | **Type:** Jigsaw Puzzles

Digital jigsaw puzzles:

- Can load custom photos
- Adjustable difficulty (piece count)
- Relaxing gameplay

**Best for:** Quiet time, spatial skills, patience

---

### Quadrapassel (Tetris)

**Ages:** 6+ | **Type:** Falling Blocks

Classic Tetris clone - rotate and place falling blocks.

**Skills:** Spatial reasoning, quick decision making, pattern recognition

**Note:** Can be challenging but good for improving spatial skills

---

### Swell Foop

**Ages:** 4-8 | **Type:** Match Colors

Click groups of matching colored blocks to clear the board.

**Skills:** Color recognition, pattern matching, planning

**Perfect for:** Younger kids, very simple mechanics

---

### Lightsoff

**Ages:** 6-10 | **Type:** Logic Puzzle

"Lights Out" puzzle - toggle lights to turn them all off.

**Skills:** Logical thinking, problem solving, pattern recognition

**Difficulty:** Starts easy, becomes challenging

---

### Hex-a-Hop

**Ages:** 6-10 | **Type:** Strategy Puzzle

Jump on hexagonal tiles to destroy them, reach the goal.

**Skills:** Planning, strategic thinking, spatial awareness

**Difficulty:** Progressive - starts simple

---

### Pingus

**Ages:** 7+ | **Type:** Lemmings-Style Puzzle

Guide penguins to safety by giving them commands.

**Skills:** Problem solving, timing, multi-tasking

**Note:** Non-violent, cute graphics

---

### KDiamond / Gweled

**Ages:** 5+ | **Type:** Match-3

Match three colored gems (like Bejeweled).

**Skills:** Pattern recognition, quick scanning

**Perfect for:** Casual puzzle fun

---

### Frozen Bubble

**Ages:** 5+ | **Type:** Bubble Shooter

Shoot colored bubbles to match groups and clear them.

**Skills:** Aiming, color matching, strategic planning

**Note:** Can be addictive in a fun way

---

### Gnonograms

**Ages:** 8+ | **Type:** Logic Puzzle

Nonogram/Picross puzzles - use number clues to reveal pictures.

**Skills:** Logic, deduction, concentration

**Difficulty:** Requires patience and logical thinking

---

### KBounce

**Ages:** 6+ | **Type:** Arcade Puzzle

Claim space while avoiding bouncing balls.

**Skills:** Timing, spatial awareness, quick reflexes

---

### KGoldrunner

**Ages:** 7+ | **Type:** Action Puzzle

Collect gold while avoiding enemies in a platformer maze.

**Skills:** Strategy, quick thinking, problem solving

**Difficulty:** Can be challenging but rewarding

---

## 🎨 Creative & Building Games

### Luanti (Minetest) ⭐ HIGHLY RECOMMENDED

**Ages:** 6+ | **Type:** Voxel Building (Minecraft-like)

Open-source alternative to Minecraft:

- Creative building in 3D blocks
- Exploration and survival modes
- 100% free, no microtransactions
- Safe single-player mode
- Optional: Add mods for more content

**Why it's great:** Encourages creativity, spatial thinking, and imagination. Can play safely offline without any purchases or ads.

**Best for:** Creative building, exploration, can play for hours

**Parent tip:** Start in creative mode (unlimited blocks, can't die) for younger kids

---

### KTuberling

**Ages:** 3-8 | **Type:** Digital Potato Head

Drag and drop facial features and accessories to create funny characters.

**Skills:** Creativity, fine motor control (using mouse)

**Perfect for:** Younger children, simple and fun

---

## 🏃 Action & Arcade Games (Age Appropriate)

### SuperTux ⭐ HIGHLY RECOMMENDED

**Ages:** 6+ | **Type:** 2D Platformer

Like Super Mario Bros but with Tux the penguin:

- Run, jump, collect items
- Multiple worlds and levels
- Non-violent (enemies are ice blocks)
- Progressive difficulty

**Why it's great:** Classic gaming fun without violence. Good hand-eye coordination practice.

**Best for:** Kids who like platformer games

---

### Extreme Tux Racer

**Ages:** 6+ | **Type:** Downhill Racing

Race Tux down snowy mountains:

- Fast-paced but simple controls
- Collect fish for points
- Beautiful 3D graphics
- Non-violent

**Best for:** Kids who like speed and racing

---

### Neverball

**Ages:** 7+ | **Type:** Tilt Maze

Guide a ball through 3D obstacle courses by tilting the floor.

**Skills:** Physics understanding, careful control, hand-eye coordination

**Difficulty:** Starts easy, becomes quite challenging

---

### Armagetronad

**Ages:** 8+ | **Type:** Tron Light Cycles

Ride a light cycle and create walls, avoid crashing.

**Skills:** Quick reflexes, spatial awareness, strategy

**Note:** Fast-paced, can play vs AI bots

**Difficulty:** Can be challenging

---

## 🚂 Simulation & Strategy Games

### OpenTTD ⭐ HIGHLY RECOMMENDED

**Ages:** 8+ | **Type:** Transport Tycoon Simulation

Build transportation networks with trains, buses, planes, and ships:

- Economic strategy and city building
- Detailed simulation
- Sandbox mode with unlimited money
- Can play solo at your own pace

**Why it's great:** Teaches economics, planning, and resource management. Very deep game that can be played for hundreds of hours.

**Best for:** Ages 8+ who like building and strategy

**Parent tip:** Start in sandbox mode (no money worries) to learn the game

---

### Ri-li

**Ages:** 3-8 | **Type:** Children's Train Game

Simple toy train game for younger kids:

- Watch trains move
- Simple controls
- Non-competitive
- Relaxing

**Perfect for:** Younger kids who like trains

---

## 🎯 Relaxing & Low-Stress Games

### Rocksndiamonds

**Ages:** 6+ | **Type:** Boulder Dash Puzzle

Collect diamonds while avoiding falling rocks:

- Hundreds of levels
- Various difficulty settings
- Strategic puzzle solving

---

### Enigma

**Ages:** 7+ | **Type:** Marble Puzzle

Guide marbles to goals using switches, portals, and physics:

- Beautiful graphics
- Challenging but fair puzzles
- Hundreds of levels

**Skills:** Physics understanding, problem solving, patience

---

## 📊 Age-Appropriate Recommendations

### Ages 3-5 (Preschool)

Focus on simple, colorful, exploratory games:

- **GCompris** (start with easier activities)
- **TuxPaint**
- **KTuberling**
- **Swell Foop**
- **Ri-li**

### Ages 6-7 (Early Elementary)

Add puzzle and coordination games:

- All of the above
- **SuperTux**
- **Quadrapassel**
- **Extreme Tux Racer**
- **Hex-a-Hop**
- **Palapeli**
- **Luanti** (creative mode)

### Ages 8+ (Upper Elementary)

Can handle more complex strategy:

- All of the above
- **OpenTTD**
- **KTurtle** (programming)
- **Gnonograms**
- **Armagetronad**
- **Luanti** (survival mode)
- **Pingus**
- **KGoldrunner**

---

## 🎮 Parental Tips

### Screen Time Management

Even with great games, limit screen time:

- Set daily time limits (already configured in parental controls)
- Encourage breaks every 30-45 minutes
- Balance with physical activity

### Educational Value

Maximize learning opportunities:

- Play **GCompris** for structured learning
- Use **TuxType** to build typing skills early
- Encourage **Luanti** for creativity
- **OpenTTD** teaches real economics concepts

### Multiplayer Considerations

Most of these games are single-player or local multiplayer only:

- **Luanti** has multiplayer but can disable it
- **Armagetronad** has online play (may want to restrict)
- No voice chat or stranger interaction in any game

### Technical Requirements

All games should run well on your iMac (2013, Intel i5, 32GB RAM):

- Most are 2D and very lightweight
- 3D games (Luanti, Neverball, OpenTTD) should run smoothly
- No internet required to play

### Storage Space

- Minimal space needed (most games under 100MB each)
- **Luanti** and **OpenTTD** can grow with saved games
- Monitor disk space if kids create many saves

---

## 🔧 Customization

### Selective Installation

Instead of installing all games, pick favorites:

```nix
home-manager.users.girls = { pkgs, ... }: {
  home.packages = with pkgs; [
    # Educational essentials
    gcompris
    tuxpaint
    tuxtype

    # Fun games
    supertux
    luanti
    frozen-bubble

    # Creative
    ktuberling
  ];
};
```

### Adding More Games

Search nixpkgs for additional games:

```bash
nix search nixpkgs game
nix search nixpkgs puzzle
nix search nixpkgs educational
```

### Game Launchers

Consider creating desktop shortcuts or a game launcher menu for easy access. Most games will appear in the Applications menu automatically.

---

## 🛡️ Safety Notes

### Why These Games Are Safe

✅ **No ads** - Open source, no advertising
✅ **No in-app purchases** - Completely free forever
✅ **No online chat** - No stranger interaction
✅ **No accounts required** - No sign-ups or personal info
✅ **Offline play** - Work without internet
✅ **No tracking** - No analytics or data collection
✅ **Age appropriate** - Non-violent, suitable content

### Games to Monitor

A few games have optional online features:

- **Luanti (Minetest)** - Has multiplayer servers, can be disabled
- **Armagetronad** - Has online play, can restrict to AI only
- **OpenTTD** - Has multiplayer, can play offline only

Consider using the parental controls to restrict network access if concerned.

---

## 📚 Additional Resources

### Game Controls

Most games use simple keyboard/mouse controls:

- Arrow keys or WASD for movement
- Mouse for clicking/dragging
- Escape to pause/quit

### Getting Help

Games usually have:

- Built-in tutorials (especially GCompris, OpenTTD)
- Help menus (press F1 or check menu bar)
- Configuration options for difficulty

### Community

These are open-source games with helpful communities:

- Most have wikis and documentation online
- Safe to search for gameplay tips and guides
- No toxic gaming communities (unlike commercial games)

---

## 🎯 Quick Reference Chart

| Game          | Age  | Type        | Difficulty | Educational Value | Time to Learn |
| ------------- | ---- | ----------- | ---------- | ----------------- | ------------- |
| GCompris      | 2-10 | Educational | Varied     | ⭐⭐⭐⭐⭐        | 5 min         |
| TuxPaint      | 3-12 | Creative    | Easy       | ⭐⭐⭐⭐          | 2 min         |
| TuxType       | 5-10 | Typing      | Easy       | ⭐⭐⭐⭐⭐        | 5 min         |
| SuperTux      | 6+   | Platformer  | Medium     | ⭐⭐              | 10 min        |
| Luanti        | 6+   | Building    | Easy/Med   | ⭐⭐⭐⭐          | 20 min        |
| OpenTTD       | 8+   | Strategy    | Hard       | ⭐⭐⭐⭐          | 30 min        |
| Frozen Bubble | 5+   | Puzzle      | Easy       | ⭐⭐              | 2 min         |
| Quadrapassel  | 6+   | Puzzle      | Medium     | ⭐⭐⭐            | 5 min         |
| Pingus        | 7+   | Puzzle      | Medium     | ⭐⭐⭐            | 10 min        |
| KTuberling    | 3-8  | Creative    | Easy       | ⭐⭐              | 1 min         |

---

## Support & Feedback

If a game doesn't work or isn't appropriate:

1. Remove it from the package list in `girls-games-collection.nix`
2. Rebuild: `darwin-rebuild switch --flake .`
3. File an issue if the game has technical problems

Most games are mature, stable projects that have been around for 10+ years and are very reliable.

---

**Have fun gaming!** 🎮
