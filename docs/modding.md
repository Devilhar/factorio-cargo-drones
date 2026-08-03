# Modding

## Add new drone type

It is possible to create new drones without altering this mod by using a car prototype and then registering it as a drone.

### The Prototype

The car prototype is created like normal. But the Cargo drone mod makes a few assumptions that needs to be kept in mind.

- If a drone is close enough to its target, it will try to turn towards it without accelerating. This assumes that `tank_driving` is set to true.
- The Cargo drone mod always try to control the drone directly. So allowing drivers or remote driving may cause issues.
- Drones do not perform any pathfinding, instead they try to go in the direction of its target. So to stop drones from getting stuck, collision for the drone needs to be disabled.

> [!WARNING]
>All drones must have the same inventory size. The Cargo drone mod asserts this by throwing an error in data-final-fixes.lua if there's a mismatch. This is due to how task scheduling is implemented.
>It is recommended to set inventory_size to the value of the "cargo-drone-inventory-size" setting to avoid this issue.
>```lua
>inventory_size = settings.startup["cargo-drone-inventory-size"].value

### Registering a drone

All drones must be registered to the Cargo drone mod during the data phase for them to work as drones.

This is done by creating a [DroneData](data-structures.md) structure and then adding it to the ModData named "cargo-drone-drones" using the name of the drone entity as key.

Here is how the DroneData structure for the Cargo drone mod's own drone is added, where `drone_data` is the structure and `"cargo-drone"` is the name of the drone prototype:
```lua
data.raw["mod-data"]["cargo-drone-drones"].data["cargo-drone"] = drone_data
```

This must be done before the Cargo drone mod's data-final-fixes.lua is run, as it validates and process all data there.

### Extra Sprites

Deployers require sprites to be able to render the drone.

A total of 20 sprites need to be created. 5 per cardinal direction, of which 1 is the shadow. The other 4 are the same image of the drone at different stages of being revealed.

The reason these are needed is that the Deployer has a sprite above its lower part that conceals the drone as it is being prepared. But this sprite is not big enough to conceal the entire drone, so the drone sprite has to be split into sprite slowly showing more and more.

Sprites ending in 1 is only showing the top 25% of the image, 2 shows the top 50%, 3 shows the top 75%, and 4 being the whole drone.

These are the height of the sprite above the Deployer:
|Deployer Orientation|Height|
|--------------------|------|
|Vertical            |  31px|
|Horizontal          |42.5px|

These are the distance from the drone position to the top of the sprite above the Deployer:
|Deployer Orientation|Height|
|--------------------|------|
|Vertical            |43.5px|
|Horizontal          |  37px|

The list of sprites are:
```lua
"cargo-drone-deployer-{drone_prototype.name}-north-1"
"cargo-drone-deployer-{drone_prototype.name}-north-2"
"cargo-drone-deployer-{drone_prototype.name}-north-3"
"cargo-drone-deployer-{drone_prototype.name}-north-4"
"cargo-drone-deployer-{drone_prototype.name}-east-1"
"cargo-drone-deployer-{drone_prototype.name}-east-2"
"cargo-drone-deployer-{drone_prototype.name}-east-3"
"cargo-drone-deployer-{drone_prototype.name}-east-4"
"cargo-drone-deployer-{drone_prototype.name}-south-1"
"cargo-drone-deployer-{drone_prototype.name}-south-2"
"cargo-drone-deployer-{drone_prototype.name}-south-3"
"cargo-drone-deployer-{drone_prototype.name}-south-4"
"cargo-drone-deployer-{drone_prototype.name}-west-1"
"cargo-drone-deployer-{drone_prototype.name}-west-2"
"cargo-drone-deployer-{drone_prototype.name}-west-3"
"cargo-drone-deployer-{drone_prototype.name}-west-4"
"cargo-drone-deployer-{drone_prototype.name}-shadow-north"
"cargo-drone-deployer-{drone_prototype.name}-shadow-east"
"cargo-drone-deployer-{drone_prototype.name}-shadow-south"
"cargo-drone-deployer-{drone_prototype.name}-shadow-west"
```
Where `{drone_prototype.name}` is replaced with the entity name.

These can be created manually, or by defining the `deployer.body.positions` and `deployer.shadow.positions` values when registering the drone which will automatically create all sprites.
