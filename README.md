# 🟣 Purple Weasle

> *A top-down stealth puzzle game. You are the Purple Weasle — sneak, crouch and outwit guards to reach the exit undetected.*

---

## 🎮 Gameplay

Navigate each level without being spotted. Guards have a **cone of vision** — stay in the shadows, crouch to reduce your noise, and time your movements to slip past their patrol routes.

### Controls

| Key | Action |
|-----|--------|
| `W A S D` | Move |
| `Left Shift` | Crouch (quieter, harder to spot) |
| `Left Ctrl` | Dash (fast but noisy) |
| `E` | Interact |

### Alert System

Guards have three states:

- 🟢 **Unaware** — patrolling normally
- 🟡 **Suspicious** — heard or half-saw something, investigating
- 🔴 **Alert** — spotted the weasle, giving chase

Crouching in a **shadow zone** makes you almost invisible. Standing in the open while a guard faces you will fill their suspicion meter fast.

---

## 🏗️ Project Structure

```
purple-weasle/
├── project.godot               # Godot 4 project config & input map
├── scenes/
│   ├── main_menu.tscn
│   ├── game_over.tscn
│   └── level_01.tscn           # The Museum Lobby
├── scripts/
│   ├── player.gd               # Movement, crouch, dash, shadow detection
│   ├── guard.gd                # Patrol, alert states, chase behaviour
│   ├── detection.gd            # Line-of-sight cone with raycast occlusion
│   ├── shadow_zone.gd          # Dark area that hides the player
│   ├── game_manager.gd         # Autoload — level flow & scoring
│   ├── main_menu.gd
│   └── game_over.gd
└── assets/
    ├── sprites/
    ├── tilemaps/
    └── audio/
```

---

## 🛠️ Getting Started

1. Download [Godot 4](https://godotengine.org/download/)
2. Clone this repo:
   ```bash
   git clone https://github.com/iamsidge/purple-weasle.git
   ```
3. Open `project.godot` in the Godot editor
4. Hit **Play** (F5)

---

## 🗺️ Planned Levels

| Level | Setting | New mechanic |
|-------|---------|--------------|
| 1 | Museum Lobby | Basics — shadows & patrol |
| 2 | Research Lab | Cameras & laser tripwires |
| 3 | Rival Gang HQ | Multiple guards, noise distractions |

---

## 📋 Roadmap

- [x] Project scaffold & base scripts
- [ ] Placeholder sprites for player & guard
- [ ] Tilemap for Level 1
- [ ] Working guard patrol & line-of-sight
- [ ] Shadow zone visual polish
- [ ] Sound effects & ambient audio
- [ ] Level 2 & 3
- [ ] Main menu polish & splash screen

---

*Made with [Godot 4](https://godotengine.org/) — GDScript*
