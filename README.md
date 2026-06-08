# 🟣 Purple Weasle

> *A third-person survival-horror game. You are the Purple Weasle, lost in a corrupted wood. Gather the scattered relics to unlock the way out — while its warped inhabitants hunt you through the dark.*

---

## 🎮 Gameplay

Explore a dark, fog-bound arena in third person. Glowing **relics** are hidden throughout — collect all of them to open the exit. But the wood is not empty: **warped woodland creatures** patrol the halls, and if one spots you it will give chase.

- 🦌 **The Deer** — a tall, skull-faced thing that patrols set routes
- 🐇 **The Rabbit** — squat, fast and vicious, with too many teeth

When a creature spots you it freezes, lets out a growl, then hunts. Your **heartbeat** pounds while you're being chased. Sprint to escape — but watch your **stamina**.

### Controls

| Key | Action |
|-----|--------|
| `W A S D` | Move (relative to camera) |
| `Mouse` | Look / orbit camera |
| `Left Ctrl` | Sprint (drains stamina) |
| `Esc` | Release / capture mouse |

### Objective

1. Find and collect **all relics** (counter shown top-right)
2. The exit pillar glows **red** while sealed, **green** once all relics are gathered
3. Reach the open exit to escape

---

## 🏗️ Project Structure

```
purple-weasle/
├── project.godot               # Godot 4.6, Forward+ renderer, autoloads
├── scenes/
│   ├── level_01_3d.tscn         # The Corrupted Wood + WorldEnvironment + HUD
│   ├── player_3d.tscn           # Third-person weasle + spring-arm camera
│   ├── creature.tscn            # Billboard creature (deer / rabbit)
│   ├── relic.tscn               # Floating collectible
│   ├── main_menu.tscn           # (2D UI)
│   └── game_over.tscn           # (2D UI)
├── scripts/
│   ├── player_3d.gd             # Movement, camera, stamina, footsteps
│   ├── creature.gd              # Patrol → alert → chase → attack AI
│   ├── relic.gd                 # Bob/spin pickup, unlocks exit
│   ├── level_01_3d.gd           # Runtime map builder + exit gating + HUD
│   ├── audio_manager.gd         # Autoload: ambient, heartbeat, growls, SFX
│   ├── game_manager.gd          # Autoload: level flow, relic tracking
│   ├── torch_flicker.gd         # Flickering torch light
│   └── … (legacy 2D scripts kept for reference)
└── assets/
    ├── sprites/                 # Creature billboards + wall/floor textures
    └── audio/                   # Procedurally generated WAVs
```

---

## 🔊 Audio

All sound is **procedurally generated** (see the generation scripts in commit history) — no external assets:

| Sound | When |
|-------|------|
| Ambient drone | Always (looping dread) |
| Heartbeat | While any creature is hunting you |
| Footsteps | While moving (faster when sprinting) |
| Growl | When a creature first spots you (positional) |
| Relic chime | On pickup |
| Death sting | When caught |

---

## 🛠️ Getting Started

1. Download [Godot 4.6](https://godotengine.org/download/)
2. Clone this repo:
   ```bash
   git clone https://github.com/iamsidge/purple-weasle.git
   ```
3. Open `project.godot` in the Godot editor (let it import assets on first open)
4. Hit **Play** (F5)

---

## 📋 Roadmap

- [x] 3D first/third-person conversion
- [x] Warped creature billboards + AI
- [x] Atmosphere — fog, glow, flickering torches
- [x] Procedural audio (ambient, heartbeat, growls, SFX)
- [x] Stamina system
- [x] Relic objective + gated exit
- [ ] Animated creature sprites (multi-frame)
- [ ] Levels 2 & 3
- [ ] Horror-themed main menu
- [ ] Save / checkpoint system

---

*Made with [Godot 4.6](https://godotengine.org/) — GDScript*
