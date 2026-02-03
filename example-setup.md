## Example Setup

### Cheat sheet blueprints

Here is a blueprint book with cheat sheets:
<details>

<summary>Cheat sheet</summary>

```0eNq9V01v2zgQ/SsE97agDEm2i8ZATjm16MHY9rJwDYO2mIioJKokZdcI/N93hvq0JUc20i4COBQ1evM48zgcvtJtUohcy8xutkr9oIvXdsbQxarziO8iYXZa5laqjC7oV5FFxMaC7FRmRWaJei4fY2Essco95FrtZSQ0IxysZWaEtsRYzeVLbOEZzKSdUEYloJQujXzJeIL+Mp4KcLTj+kV5kVaZ8Go8L1UKaL3QE3yaReIXXQSnNaPAQ1opSiT3cNxkRboVGgxYjWisEInniILrXBlZrumVAk4YTOaMHunCC2B0OrEeUNgAlQuCuT5KeIbCaCS12JUGQTgAOmU3rbfvaHbhCNOhVbLZipjvpdJopwWPNlWeIDbPPDHihPE6ACsM1ipgAZuyYA1z0ooUaLSpZzThWwEpocuKDmnp7IU2js38Q/gwe3iYfwz9+WwWtInxcbVvCOlJpcKQg7QxMTLNE0GQAdHiZ4FKMsIW+YT8qwqy4xnhUUS4ISnPjrWJwYkjvD/wDEXllPcEerL4vFPpVmbcKhDhtgBlxtKQhg6+rr3bgyI515AFSKkDFb84ErpDoBWlP6tQv0r59D0CDbogZ/qcvSlPriFWECK589rQDuGX6H4PfViiLSwKNXJQBl88S23spg26PeZIYy+1LWCmDZmz8ATfxRhzIxAGsZwMcH8wqnKheSW7v+FTVdi8uBv8NBTzGbtNDv1ATc8Tcfv+7ZOYtySqdY/kqHYdXnVtyryZ8zFotxY1gwwluGEuZisizYbyfCDwE6IKhGE+Uzp1EQaCaIMEF/TRTRSYryDABVZ44QBecCdeeFrD33DZY6sp/J+5EfyyeVkK22rgFlepQ0atMP4KyCesVnCQVbnGWhFdW7jXaBvjOc7eJblyWyWZ1YMFDYI+kXK1UJdhQ/Ftgq8C36cdnDP64Tj94I/RD/tErtF/+1z6p95mdx1MwcjB9Lkwtu5ZnguRXDQueMpU7u46IBDqfafD9ao+rbuB6U1NR8huoNh38qHjZDQziHVnYsKRxHyN1cEQ+EHdJjKVmBGQHuCTFZJ57Cxn/YRj4sbGtaHQUdR0oEGFOgchmXzPvmFjUBg0Ij1BdXqHg9I/qo6BJ0ltYCZ91732bd036Z0QgzbdhKz/927kpsPE9Z8d7f3Ww2TkXP5y51FwfrKMgC/vA5/75TkDAUr4UejNuXa/QdVYVa680sNjvYo1KUelpo2rMDxFWLxcjSjbxtwSbt1HBhZArIQfbJktmAl7Vq++Z6j3q0yWDRPYK6b7pWl2DBvdasmBH82A96rbhokYqin2+DUmcc3epOSWqIN7p4yRcBK0RrAH/fJCeYYxZBfO5xN6R+Eb7da8j5XIw3detsLRy9YXV9hwmctqRTcVz+lQRfbc/b7F7iQKL+wgGxMLgd4vKm15IVs21/imMJYJaMq7u6XdXJguyxCHUrAXm/rC+MYyT/8Bb3+zwA==```

</details>

### Provider mooring

The easiest setup is to have a chest inserting into the Provider mooring and sending it its content.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/provider-setup.png">

#### Signals

To wire up the signals, simply connect the chest to the mooring with either red or green wire. The color makes no difference. By default, wired chests automatically read their content, but you can make sure by opening the chest and see that the "Read content" checkbox is checked.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/provider-chest-configuration.png">

### Requester mooring

The easiest setup is to have a Requester mooring inserting into a chest. Then have the chest send its content into an Arithmetic combinator and invert the signal, and send the inverted signal to the Requester mooring. Finally a Constant combinator with a list of the requested items wired up to the Requester mooring using the same colored wire as the Arithmetic combinator.

This makes it so the mooring will requests items missing from the chest.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-setup.png">

#### Signals

Connect the chest to the Arithmetic combinator's input (The side with an arrow pointing *into it* when in Alt-mode) with either red or green wire. The color makes no difference. Make sure its sending its content over the wire by opening the chest and see that the "Read content" checkbox is checked.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-chest-configuration.png">

In the Arithmetic combinator, set the Input (The first box under Input) and Output to "Each". Then set the Constant number to -1. Finally wire the output to the Requester mooring (The side with an arrow pointing *out* when in Alt-mode). The wire color makes no difference.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-arithmetic-combinator-configuration.png">

Wire the Constant combinator to the requester mooring, the color makes no difference. Then add the items you wish to request.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-constant-combinator-configuration.png">

### Refueler mooring

Refuelers require no signals, so the easiest setup is to simply insert fuel into the Refueler mooring.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/refueler-setup.png">

### Drones

Once the moorings are setup, simply place a Cargo drone, give it a bit of starting fuel, and watch it automatically start ferrying cargo.
