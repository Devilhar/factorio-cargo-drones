## Example Setup

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

### Cheat sheet blueprints

Here is a blueprint book with all setups described above:

```0eNq1VlFv2jAQ/iuW9zY5FQ4wrUh76tP2VG1PU1UhkxxgLYlT24Giiv++OychQKCAqgoJYsd89919n+1747OsgtLqwk9nxvzjk7duxvHJ096Q3qXgEqtLr03BJ/wPFCnzS2CJKTwUnpl5PVyC88ybMCitWekUrGAKV+vCgfXMeav0YulxjMu0v+OCa0SpQzq9KFRG8QqVAwZKlF2YKLWmgKjFi3JjkNaCb/GvRQqvfCK3z4IjD+011EhhsJkWVT4DiwtEi+g8QBYFohi6NE7XOb1xxInl3VjwDZ9EEp+2W9EDindAdUI410eJD1AET7WFpF4g4xOgQ3FVvv1Ao6NAJIc12XQGS7XSxtI6CyqdNjphbeYqc7Cleq2RFRXrSQophkI+45z2kCONTnrBMzUDlIQ/NnRYR2cF1gU242/x/ej+fvw9HoxHI9kJM6Bs3zHSg8nBsbX2S+Z0XmbAiAGz8FKRkxz4qrxjf03FElUwlaZMOZarYtMucTSxwfdrVZCpgvMe0E+exonJZ7pQ3qAJZxU6c6kd29Gh1210vzasVBZVQEkDKLwqInSDQRtKn+vQQSP58CMGlfsgB/4cvWtPZbFWWCKdRF1pT+HX6IMe+mmLdrBk1DRAOXox19b5aVd0vymJxkpbX+FMV7KwIgKVLKnmDgiGsIINaH8IbkqwqrHdV/yrqXxZ3Qy+PVXzkbjODv1CDQ+FuH7/9kmMOxJN3hc0akPHZ0O7Wjd3+IzebU0tUKGMNszRbENkt6GiARJ4waoiYZwvjM1DhZEgrSGCE/4jTFSkl5SUYIMXn8CTN+LF22f8nD72xNMQf0fhCb/FuD4Ku9MgJNe4Q6edMb5I9pNOK7zIGq3prEjPJR7tvE31vMw+iNyEbUQW7cOES9knUmeL5zJuKDXL6JUcDPgezgH9+DJ9+Wn04z6Rc/Tfv5d+t9vspotJXriYflXOtz3LvILsqHGhW6YJd9MFQVAfux3On+rDthsYXtV0xOIKiv0g3/aCXFSGsG4UJj4FGoUWtUN+IMYsMKaeU2GnsASg2Ed9at1TPO460Z1Z6qZ0xzA0GlcLeaycwjqvYNqdV2fT3P4H61TZig==```
