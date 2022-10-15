# Proxy Service


# Proxy Server
Proxy server submits two transactions to Sui blockchain for every single EVM transaction:
1. CreateAccountTx
2. ExecuteEvmTx 

## CreateAccountTx transaction
- signer: `FeePayer`

For every EVM request, we create new Sui account called `CallerAccount` with an initial balance set by `gasPrice*gasLimit - <FEE_OF_CreateAccountTx>`. This initial balance is sent from User's EVM account in our EVM interpreter state. And `CallerAccount` will pay fee for the following transaction that executes EVM call. 

 The reason why `FeePayer` account doesn't directly call EVM is to prevent an expensive execution from draining fee pool balance. The fee amount paid for this transaction will be returned to `FeePayer` in **ExecuteEvmTx** transaction. We must make sure that failing **CreateAccountTx** is not broadcasted to blockchain. Like Ethereum, a failed transaction will cost fee and such transaction itself could become an attack to the fee pool.
## ExecuteEvmTx transaction
- signer: `CallerAccount`

`CallerAccount` calls EVM interpreter module which executes EVM bytecode specified in an user-submitted EVM transaction. This transaction might be expensive. But, the maximum gas that can be paied is capped by the balance of `CallerAccount`. Therefore a maliciously expensive EVM will not drain fund from `FeePayer`.

## Intrinsic Fee
Every interaction with EVM Interpreter will cost additional fee on top of blockchain fee. This is like a "tax" to EVM users. This ensures the protocol subtainability. 

# Diagram

```mermaid
sequenceDiagram
    participant Alice as Alice (User)
    participant API as API Provider
    participant Payer as Fee Payer
    participant Sui as Sui Blockchain
    participant EVM as EVM interpreter

    Alice->>API: EVM transaction
    Note right of Alice: [Transaction]<br/>from = alice<br/>to = bob<br/>gasLimit = gL<br/>gasPrice = gP<br/>value = v<br/>data = d<br/>nonce = n<br/>signature = sig
    API->>Payer: Queue request

    Payer->>EVM: Fetch state of ' alice '
    EVM->>Payer: balanceAlice, nonceAlice
    
    Payer->>Payer: Require
    Note right of Payer: [Requre]<br/>balanceAlice >= gP * gL + v<br/>nonceAlice == n

    Payer->>Payer: Generate secret ' s ' as a secret key of ed25519

    Note right of Payer: gL_create = MAX_GAS_AMOUNT_FOR_CREATE_ACCOUNT
    Note right of Payer: gL_call = gL - gL_create

    Note over Payer, EVM: BEGIN CreateAccountTx
    rect rgb(191, 223, 255)
        Payer->>Payer: Create Sui Transaction
        Note right of Payer: [Transaction]<br/>amount = 0<br/>gas_price = gP<br/>max_gas_amount = gL_create<br/>[Call Arguments]<br/>created_address = X<br/>create_fee = gP * gL_create<br/>initial_balance = gP * gL_call
        Payer->>Payer: Sign Sui Transaction with FeePayer's secret
        Payer->>EVM: Sui Call
        Note right of EVM: [Execution]<br/>send gP * gL_call from alice to ' X '<br/>send gP * gL_create from alice to FeePayer
        EVM->>Sui: OK
        Sui->>Payer: OK
        Note right of Payer: [Account ' X ']<br/>balance = gP * gL_call
    end
    Note over Payer, EVM: END CreateAccountTx

    Note over Payer, EVM: BEGIN ExecuteEvmTx
    rect rgb(191, 223, 255)
        Payer->>Payer: Create Sui Transaction
        Note right of Payer: [Transaction]<br/>from = PayerAddress<br/>to = EvmInterpreter<br/>amount = 0<br/>gas_price = gP<br/>max_gas_amount = gL_call<br/>[Call Arguments]<br/>from: alice<br/>to: bob<br/>value=v<br/>calldata = d<br/>nonce = n<br/>signature = sig
        Payer->>Payer: Sign Sui Transaction with ' s '
        Payer->>EVM: Sui Call 
        Note right of EVM: [Execution]<br/>check signature<br>interpret EVM transaction
        EVM-->>Payer: Sui Response ' r '
    end
    Note over Payer, EVM: END ExecuteEvmTx

    Payer->>API: Return ' r '
    Note right of API: r is converted to EVM compatible format
    API-->>Alice: EVM Response
```
