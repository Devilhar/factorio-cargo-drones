<h1 align="center">Usage</h1>

## <img src="https://raw.githubusercontent.com/Devilhar/factorio-cargo-drones/refs/heads/main/docs/cargo-drone-icon.png" width="32"> Cargo drone

The easiest way to imagine the Cargo drone is as a Logistic robot, picking up items from a provider and then dropping it off at a requester. But instead of chests, they go to mooring towers. And unlike robots where the chests must be connected by Roboports, mooring towers work over the entire surface.

Another difference is the source of fuel. Cargo drones need fuel like a Car. This can be given manually, but to make it work autonomously it needs access to a Refueler mooring. Once drones run low enough on fuel, they will seek out the nearest available Refueler.

If drones don't have a task, they will seek out available depots where they will await further tasks.

## Moorings

The moorings are what allows you to insert into or take items out of drones.
They don't have an inventory of their own, instead when a drone docks with a mooring, inserters interacting with the mooring will access the drone's inventory.

### <img src="https://raw.githubusercontent.com/Devilhar/factorio-cargo-drones/refs/heads/main/docs/cargo-drone-mooring-provider-icon.png" width="32"> Provider mooring

Provider moorings works similar to Provider chests, making items available to be picked up by drones. To tell it what items are available, continuously send it a circuit signal with all the items and their quantity.

### <img src="https://raw.githubusercontent.com/Devilhar/factorio-cargo-drones/refs/heads/main/docs/cargo-drone-mooring-requester-icon.png" width="32"> Requester mooring

Requester moorings works similar to Requester chests, but since it doesn't have an inventory, it doesn't make sense to set requests the same way. To make requests continuously send it a circuit signal with all the requested items and their quantity.

#### Request mode
The Requester has 4 request modes. These are used to set the minimum amount of items that must be delivered in a single request. If no single Provider has enough items to fullfill a request, no drone will be tasked.

This can be used to stop multiple drones being assigned tasks to pickup single items as they become available at providers.

| Mode | Minimum item requested              |
|------|-------------------------------------|
|Any   |No minimum, will pickup any amount   |
|Stack |All requests are for full stacks only. Note that requests are rounded up, so if the Requester has a signal for 101 Iron plates, it will try to request 200 Iron plates|
|Fuzzy |Sets the minimum to either a stack or the exact amount requested, whichever is smaller|
|Full  |Sets the minimum to a drone's inventory capacity. Note that requests are rounded up, so assuming drones have 10 inventory slots and the Requester has a signal for 1 Iron plate, it will try to request 1000 Iron plates|

### <img src="https://raw.githubusercontent.com/Devilhar/factorio-cargo-drones/refs/heads/main/docs/cargo-drone-mooring-refueler-icon.png" width="32"> Refueler mooring

Refueler moorings is where drones will head to when they run low on fuel. Once the drone is fully fueled, it will return to whatever it was doing.

If the docked drone has any burnt results in it, it will also wait for those items to be removed before leaving. This is only relevant if burnt results has been enabled in the mod settings.

### Limit drones per mooring
You can set a limit of incoming drones to any mooring by setting it in its menu or by sending the mooring a signal.

For Signals:
- Any value greater than 0 will set the limit to that value
- Any value less than or equal to 0 will stop new drones from heading towards it

Note that drones already tasked with going to a mooring will not stop or change task if the mooring is now above its limit.

### Priority
You can set any mooring's priority to a number between 0 and 255 (inclusive) by setting it in its menu or by sending the mooring a signal. Moorings with a higher priority signal will be targeted first by drones.

For Signals:
- The value will be clamped between 0 and 255

Note that drones already tasked with going to a mooring will not change target if there's a new mooring with higher priority.

### Inventory targeting
You can set which inventory each tile of the mooring should target. This is primarily intended for removing burnt results, but can be used to add or remove fuel or burnt results from drones at any mooring.

#### Limitation:
- Mirroring moorings when pasting them will not mirror the inventory targets inside the mooring. But it is possible to mirror them once they have been placed.

## <img src="https://raw.githubusercontent.com/Devilhar/factorio-cargo-drones/refs/heads/main/docs/cargo-drone-depot-icon.png" width="32"> Depot

Depots act as a gathering point for drones with no task. This can be used to reduce delivery times since drones closest to the Provider will be preferred when assigning tasks.

Drones will try to spread themselves evenly amongst the depots with the highest priority.

### Limit drones per depot
You can set a limit of incoming and parked drones to any depot by setting it in its menu or by sending the depot a signal.

For Signals:
- Any value greater than 0 will set the limit to that value
- Any value less than or equal to 0 will stop new drones from heading towards it

Note that drones already tasked with going to a depot will not stop or change depot if the depot is now above its limit.

### Priority
Drones will always target depots with the highest priority. So if there's a depot with a priority of 60, drones will target it over any depot with a priority lower than 60. This means that if a depot does not have a drone limit set, no depot with a lower priority will ever be targeted by a drone.

You can set a depot's priority to a number between 0 and 255 (inclusive) by setting it in its menu or by sending the depot a signal. Depots with a higher priority signal will be targeted first by drones.

For Signals:
- The value will be clamped between 0 and 255

Note that drones already tasked with going to a depot will not change target if there's a new depot with higher priority.

## <img src="https://raw.githubusercontent.com/Devilhar/factorio-cargo-drones/refs/heads/main/docs/cargo-drone-deployer-icon.png" width="32"> Deployer

Deployers can automatically deploy new drones when needed. This is done by inserting drones as items into the deployer, this will automatically prepare the drone. Once the drone is prepared it needs to be fuelled before it will be released, this is done by inserting the fuel into the deployer. When the drone has a full fuel inventory, the deployer can autonomously release it.

By default drones are only released if there are no drones without a task. This can be changed to always be released in the deployer.

Drones are only released if the amount of drones on the surface is less than the deployer's total drone limit.

### Total drone limit
To stop an endless amount of drones from causing lag, there's a limit on the total amount of drones that are allowed on the surface of the deployer. This limit is set per deployer. Drones are only released if the amount of drones on the surface is less than the deployer's total drone limit.

You can set the total drone limit for any deployer by setting it in its menu or by sending the deployer a signal.

For Signals:
- Any value greater than 0 will set the total limit to that value
- Any value less than or equal to 0 will stop new drones from being released by that deployer

### Drone statistics
Deployers keep track of two drone counts, used in its logic. These can be outputted by the deployer via circuit signals.

#### Total drone count
The amount of drones on the surface of the deployer. Includes any drone currently being released.

#### Available drone count
The amount of drones on the surface of the deployer that does not have a task assigned to them. Includes any drone currently being released.
