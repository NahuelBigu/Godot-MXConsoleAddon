# MX Creative Console User Guide

By utilizing the Logitech MX Creative Console hardware alongside this Godot Plugin, your editor transforms into a contextual workstation.

## Related repositories

- **This addon (Godot):** [github.com/NahuelBigu/Godot-MXConsoleAddon](https://github.com/NahuelBigu/Godot-MXConsoleAddon)
- **Logi Actions plugin (Windows / Options+):** [github.com/NahuelBigu/Godot-LogiActionsPlugin](https://github.com/NahuelBigu/Godot-LogiActionsPlugin)

The in-app **help link** in the Logitech plugin (Options+ → plugin status) points to the Godot addon repo so you can install and enable **`mx_creative_console`** in your project.

## How Contexts Work

The dials and buttons on your hardware will change depending on exactly what you have selected on Godot. The currently supported "Live Contexts" are:

### 1. 📐 Node Transform

- **Trigger:** Select any `Node3D` or `Node2D` in the Scene Tree.
- **Dial Interactions:** 
  - Turn to adjust Position X, Y, Z.
  - Turn to adjust Rotation X, Y, Z.
  - Turn to uniformly scale the object.
  - **Tip:** The faster you twist the dial, the more exponentially it multiplies the step boundary. A fast flick can smoothly traverse your whole scene without repetitive turning.

### 2. 🎛️ Inspector Live Property

- **Trigger:** Click on any numeric field (float or integer slider) in the Inspector.
- **Dial Interactions:** 
  - The dial instantly overrides its function to control ONLY that clicked property.
  - The plugin dynamically reads the Godot `step` values from that slider. For example, if Godot enforces a `0.001` float increment, your standard dial turn will obey `0.001` flawlessly. Faster spins will accelerate `0.001 -> 0.05`.

### 3. 🗺️ TileMap Master

- **Trigger:** Select a `TileMap` node and use the 2D Viewport.
- **Dial / Button Interactions:** 
  - You gain physical buttons for standard Drawing, Line tools, Rectangles, Picker, and Eraser.
  - Dial dynamically adjusts your Scatter Density without needing to locate it deep in the Godot inspector.
  - Layers can be swapped directly via hardware buttons.

### 4. 🎬 Animation Scrubbing

- **Trigger:** Select an `AnimationPlayer` node and focus the Animation timeline panel.
- **Dial / Button Interactions:**
  - Dial becomes a live timeline scrubber. Twisting scrubs time proportionally to the exact animation step length.
  - Buttons physically Play and Pause the timeline.

### 5. 🛠️ General Workflow Tools

No matter your context, globally useful Godot utilities are always available on the device pads, such as:

- Attach scripts to the active node.
- Instantly toggle between Orthogonal & Perspective and Viewport 3D directions.
- Toggle Godot Grid Environment Snapping.

## Troubleshooting

- **Option/Action does not work or displays "Waiting for Godot..."**
Ensure the Godot Engine is currently running and the `MX Creative Console` Addon is Enabled in your Project Settings. The Logitech background service communicates to an invisible HTTP server hosted natively by this Godot Addon (via port 49152+ by default).
- **Movement is choppy / "rubberbanding":**
All relative math has been rewritten for raw performance. If you experience lags, ensure Godot is focused and the editor processes aren't completely frozen due to compiling C# or running an intense scene.