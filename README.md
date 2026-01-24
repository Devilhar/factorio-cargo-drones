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

**Note**
Moorings can only have 1 Cargo Drone heading towards them at a time. If a requester mooring require more items than what a Cargo Drone is carrying, no other Cargo Drone will be assigned until the first one is done delivering its cargo.
