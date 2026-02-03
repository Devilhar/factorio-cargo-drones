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

You can find an example setup [here](example-setup.md)

### Limit Cargo drones per mooring
You can set a limit of incoming Cargo drones to any mooring by sending the mooring a [L] signal.
- Any value over 0 will set the limit to that value
- Any value below 0 will stop new Cargo drones from heading towards it
- If the signal is 0, there is no limit

Note that Cargo drones already tasked with going to a mooring will not stop or change task if the mooring is now above its limit.

### Mooring priority
You can set any mooring's priority to a number between 0 and 255 (inclusive) by sending it a [P] signal. Moorings with a higher priority signal will be targeted first by Cargo drones.

Mooring priority defaults to 0 if no priority signal is sent.
