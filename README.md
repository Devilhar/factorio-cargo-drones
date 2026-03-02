<p align="center"><img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/cargo-drone/graphics/cargo-drone-icon-256x256.png" alt="Logo" width="128"></p>

<h1 align="center">Cargo Drones</h1>

A mod for Factorio that adds a long distance Cargo Drone airship that automatically move items between moorings structures.

Cargo Drones can pick items up from providers and deliver them to requesters. They can also refuel at refueler moorings.

## Usage
For Cargo Drones to function, you need to place down a provider, requester, and refueler mooring in your world.
Notice that the provider and requester moorings don't have any inventory space; instead you need to give them a circuit signals explained below.

- Provider Moorings: To make items available for pickup, input signals of the items and their count
- Requester Moorings: To request items, input signals of the items and their count
- Refueler Moorings: Refueler moorings are always active, so make sure that they have fuel available or Cargo Drones will get stuck waiting there as they will not leave until fully refueled

When a Cargo Drone is waiting at a mooring, you can insert and extract items by inserting into/out of the mooring

You can find an example setup and Blueprint book cheat sheet [here](example-setup.md)

### Limit Cargo drones per mooring
You can set a limit of incoming Cargo drones to any mooring by setting it in its menu or by sending the mooring a signal.

For Signals:
- Any value greater than 0 will set the limit to that value
- Any value less than or equal to 0 will stop new Cargo drones from heading towards it

Note that Cargo drones already tasked with going to a mooring will not stop or change task if the mooring is now above its limit.

### Mooring priority
You can set any mooring's priority to a number between 0 and 255 (inclusive) by setting it in its menu or by sending the mooring a signal. Moorings with a higher priority signal will be targeted first by Cargo drones.

For Signals:
- The value will be clamped between 0 and 255

Note that Cargo drones already tasked with going to a mooring will not change target if there's a new mooring with higher priority.

### Mooring inventory targeting
You can set which inventory each tile of the mooring should target. This is primarily intended for removing burnt results, but can be used to refuel Cargo drones at any mooring.

Limitation:
- Mirroring moorings when pasting them will not mirror the inventory targets inside the mooring. But it is possible to mirror them once they have been placed.

### Special thanks
Thank you to KeithFromCanada for feedback and help
