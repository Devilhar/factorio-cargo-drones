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

When a Cargo Drone is waiting at a mooring, you can insert and extract items by inserting into/out of the mooring.

- You can find an example setup and Blueprint book cheat sheet [here](docs/example-setup.md)
- For more in-depth explanations go to the [usage](docs/usage.md) section

## Want your name in the mod?
Moorings and Depots have a list of default names. If you want your name in it, simply leave a comment on [this thread](https://mods.factorio.com/mod/cargo-drone/discussion/69cffa6b1ac576ba3a8cc2bb) or submit it in [this Google forms](https://docs.google.com/forms/d/e/1FAIpQLScxgUvPshNqgkHA6LmNkEkS_W-_6UsW4ZvHqafAvMTLcefAzg/viewform?usp=header).

## Modding
It is possible to add new drones via modding without altering the Cargo drone mod's files. An minimal example of how to implement it can be found on [Github](cargo-drone-test/data.lua) in the cargo-drone-test mod. [Documentaion](docs/modding.md)

### Special thanks
Thank you to KeithFromCanada for feedback and help
