## Example Setup

### Cheat sheet blueprints

Here is a blueprint book with cheat sheets:
<details>

<summary>Cheat sheet</summary>

```0eNrlV82O2zYQfhWCPRQoKEOSZSdroKc9JUCBojkExcIwaIm2iEikQlJ2jIUfoA/SF+uTdEa/tmV7187mUPRii0Pqm2+G86dnusxKURip3GKp9Rc6e+4lls6eDpa4lwgbG1k4qRWd0U/CWeJSQaQTuSV8w2XGlxmsVSUujN7IRBjCLcm0WuO/dD/DyaXeCMKJFQ4OGmFTnSUjyqiMtarVWrlWPEOdiucClMXcrLWXGK2El2sNjNYennZcOXjIl1Jxp43XKqV7gFOJ+EZnwX7OqFBOOilq9GqxW6gyX8LJWcBaLdYJkXlxKqwDOoW2srb1mQKO548mjO7obDKa7PdsABN2MFJZYRzIBhiHEIwm0oi43g3CM4hjdrf5A83hkWZ41xmdLZYi5RupDR6yNRd7/Azuav3IKAfpBviseGYFEm62wstb49Ot+f6c86LO1ETEaMGBVWeMqUx5d+rE6LxhDeIC9hLZmXi4AiNX0li36OPO7Qpks5HGlSDpQ6Q64Qkep7R2ZHUJwMnHVV5wU3Ge0X/++pti6OnSFaU7jetX4VfOAogt2IgATwELWMSCOXsaV0/jOeyiylxAvNU6GuTGs6x9mNHQ79X8xr8ME3ebiip1jYAszbURsOCqMgKPwmt9OWAU3hFgCv29zfMmMGFrA1yqG5lMw4fo4WHyPvQnURT0SeljDFwpLo86F5ZspUuJlXmR1WSJEV9LSE4sHWUxIn/qksRcEZ4kWF1yrnbtEYuCHexv4XbakvTY3Bbpg4uRZYllSFrS0cHtVrvbatI7GEHFN46ERuSzzLKOUS6tBeMbnyKmVtmOyBURSpfrtHU2OLU5+kYVryHwQ0reu++veO8vVbzoTQpeb/1Ac+D/V0reGcMuO3L6PdasZNbViV7a0OjC3MNC8RXKEtDFSqJNXpWoo/L2ayUoMXkD3z/2zAAwuA0wBMD5BbdNOnhuIEEBX8bXHXdTs+hBT/rFnQ0CLgJgFn2f8MDhuhBgdV3pfqFti7gV/Kx7pjc10sD/P3fSSddJp9BJ2VNUyfAJfkEW3N1dpZJ5mROeYzwTvWqqv9Ntv6B4dQ2WTPo3fwrIB2x0BycZHriQnV7ne/TEyxm2P1A7NAHyeMikTslLdMOX6QY/im54RDc8ont9ZPmj7Ro3zSzBCzPLx9LipIGdkKxKkRHrDJfrFIXgIBxAGnVv1vpRzb2d/3LPHkdNrxm/6jMlZHcTH6qeHqm+q821uX41AGoCN91/eA7Uqz6ce+RHdAGpXEBgquIwq6ZCoO6Tr+d6qm2HZ0a6mGSEq4R0DKtR99XxchoK9SCyaKfuK2bu/wVFQ3pP```

</details>

### Provider mooring

The easiest setup is to have a chest inserting into the Provider mooring and sending it its content.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/provider-setup.png">

To wire up the signals, simply connect the chest to the mooring with either red or green wire. The color makes no difference. By default, wired chests automatically read their content, but you can make sure by opening the chest and see that the "Read content" checkbox is checked.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/provider-chest-configuration.png">

But this can result in a lot of Cargo drones getting tasked with picking up single items as they're added into the chest one by one. To counteract this, add a Decider combinator and instead wire the chest to the Decider combinator's input (The side with an arrow pointing *into it* when in Alt-mode).

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/provider-setup-decider.png">

Inside the Decider combinator, add a condition which checks if "Each" is higher than or equal to a minimum value you set. This value is the required amount of each item for them to be made available for pickup. In the example the minimum amount is 20.

Finally add an output, and set it to "Each" and check "Input count".

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/provider-decider-combinator-configuration.png">

### Requester mooring

The easiest setup is to have a Requester mooring inserting into a chest. Then have the chest send its content into an Arithmetic combinator and invert the signal, and send the inverted signal to the Requester mooring. Finally a Constant combinator with a list of the requested items wired up to the Requester mooring using the same colored wire as the Arithmetic combinator.

This makes it so the mooring will requests items missing from the chest.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-setup.png">

#### Signals

Connect the chest to the Arithmetic combinator's input (The side with an arrow pointing *into it* when in Alt-mode) with either red or green wire. The color makes no difference. Make sure its sending its content over the wire by opening the chest and see that the "Read content" checkbox is checked.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-chest-configuration.png">

In the Arithmetic combinator, set the Input (The first box under Input) and Output to "Each". Then set the Constant number to -1. Finally wire the output to the Requester mooring (The side with an arrow pointing *out* when in Alt-mode).

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-arithmetic-combinator-configuration.png">

Wire the Constant combinator to the Arithmetic combinator's Output. Then add the items you wish to request.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-constant-combinator-configuration.png">

But this can result in a lot of Cargo drones getting tasked with picking up single items as they're taken out of the chest one by one. To counteract this, add a Decider combinator and instead wire the Arithmetic combinator's Output to the Decider combinator's input (The side with an arrow pointing *into it* when in Alt-mode).

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-setup-decider.png">

Inside the Decider combinator, add a condition which checks if "Each" is higher than or equal to a minimum value you set. This value is the required amount each item need to be missing for it to be requested. In the example the minimum amount is 20.

Finally add an output, and set it to "Each" and check "Input count".

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/requester-decider-combinator-configuration.png">

### Refueler mooring

Refuelers require no signals, so the easiest setup is to simply insert fuel into the Refueler mooring.

<img src="https://raw.githubusercontent.com/devilhar/factorio-cargo-drones/main/images/refueler-setup.png">

### Drones

Once the moorings are setup, simply place a Cargo drone, give it a bit of starting fuel, and watch it automatically start ferrying cargo.
