## Example Setup

### Cheat sheet blueprints

Here is a blueprint book with cheat sheets:
<details>

<summary>Cheat sheet</summary>

```0eNrdWEuO4zYQvQrBLAYIJMOSrZ6xgV71KsEEaGQGCAKPYdAW2yJaEj0kZY/R8AFykFwsJ0kV9bMstWXNJ4tsbIkqvfqw6rFKL3QdZ3ynRGpWaymf6fylXtF0vji7xWch1xsldkbIlM7pB240MREnwvBEE7ZnImbrGO5Tu7xTci9CrgjTJJbpFv+FeQOSa7nnhBHNDQgqriMZhyPqULGRaa5Wi23KYtSZsoSDsg1TW+mGSqbcLYHdREowbUtP8Goa8i907p2WDuWpEUbwHMneHFdplqy5AgGnRBSp5srAmkN3UovcqRcKIJO3o8ChRzp3g1EA2KFQfJM/9/yT08L0K0xtOI/dTcS16YC9O4ftwJk4N3nbBp417YUoGiXj1ZpHbC+kQjHFWbjCB9zu7BOLNe+yYVrZEPKNVbuRyVqkzMiuSM1yvZPLOE27rSgw0ZDQ4mhcPb+DHXsSSptVnQHmuEN79kKZDFbqYFsJl7NNRHOvtWGYqP4Y75IdU9bqOf3nr78pJobMzC4zlxl2E/5peTohxAF8RICF73jO1PGWzmJiryZLeIoqEw5JlesokIvYOuXFnPrjWs1v7LldQoeI2yJSHOolkYrDDUutEygKr9WF6VB4h4Mr9LGsuDpV9mCL3ZHgzp9NZ7PgnT8OplOvLpkxZsGVMn+QCdfkIExEtEh2cW4sUfxzBmmORZztRuRPmZENSwkLQ6zzhKXHUkTjwhGeH2B3SnJ4KHaL1OnlkHWGhCA0qczBx6V2c5CkDjCC8i8MDRqRP0QcVxYlQmtwvogpYso0PhLxRHgqs21UBhuCWogO4J5CybeSz1WicIOSgKazbqbwb2AxN7g7R2mW583s0/a3Q9G0qej78E9Zz1cJqHYyGL+qW+du6+Y1bE+5bw5wTlxVbb1aWFIlnYtl+xlIAizGupYqsYTRIJt7u5BhKXljW1wFoN8B6A0D9AFwaamoHbmggmcKygXwxaYndm/zyHk3sneNe0HgX8nYsBcAs6qJ24WYyx0Hx3Pq+ZmWnD0UvDNCd4PONjcIhoXnf3S4eXCkBdXhdgeHm7OY2jW8gl9Y8776wBOpSLKEsASTmsingpCNLCmc4uYVWCKs3/zJI7/g2XMm6aDAKyXqVrHHSPSX2elMbdsFKOa2JXldvmau32+u96PM9Rvm+g1zr3cRv5eUP6iN8HraiF8zjYc/nlbkKeMx0UYxsY1wEQKEPUGhbtBpjFA/bA4oz7XJwDHgiomvTwWopHdnEGvgxvg9G/MhkgdN4AfzNBaJwB2BVMMWaoHG3J+5s3zAa2KvoYVKQzvEFebAxAdUCCEZfUo/YhuXaRQirYQ66/QOUj0X/R2DHq4Q0KO26tYgtGyLtLqVTpnzDVn+563fbX2N5zVy77u2NT1nwvuBTU6zxekBfxwGHhT9DgQoZkc4XJu5+xFYY1GocnMN96UXS5Jf5Tmdf6moj5yezIZpyxBm7EsaHCBGwA8OOAbEuGnw1acU8/1VSx4rS3T5xaRM86pinN5Siw/sqDu0F7MRLETApjj/lJjE9hqj3LZYHuwzCQMPDpiVENTg2LGV3MDokvODYEQHEF//5PCuSHJ/4Nxw2av4eTdyhTrfW2JDNx8Lj24iz0kXI7v2W1mNfbZRBEY6SBsdcY7aL5g2H5/LKd2piTHfgIre7Ux9MzFd0hADKtjzVTneX3Hz9C+tidi1```

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
