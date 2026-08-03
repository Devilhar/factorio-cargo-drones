
# DroneData

The data structure representing additional data required by drones.

|Properties|Type||
|-|-|-|
|[version](#dronedata.version)|:: number|A value representing the version of the data structure used.|
|[cable](#dronedata.cable)|:: [DroneCableData](#dronecabledata)||
|[deployer](#dronedata.deployer)|:: [DroneDeployerData](#dronedeployerdata)||

### Properties

#### version :: number <a name="dronedata.version"></a>
A value representing the version of the data structure used. This is used by the Cargo drone mod to know how to interpret the data. So even if a value is moved/renamed/changed in a newer version of the Cargo drone mod, old data structures may still function.

This means that it is usually recommended to hardcode the value when creating structure.

|Mod Version|Data Version|
|-|-|
|< 1.18.0|N/A|
|>= 1.18.0|1|

>[!WARNING]
>Due to the version being part of the data structure, it is not recommended to copy another drone's data using `table.deepcopy` or similar methods unless you do not intend to change any of the values.

---

#### cable :: [DroneCableData](#dronecabledata) <a name="dronedata.cable"></a>
---

#### deployer :: [DroneDeployerData](#dronedeployerdata) <a name="dronedata.deployer"></a>
---

# DroneCableData

The data used when drones interact with depots.

|Properties|Type||
|-|-|-|
|[attachment_offset](#dronecabledata.attachment_offset)|:: Vector|Where cables visually attach.|
|[attachment_shadow_offset](#dronecabledata.attachment_shadow_offset)|:: Vector|Where cable shadows visually attach.|

#### attachment_offset :: Vector <a name="dronecabledata.attachment_offset"></a>
A shift vector to where depot cables should visually attach on the drone.

---

#### attachment_shadow_offset :: Vector <a name="dronecabledata.attachment_shadow_offset"></a>
A shift vector to where the shadow of depot cables should visually attach on the drone's shadow.

---

# DroneDeployerData

The data used by deployers to draw the drone.

|Properties|Type|
|-|-|
|[body](#dronedeployerdata.body)|:: [DroneDeployerBody](#dronedeployerbody)|
|[shadow](#dronedeployerdata.shadow)|:: [DroneDeployerShadow](#dronedeployershadow)|

#### body :: [DroneDeployerBody](#dronedeployerbody) <a name="dronedeployerdata.body"></a>
---

#### shadow :: [DroneDeployerShadow](#dronedeployershadow) <a name="dronedeployerdata.shadow"></a>
---

# DroneDeployerBody
The data used by deployers to draw the drone, excluding its shadow.

|Properties||Type||
|-|-|-|-|
|[spawn_offset](#dronedeployerbody.spawn_offset)||:: Vector||
|[prepare_offset](#dronedeployerbody.prepare_offset)||:: Vector||
|[filename](#dronedeployerbody.filename)|<span style="color:grey">optional</span>|:: string|Required and loaded if `positions` is defined.|
|[positions](#dronedeployerbody.positions)|<span style="color:grey">optional</span>|:: [DirectionPositions](#directionpositions)|The position of the four cardinal directions of the drone on the spritesheet.|
|[width](#dronedeployerbody.width)|<span style="color:grey">optional</span>|:: number|Required and loaded if `positions` is defined.|
|[height](#dronedeployerbody.height)|<span style="color:grey">optional</span>|:: number|Required and loaded if `positions` is defined.|
|[scale](#dronedeployerbody.scale)|<span style="color:grey">optional</span>|:: number|Only loaded if `positions` is defined.|
|[shift](#dronedeployerbody.shift)|<span style="color:grey">optional</span>|:: Vector|Only loaded if `positions` is defined.|

#### spawn_offset :: Vector <a name="dronedeployerbody.spawn_offset"></a>
The offset where the RenderObject representing the drone is created.

---

#### prepare_offset :: Vector <a name="dronedeployerbody.prepare_offset"></a>
The offset the RenderObject representing the drone should be moved to when the drone is prepared inside a deployer.

---

#### filename :: string <span style="color:grey">optional</span> <a name="dronedeployerbody.filename"></a>
Required and loaded if `positions` is defined.

The path to the sprite file to use.

---

#### positions :: [DirectionPositions](#directionpositions) <span style="color:grey">optional</span> <a name="dronedeployerbody.positions"></a>
The position of the four cardinal directions of the drone on the spritesheet. These will be used to create the required sprites.

If `positions` or any of its values are not defined, the required sprites must be created elsewhere.

---

#### width :: number <span style="color:grey">optional</span> <a name="dronedeployerbody.width"></a>
Required and loaded if `positions` is defined.

Width of the picture in pixels, from 0-4096.

---

#### height :: number <span style="color:grey">optional</span> <a name="dronedeployerbody.height"></a>
Required and loaded if `positions` is defined.

Height of the picture in pixels, from 0-4096.

---

#### scale :: number <span style="color:grey">optional</span> <a name="dronedeployerbody.scale"></a>
Default: `1`

Only loaded if `positions` is defined.

Values other than 1 specify the scale of the sprite on default zoom. A scale of 2 means that the picture will be two times bigger on screen (and thus more pixelated).

---

#### shift :: Vector <span style="color:grey">optional</span> <a name="dronedeployerbody.shift"></a>
Default: `{0, 0}`

Only loaded if `positions` is defined.

The shift in tiles. util.by_pixel() can be used to divide the shift by 32 which is the usual pixel height/width of 1 tile in normal resolution. Note that 32 pixel tile height/width is not enforced anywhere - any other tile height or width is also possible.

---

# DroneDeployerShadow
The data used by deployers to draw the drone's shadow.

|Properties||Type||
|-|-|-|-|
|[prepare_offset](#dronedeployershadow.prepare_offset)||:: Vector||
|[filename](#dronedeployershadow.filename)|<span style="color:grey">optional</span>|:: string|Required and loaded if `positions` is defined.|
|[positions](#dronedeployershadow.positions)|<span style="color:grey">optional</span>|:: [DirectionPositions](#directionpositions)|The position of the four cardinal directions of the drone on the spritesheet.|
|[width](#dronedeployershadow.width)|<span style="color:grey">optional</span>|:: number|Required and loaded if `positions` is defined.|
|[height](#dronedeployershadow.height)|<span style="color:grey">optional</span>|:: number|Required and loaded if `positions` is defined.|
|[scale](#dronedeployershadow.scale)|<span style="color:grey">optional</span>|:: number|Only loaded if `positions` is defined.|
|[shift](#dronedeployershadow.shift)|<span style="color:grey">optional</span>|:: Vector|Only loaded if `positions` is defined.|

#### prepare_offset :: Vector <a name="dronedeployershadow.prepare_offset"></a>
The offset where the RenderObject representing the drone's shadow is created. Should be the position of the drone's shadoow when the drone is prepared inside a deployer.

---

#### filename :: string <span style="color:grey">optional</span> <a name="dronedeployerbody.filename"></a>
Required and loaded if `positions` is defined.

The path to the sprite file to use.

---

#### positions :: [DirectionPositions](#directionpositions) <span style="color:grey">optional</span> <a name="dronedeployerbody.positions"></a>
The position of the four cardinal directions of the drone shadow on the spritesheet. These will be used to create the required sprites.

If `positions` or any of its values are not defined, the required sprites must be created elsewhere.

---

#### width :: number <span style="color:grey">optional</span> <a name="dronedeployerbody.width"></a>
Required and loaded if `positions` is defined.

Width of the picture in pixels, from 0-4096.

---

#### height :: number <span style="color:grey">optional</span> <a name="dronedeployerbody.height"></a>
Required and loaded if `positions` is defined.

Height of the picture in pixels, from 0-4096.

---

#### scale :: number <span style="color:grey">optional</span> <a name="dronedeployerbody.scale"></a>
Default: `1`

Only loaded if `positions` is defined.

Values other than 1 specify the scale of the sprite on default zoom. A scale of 2 means that the picture will be two times bigger on screen (and thus more pixelated).

---

#### shift :: Vector <span style="color:grey">optional</span> <a name="dronedeployerbody.shift"></a>
Default: `{0, 0}`

Only loaded if `positions` is defined.

The shift in tiles. util.by_pixel() can be used to divide the shift by 32 which is the usual pixel height/width of 1 tile in normal resolution. Note that 32 pixel tile height/width is not enforced anywhere - any other tile height or width is also possible.

---

# DirectionPositions
The positions on a spritesheet where the sprite corresponding to the direction is located.

|Properties||Type|
|-|-|-|
|[north](#directionpositions.north)|<span style="color:grey">optional</span>|:: Vector|
|[east](#directionpositions.east)|<span style="color:grey">optional</span>|:: Vector|
|[south](#directionpositions.south)|<span style="color:grey">optional</span>|:: Vector|
|[west](#directionpositions.west)|<span style="color:grey">optional</span>|:: Vector|

#### north :: Vector <span style="color:grey">optional</span> <a name="directionpositions.north"></a>
---

#### east :: Vector <span style="color:grey">optional</span> <a name="directionpositions.east"></a>
---

#### south :: Vector <span style="color:grey">optional</span> <a name="directionpositions.south"></a>
---

#### west :: Vector <span style="color:grey">optional</span> <a name="directionpositions.west"></a>
---

# CargoDroneModData

Only available after the Cargo drone mod's data-final-fixes.lua has run.

The data structure with information about the Cargo drone mod.

|Properties|Type||
|-|-|-|
|[items](#cargodronemoddata.items)|:: Array[string]||
|[inventory_size](#cargodronemoddata.inventory_size)|:: number||
|[burnt_results_enabled](#cargodronemoddata.burnt_results_enabled)|:: boolean||

### Properties

#### version :: Array[string] <a name="cargodronemoddata.items"></a>
Array[string] of all items with a place_result for a drone.

All items are automatically found, no need to add it manually.

---

#### inventory_size :: number <a name="cargodronemoddata.inventory_size"></a>
The inventory size of all drones.

---

#### burnt_results_enabled :: boolean <a name="cargodronemoddata.burnt_results_enabled"></a>
True if any drone has burnt results inventory size larger than 0.

---
