# EVM on Sui

## Test on Local network
https://docs.sui.io/devnet/build/cli-client#genesis
```
sui genesis
```
### show addresses
```
$ sui client addresses
Showing 5 results.
0x128f64b1855c9546a7ae27318241796e1edb722a
0x4c708ee9a8962d980f28ebab237b4136bb04018b
0x6cd283a42513924fe1aebd78d66b54bf541cb8fc
0x93bcc7ac60ee6362da26f1b3af5fc8f7dd385a71
0xe9ec23c39597c139e60b635e681d66982b3fb990
```
### show active address
```
$ sui client active-address
0x128f64b1855c9546a7ae27318241796e1edb722a
```
### owned gas
```
$ sui client gas
                 Object ID                  |  Gas Value
----------------------------------------------------------------------
 0x170f7dabf9f3349af8f308a3e3706b74f6837d8d |  100000000
 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 |  100000000
 0x6f30aac6ae14ec9e22dc2fcfd7782ba1ce4cb6d9 |  100000000
 0x8155fea0da09e6d3fb66354e3178fbfe184acb3a |  100000000
 0xcf1438d8f4fc26906cef10ca596c837f99c95a66 |  100000000
```

### tranfser SUI
https://docs.sui.io/devnet/build/cli-client#calling-move-code
```
$ sui client objects --address 0x128f64b1855c9546a7ae27318241796e1edb722a
                 Object ID                  |  Version   |                    Digest                    |   Owner Type    |               Object Type
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
 0x170f7dabf9f3349af8f308a3e3706b74f6837d8d |     0      | FzSBEG6sZHumv82D9QOCw1UvJUSHDXn95CKDdFL10rg= |  AddressOwner   |      0x2::coin::Coin<0x2::sui::SUI>
 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 |     0      | EEcs1FdOsC6ZFvo6Cwcqr87+ZE/8/rHgDxFIh0KioXk= |  AddressOwner   |      0x2::coin::Coin<0x2::sui::SUI>
 0x6f30aac6ae14ec9e22dc2fcfd7782ba1ce4cb6d9 |     0      | 9UsSfpI67uV0tjjraHN0D9t+Hmy10Q0OJbuRVnHdvv8= |  AddressOwner   |      0x2::coin::Coin<0x2::sui::SUI>
 0x8155fea0da09e6d3fb66354e3178fbfe184acb3a |     0      | KzQLilVN5gV1fhyH3GwOTVPxXiK97jWdRBi9aHxpQTU= |  AddressOwner   |      0x2::coin::Coin<0x2::sui::SUI>
 0xcf1438d8f4fc26906cef10ca596c837f99c95a66 |     0      | Pbdf4N3ZMvU0qorrwJE66z8ewjgca46rjLcrnnyoqe0= |  AddressOwner   |      0x2::coin::Coin<0x2::sui::SUI>
Showing 5 results.
```
```rs
// module entry function signature
public entry fun transfer(c: coin::Coin<SUI>, recipient: address) {
    transfer::transfer(c, Address::new(recipient))
}
```
#### arguments
- **c**: `coin::Coin<SUI>` object, which is `0x170f7dabf9f3349af8f308a3e3706b74f6837d8d`, the first object in the previous result in our case.
- **recipient**: any `address`. Let's set it `0x4c708ee9a8962d980f28ebab237b4136bb04018b`, the second address listed by `sui client addresses`.
```
$ sui client call --function transfer --module sui --package 0x2 --args 0x170f7dabf9f3349af8f308a3e3706b74f6837d8d 0x4c708ee9a8962d980f28ebab237b4136bb04018b --gas-budget 1000
```
#### result
```
----- Certificate ----
Transaction Hash: jTpJuqDAImY9z+U+s5s2QyiYGGGOqZxTHQaURu7OCj4=
Transaction Signature: AA==@+jfnUBqOs6YNk8FiBSW2j2IGTt81Rj+vGPKdw15089YGn6JcB+07llYmaEgKIILye93tlFcatLnyAqr8cP3ECA==@TtVsIwfMrPRmPcB8vYp3LFHv5Sp3AD9IBtpBJpK8mQ0=
Signed Authorities Bitmap: RoaringBitmap<[0, 1, 3]>
Transaction Kind : Call
Package ID : 0x2
Module : sui
Function : transfer
Arguments : ["0x170f7dabf9f3349af8f308a3e3706b74f6837d8d", "0x4c708ee9a8962d980f28ebab237b4136bb04018b"]
Type Arguments : []
----- Transaction Effects ----
Status : Success
Mutated Objects:
  - ID: 0x170f7dabf9f3349af8f308a3e3706b74f6837d8d , Owner: Account Address ( 0x4c708ee9a8962d980f28ebab237b4136bb04018b )
  - ID: 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 , Owner: Account Address ( 0x128f64b1855c9546a7ae27318241796e1edb722a )
```
check balance
```
$ sui client gas
                 Object ID                  |  Gas Value
----------------------------------------------------------------------
 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 |  99999516
 0x6f30aac6ae14ec9e22dc2fcfd7782ba1ce4cb6d9 |  100000000
 0x8155fea0da09e6d3fb66354e3178fbfe184acb3a |  100000000
 0xcf1438d8f4fc26906cef10ca596c837f99c95a66 |  100000000
```

## Publishing EVM package
https://docs.sui.io/devnet/build/cli-client#publish-packages

Execute the following command in the directory where `Move.toml` file is located.
```
sui client publish --path ./ --gas-budget 30000
```
```
----- Certificate ----
Transaction Hash: E6/DdrK/Ahf0/9pLy7S21eJhuTJNQFrjf+m52MAxQxA=
Transaction Signature: AA==@dHWpfEuyFwvmmtHDVgBl36NWnXn43nSCCHW2VnZNZ/Yfan9grOTBiuLBwJOa+cxnNehsJuQkbasXt5zQbXLHBQ==@TtVsIwfMrPRmPcB8vYp3LFHv5Sp3AD9IBtpBJpK8mQ0=
Signed Authorities Bitmap: RoaringBitmap<[0, 2, 3]>
Transaction Kind : Publish
----- Transaction Effects ----
Status : Success
Created Objects:
  - ID: 0xe0a854a72ebc77fcb532de742455e050fdd1166b , Owner: Immutable
Mutated Objects:
  - ID: 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 , Owner: Account Address ( 0x128f64b1855c9546a7ae27318241796e1edb722a )
----- Publish Results ----
The newly published package object ID: 0xe0a854a72ebc77fcb532de742455e050fdd1166b

Updated Gas : Coin { id: 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0, value: 99998415 }
```
#### view published object
```
sui client object --id 0xe0a854a72ebc77fcb532de742455e050fdd1166b
----- Move Package (0xe0a854a72ebc77fcb532de742455e050fdd1166b[1]) -----
Owner: Immutable
Version: 1
Storage Rebate: 0
Previous Transaction: E6/DdrK/Ahf0/9pLy7S21eJhuTJNQFrjf+m52MAxQxA=
----- Data -----
Modules: ["account", "state", "vm"]
```
### create EVM
- module: `vm`
- package: `0xe0a854a72ebc77fcb532de742455e050fdd1166b`
- func signature: `public entry fun create(ctx: &mut TxContext)`
```
sui client call --function create --module vm --package 0xe0a854a72ebc77fcb532de742455e050fdd1166b --gas-budget 1000
```
```
----- Certificate ----
Transaction Hash: aatl3Oz6LyTaJMmSMjxsafMaB/UGt7JgYqyyPkxshtk=
Transaction Signature: AA==@qIHH95aBeHYP+OljgMJA9khtX0/3AX+S3J6dzzwToZtN5A6tariXgYOxNiF28QcRCVgUCNG+S4na6eVwQVAMAQ==@TtVsIwfMrPRmPcB8vYp3LFHv5Sp3AD9IBtpBJpK8mQ0=
Signed Authorities Bitmap: RoaringBitmap<[0, 1, 3]>
Transaction Kind : Call
Package ID : 0xe0a854a72ebc77fcb532de742455e050fdd1166b
Module : vm
Function : create
Arguments : []
Type Arguments : []
----- Transaction Effects ----
Status : Success
Created Objects:
  - ID: 0x493116f6f43be2d1309ec744e0761af7f7fe7aec , Owner: Shared
Mutated Objects:
  - ID: 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 , Owner: Account Address ( 0x128f64b1855c9546a7ae27318241796e1edb722a )
```
`0x493116f6f43be2d1309ec744e0761af7f7fe7aec` is an EVM state object (type = `vm::StateV1`) we refer to in the following interaction with EVM.
```
$ sui client object --id 0x493116f6f43be2d1309ec744e0761af7f7fe7aec
----- Move Object (0x493116f6f43be2d1309ec744e0761af7f7fe7aec[1]) -----
Owner: Shared
Version: 1
Storage Rebate: 18
Previous Transaction: aatl3Oz6LyTaJMmSMjxsafMaB/UGt7JgYqyyPkxshtk=
----- Data -----
type: 0xe0a854a72ebc77fcb532de742455e050fdd1166b::vm::StateV1
id: 0x493116f6f43be2d1309ec744e0761af7f7fe7aec
state:
  type: 0xe0a854a72ebc77fcb532de742455e050fdd1166b::state::State
  accounts:
    type: 0x2::vec_map::VecMap<vector<u8>, 0xe0a854a72ebc77fcb532de742455e050fdd1166b::account::Account>
    contents: []
  height: 0
  id: 0x0d404544665890018dc7142993fd942380f2e43b
  pool:
    type: 0x2::coin::Coin<0x2::sui::SUI>
    balance: 0
    id: 0x1eeb1286f53b7ccb31b605371157974e458dc43c
```
### call EVM
- module: `vm`
- package: `0xe0a854a72ebc77fcb532de742455e050fdd1166b`
- func signature: `public entry fun call(_state: &StateV1, tx: vector<u8>)`
- args
  - _state: `0x493116f6f43be2d1309ec744e0761af7f7fe7aec`, `vm::StateV1` object we created in `create` section.
  - tx: any message. we set `hello` in our example.
```
sui client call --function call --module vm --package 0xe0a854a72ebc77fcb532de742455e050fdd1166b --args 0x493116f6f43be2d1309ec744e0761af7f7fe7aec hello --gas-budget 1000
```
```
----- Certificate ----
Transaction Hash: vpYwwqa7De8wx2b/5Zwp73yL2+p4H7eCHBd4sq4bRpw=
Transaction Signature: AA==@8PnDzXHIUhfmLYhJAyQvXxbPphQhFWuRXo68flhvvkfGwJlUJYQwxxqyRieGIt6FlEiZWsjeEC2RwQ6wNmoAAQ==@TtVsIwfMrPRmPcB8vYp3LFHv5Sp3AD9IBtpBJpK8mQ0=
Signed Authorities Bitmap: RoaringBitmap<[0, 1, 2]>
Transaction Kind : Call
Package ID : 0xe0a854a72ebc77fcb532de742455e050fdd1166b
Module : vm
Function : call
Arguments : ["0x493116f6f43be2d1309ec744e0761af7f7fe7aec", "hello"]
Type Arguments : []
----- Transaction Effects ----
Status : Success
Mutated Objects:
  - ID: 0x493116f6f43be2d1309ec744e0761af7f7fe7aec , Owner: Shared
  - ID: 0x6c320f11da70f65d2a05f51968ca1c86ea2816b0 , Owner: Account Address ( 0x128f64b1855c9546a7ae27318241796e1edb722a )
```
## Web3 API
https://ethereum.org/en/developers/docs/apis/json-rpc/
eth_getBlockByHash
eth_getBlockByNumber
eth_getBlockTransactionCountByHash
eth_getBlockTransacttionCountByNumber
eth_getUncleCountByBlockHash
eth_getUncleCountByBlockNumber
eth_protocolVersion
eth_chainId
eth_coinbase
eth_accounts
eth_blockNumber
eth_call
eth_estimateGas
eth_gasPrice
eth_feeHistory
eth_newFilter
eth_newBlockFilter
eth_newPendingTransactionFilter
eth_uninstallFFilter
eth_getFilterChanges
eth_getFilterLogs
eth_getLogs
eth_mining
eth_hashrate
eth_getWork
eth_submitWork
eth_submitHashrate
eth_sign
eth_signTransaction
eth_getBlaance
eth_getStorageAt
eth_getTransactionCount
eth_getCode
eth_sendTransaction
eth_sendRawTransaction
eth_getTransacttionByHash
eth_getTransactionByBlockHashAndIndex
eth_getTranssactionByBlockNumberAndIndex
eth_getTransactionReceipt

## Opcodes
ADD, MUL, SUB, DIV, SDIV, MOD, SMOD, ADDMOD, MULMOD, EXP, SIGNEXTEND
LT, GT, SLT, SGT, EQ, ISZERO
AND, OR, XOR, NOT, BYTE, SHL, SHR, SAR
POP, PUSHn, DUPn, SWAPn,
JUMP, JUMPI, JUMPDEST
MLOAD, MSTORE, MSTORE8, MSIZE
SLOAD, SSTORE
CALL, STATICCALL, DELEGATECALL, CALLCODE
CREATE, CREATE2, SELFDESTRUCT
REVERT
RETURN, RETURNDATACOPY
CALLVALUE, CALLDATALOAD, CALLDATASIZE,
CALLER, ORIGIN, ADDRESS, BALANCE, SELFBALANCE, GAS, GASPRICE, CHAINID
SHA3
EXTCODESIZE, EXTCODECOPY, EXTCODEHASH
COINBASE, BLOCKHASH
BASEFEE, PC, INVALID,
LOGn
