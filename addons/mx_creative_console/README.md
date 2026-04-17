# Godot MX Creative Console Integration

Godot version
License

A powerful plugin for the **Godot 4 Editor** that bridges your workflow directly with the **Logitech MX Creative Console** and **Loupedeck** devices.

This plugin runs quietly in the background of your Godot Editor, listening to contextual changes (like selecting a `Node3D`, editing a `TileMap`, exploring the `Inspector`, or scrubbing an `AnimationPlayer`). It syncs instantly with your physical hardware dials and buttons to give you tactile, zero-lag control over Godot.

> **Note:** This Godot addon is designed to be used together with **[Godot-LogiActionsPlugin](https://github.com/NahuelBigu/Godot-LogiActionsPlugin)** (the Logi Actions C# plugin) on the Logitech Options+ / Loupedeck side.

---

## ✨ Features

The integration is highly context-aware. Depending on what you are doing in Godot, your dials and screens will magically adapt:

- 🏎️ **Accelerated Native Dials:** Dials feature a velocity-curve algorithm. Turn a dial slowly for deep precision, or whip it fast to smoothly apply a 15x multiplied adjustment instantly. No lag, no rubberbanding.
- 📐 **Node Transform Control:** Control `Position`, `Rotation`, and `Scale` exclusively through tactile dials for both `Node2D` and `Node3D`. Supports infinite 3D rotations without hard clamps.
- 🎛️ **Live Inspector Control:** Focus on any numeric property (float/int ranges) in the Inspector. The hardware dials instantly lock onto that property and read the engine's exact mathematical bounds and steps for perfect manipulation.
- 🗺️ **TileMap Mastery:** Pick, erase, draw lines, or change Paint layers instantly via tactile buttons. Control Random Scatter with a dial exactly perfectly.
- 🎬 **Animation Scrubbing:** When working on an `AnimationPlayer`, your dials become a physical timeline scrubber. Buttons become immediate Play, Pause, and loop-toggles.
- 🛠️ **Deep Editor Workflow:** Shortcuts to attach scripts, toggle 3D View grids, manipulate snapping environments, run/pause the game, and traverse Undo/Redo history.

---

## 📦 Installation

1. **Download this Godot Plugin:**
  Copy the `addons/mx_creative_console` folder into the `addons/` directory of your Godot 4.x project.
   *(Path should look like: `res://addons/mx_creative_console/plugin.gd`)*
2. **Enable the Plugin:**
  Open Godot. Go to **Project > Project Settings > Plugins** and check the "Enable" box next to **MX Creative Console**.
3. **Install the Logitech C# SDK Plugin:**
  This Godot Addon talks to your Logitech hardware via a local bridge. Build and install the companion plugin from **[Godot-LogiActionsPlugin](https://github.com/NahuelBigu/Godot-LogiActionsPlugin)** (package name on device: **Godot MX Console Bridge**).

---

## 🚀 How It Works (Architecture)

1. **Godot Side (This Addon):** Uses Editor API callbacks to analyze your active selection and active screen (2D, 3D, Script, etc). It builds a `ContextSnapshot` and hosts a local HTTP REST listener.
2. **Logitech Side (C# Plugin):** Polls the context and redraws your hardware icons. When you physically spin a dial, the C# plugin fires a high-speed HTTP POST with a payload (e.g., `{"relative": true, "value": 2.5}`) directly into to Godot.
3. **Execution:** Godot parses the delta, executes the exact engine manipulation natively, and wraps it cleanly in Godot's Undo/Redo stack.

---

## 📚 Documentation

For deep technical insights or customization guides, see the `docs/` folder:

- [User Guide & Setup Workflow](docs/user-guide.md)
- [Technical Architecture](docs/architecture.md)