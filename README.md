# First Sui module
- doc: https://docs.sui.io/devnet/build/move
- Don't try to build [sui](https://github.com/MystenLabs/sui) yourself.
    - Install with [this script](https://docs.sui.io/devnet/build/install#summary) instead. 
- There's Strange bug: When I have any unused imports or variables, and I run sui move build I get
Failed to verify the Move module, reason: `Sui framework version mismatch detected.Make sure that the sui command line tool and the Sui framework codeused as a dependency correspond to the same git commit`. This error goes away if I only remove the unused imports & vars XD. [link](https://discordapp.com/channels/916379725201563759/955861929346355290/1023557655308025920)

