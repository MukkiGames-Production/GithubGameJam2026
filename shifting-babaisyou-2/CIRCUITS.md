# Box circuits

Open `player_move_scene2.tscn` and run the current scene (F6). WASD moves the player;
bump a box to push it one cell. The two boxes contain `1` and `0`. Their invisible
source tiles feed an invisible output tile, which forwards both values to a gate.
The gate prints `Gate open: true` or `Gate open: false` on startup and state changes.
Any nonzero output opens it; changing both boxes to `0` closes it.

The scene uses the existing player and box sprites, with no added visual elements.
It matches `test_world.tscn`: 16-pixel TileMap cells with 2x layer scale give
32-pixel movement steps. The 32-pixel sprites fill one cell without scaling the
player or boxes. Both snap to the TileMap's cell centers.

To build a circuit in a level using `LevelManagement/level.gd`:

1. Assign the level's `walls_layer`. This TileMapLayer defines the grid for boxes
   and signal tiles; match the player's step size to its scaled cell size.
2. Instance `SignalTile.tscn` at each interactive cell's center. Ordinary floor
   tiles remain ordinary tiles. SignalTile may also be used in a TileSet scene
   collection; explicitly placed instances make destination wiring easiest.
3. Expand each tile's exported `destinations` array in the Inspector, add entries,
   and drag destination SignalTile nodes from the Scene tree into those slots.
   These are direct node references; no Godot signal connections are required.
   A tile can feed several destinations, and several tiles can feed one tile.
4. Place a `MovingEntities/Box/Box.tscn` on a signal tile. Set `val` to a binary string for a source,
   or leave `val = "-1"` and set `op` for an operator. A value takes priority if
   both are set. No box (or a box with neither field set) forwards incoming strings.
5. Add a gate to a terminal tile's `receivers`. Receivers implement
   `incoming_signal(bool)`. Any nonzero output opens the gate; zero or no output
   closes it. Route combined inputs through one terminal tile per gate.

AND, OR, XOR, NAND, NOR, and XNOR take two or more inputs. Shorter strings are
left-padded with zeroes to the widest input. The inverted operators invert once
after combining all inputs. NOT takes exactly one input and preserves its width.
`<<` and `>>` take a value and an optional binary shift amount (default one),
preserve the value's width, and discard overflow. Source tiles' scene-tree order
defines operand order, including through passthrough tiles: put the shift's value
source before its amount source.

Operators wait for every connected predecessor to have an output. Empty tiles
also wait for all their connected predecessors, then forward each string without
combining them. Value boxes supply their own value independently of incoming values.
Invalid binary strings, operators, or operand counts produce no output. Cycles
and tiles depending on cycles produce no output. Inspect `level.signal_errors`
and each tile's `error`, `incoming_values`, and `output_values` in the debugger.

Box movement, deletion, and changes to `val`/`op` automatically request a deferred
recalculation. After changing destination links or moving signal tiles at runtime,
call `level.request_signal_update()`. Read `output_values` to inspect a tile's
current result. Multiple tiles should not occupy the same cell.

The player uses `MovingEntities/Player/player.gd`, inheriting the same grid
movement as boxes. It discovers its parent level automatically and pushes boxes
through the level's grid registry. TileMap cell centers determine both player
and box positions; no raycast or Area2D is needed to push a box.

Run the circuit integration and operator checks with:

```sh
godot --headless --path . -s res://tests/test_signal_network.gd
```
