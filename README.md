# 0xShip
On-chain Battleship Game

- [Deployed Contract](https://goerli.etherscan.io/address/0x9648cDC5D3D17A7DEc035ac2d0d943b511ECf8F6)
- Frontend: [0xship.vercel.app](https://0xship.vercel.app/)

![Demo of the game UI](https://github.com/ilamanov/0xShip/blob/main/demo-image.png?raw=true)


### Here is how the game works at a high level:
 1. A challenger submits a Challenge py picking a general (the contract
    that has playing logic) and the fleet.
 2. Anyone can then then accept this challenge. (To accept the challenge
    you need to provide your own general and fleet). Accepting the
    challenge locks a battle between the challenger and the caller.
 3. At this point, nothing can be modified about the game. Next step is
    to reveal your fleet and start the battle. Both of these operations
    can be performed by a 3rd party facilitator that will be compensated
    by a percentage of game bid.

 (Fleet reveal is necessary because fleet is initially obfuscated by
 providing only the hash of the fleet. This is so that opponents don't
 know each other's fleet before the battle begins).

