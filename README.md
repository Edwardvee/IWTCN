# I Want That Castle Now!

[![Engine](https://img.shields.io/badge/Engine-Godot_4.x-blue?logo=godotengine)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Mobile_Android_%2F_iOS-green)](#)
[![Genre](https://img.shields.io/badge/Genre-Lane_Auto--Battler_%7C_RTS-orange)](#)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](#)

A fast-paced 2D vertical mobile lane auto-battler and base-building RTS inspired by competitive classics like *Warcraft 3: Castle Fight* and the immediate, tactical decisions of *Clash Royale*. 

Defend your stronghold, optimize production on a restricted territorial grid, and overrun your rival's kingdom through synchronized automated waves.

---

## ⚔️ Game Overview & Core Loop

In *I Want That Castle Now!*, you do not directly pilot units on the battlefield. Instead, victory is decided by your **macro-management, tactical drafting, grid optimization, and economic ramp-up**.

```
    ┌───────────────────────────────┐
    │     DRAFT CYCLE (1 of 3)      │
    │   Structures | Buffs | Units  │
    └───────────────┬───────────────┘
                    ▼
    ┌───────────────────────────────┐
    │     TERRITORY MANAGEMENT      │
    │ 6 Plots x 4 Slots = 24 Slots  │
    └───────────────┬───────────────┘
                    ▼
    ┌───────────────────────────────┐
    │     PRODUCTION & HARVEST      │
    │ Passive Gold & Wave Spawns    │
    └───────────────┬───────────────┘
                    ▼
    ┌───────────────────────────────┐
    │       AUTO-LANE COMBAT        │
    │ Clashing in the Central Lane  │
    └───────────────┬───────────────┘
                    ▼
    ┌───────────────────────────────┐
    │       TOTAL CONQUEST          │
    │ Destroy Castle & All Outposts │
    └───────────────────────────────┘
```

### The Rules of Engagement
1. **The Draft Phase:** At regular intervals, you are presented with **3 randomized choices**: permanent structures, global army buffs, or immediate unit reinforcements.
2. **Restricted Territory:** Your kingdom consists of **6 building plots**, each containing **4 build spaces** (24 total slots).
3. **Merging & Upgrades:** To upgrade a structure, you draft and construct additional copies. Multiple structures merge together into advanced tiers, condensing stats while liberating crucial grid spaces.
4. **Win Condition:** Push down the lane, eliminate all enemy defensive structures, and obliterate the opposing castle core.

---

## 🏗️ Structures & Economy

Grid management is the core puzzle of every match. Allocating too many slots to economy will leave your lanes vulnerable; over-investing in static defense leaves you unable to push.

| Structure | Archetype | Mechanic & Scaling |
| :--- | :--- | :--- |
| **Farm** | Economy / Gold Engine | Generates gold every 8 seconds.<br>• **Lvl 1:** +25 Gold / 8s<br>• **Lvl 5:** +100 Gold / 8s *(consolidated into a single slot)* |
| **Tower** | Static Defense | Automated ranged turret protecting your base perimeter. Upgrades increase attack speed, range, and burst damage. |
| **Barracks (Soldier)** | Melee Spawner | Regularly deploys front-line infantry.<br>• **Lvl 1:** Spawns 2 Soldiers every 8s.<br>• High-tier barracks decrease interval and boost unit stats. |
| **Barracks (Archer)** | Ranged Spawner | Spawns backline ranged troops to provide sustained DPS behind melee waves. |
| **Church** | Utility / Magic | Trains Priests to heal and bolster your army.<br>• **Lvl 3:** Unlocks the **Mind Conversion** passive, giving priests a chance to convert enemy units. |

> **Consolidation Rule:** Duplicate buildings automatically merge upon reaching tier requirements, freeing up adjacent tiles for tactical counter-building.

---

## 🛡️ Unit Hierarchy

Units march down the vertical lane automatically upon deployment, using custom pathfinding and target prioritization.

```
       [TANK] ──── High HP meat-shield; absorbs tower aggro & pushes lines
         │
    [SOLDIER] ──── Balanced baseline melee fighter; controls lane tempo
         │
    [ARCHER] ──── Squishy ranged DPS; relies entirely on frontline protection
         │
    [PRIEST] ──── Support caster; heals allies & converts enemy units (Lvl 3)
```

* **Soldier:** Reliable, balanced melee combatant. Forms the backbone of your offensive waves and stalls enemy pushes.
* **Archer:** Long-range, rapid-firing glass cannon. Dominates open fields when shielded by Soldiers or Tanks.
* **Tank:** Massive health pool, low movement speed. Soaks tower fire, absorbs initial bursts, and shatters defensive bottlenecks.
* **Priest:** Essential support unit. Restores hit points to damaged allies in a radius and casts stat enhancements. At **Church Tier 3**, regular attacks roll a chance to turn enemy units against their own master.

---

## 🎴 The Draft System

When the draft triggers, players must choose one of three cards:

* **Structures:** Expand your footprint with farms, barracks, defensive towers, or religious temples.
* **Global Buffs:** Permanent passive bonuses that enhance your board state (e.g., `+15% Troop March Speed`, `+10% Armor`, `-1.5s Spawner Cooldowns`).
* **Tactical Units:** Instant reinforcement drops deployed directly to the battlefield to stabilize a losing lane or punish an open flank.

---

## 🛠️ Tech Stack & Architecture

* **Engine:** [Godot Engine 4.x](https://godotengine.org/) (Standard 2D Mobile Pipeline)
* **Scripting Language:** GDScript
* **AI Architecture Partner:** Engineered and architected in collaboration with Claude AI (Anthropic)
* **Target Resolution:** 1080 x 1920 (Vertical 9:16 aspect ratio)
* **Codebase Structure:**
  * `src/core/`: Match state machine, win/loss triggers, and global match clock.
  * `src/grid/`: 24-slot plot validation, placement coordinates, and building merge logic.
  * `src/entities/`: Finite State Machines (FSM) for unit pathfinding, targeting, and combat interactions.
  * `src/draft/`: Weighted card pool generation, rarity curves, and pick mechanics.
  * `src/economy/`: Gold generation loops, income curves, and purchase handlers.

---

## 🚀 Setup & Local Development

### Prerequisites
* Godot Engine 4.2+ (Standard Edition).
* Android/iOS build tools and export templates (optional, for physical device deployment).

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/i-want-that-castle-now.git
   ```
2. Launch Godot Engine and click **Import**.
3. Locate the cloned repository and select `project.godot`.
4. Run the main test scene by pressing **F5** (or open `res://scenes/Main.tscn`).

---

## 🗺️ Roadmap

- [x] Initial 24-slot grid system implementation (6 plots × 4 spaces).
- [x] Base wave spawner and single-lane AI pathfinding.
- [ ] Structure consolidation (tier merge algorithm) to balance space economy.
- [ ] Numerical balance pass on Farm income vs. Draft card costs.
- [ ] Priest Mind Conversion logic and target restriction rules.
- [ ] Full touch-control UI/UX pass for 9:16 mobile viewports.

---

## 👥 Credits

* **Game Design & Lead Development:** [Your Name / Studio Name]
* **Game Logic & Systems Architecture:** Assisted by **Claude AI (Anthropic)**
* **Engine:** Built with the [Godot Engine](https://godotengine.org/) community

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
