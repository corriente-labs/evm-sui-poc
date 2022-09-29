module vm::vm {
    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::TxContext;
    use sui::event;
    use sui::transfer;
    use std::vector;

    const EAmountInvalid: u64 = 0;
    const ENonceInvalid: u64 = 1;
    const EToInvalid: u64 = 2;

    struct Account has store {
        addr: vector<u8>,
        balance: u128,
        nonce: u128,
        code: vector<u8>,
    }
    
    struct State has key, store {
        id: UID,
        accounts: VecMap<vector<u8>, Account>,
        height: u128,
    }

    struct GetAccount has copy, drop {
        balance: u128,
        nonce: u128,
        code: vector<u8>,
    }

    struct CallResult has copy, drop {
        status: u128,
        data: vector<u8>,
    }

    public entry fun create(ctx: &mut TxContext) {
        let state = State {
            id: object::new(ctx),
            accounts: vec_map::empty(),
            height: 0,
        };
        transfer::share_object(state);
    }

    public entry fun get_account(_state: &State, addr: vector<u8>) {
        let acct = vec_map::get(&_state.accounts, &addr);
        event::emit(GetAccount {
            balance: acct.balance,
            nonce: acct.nonce,
            code: acct.code,
        });
    }

    public entry fun deposit(_state: &State, addr: vector<u8>) {
        let _ = addr;
    }

    public entry fun withdraw(_state: &State, from: vector<u8>, to: address) {
        let _ = from;
        let _ = to;
    }

    #[test_only]
    public entry fun edit_account(_state: &mut State, addr: vector<u8>, nonce: u128, balance: u128, code: vector<u8>) {
        if (vec_map::contains(&_state.accounts, &addr)) {
            let acct = vec_map::get_mut(&mut _state.accounts, &addr);
            acct.balance = balance;
            acct.nonce = nonce;
            acct.code = code;
        } else {
            let acct = Account {
                addr: addr,
                balance: balance,
                nonce: nonce,
                code: code,
            };
            vec_map::insert(&mut _state.accounts, addr, acct);
        }
    }

    public entry fun transfer(_state: &mut State, nonce: u128, from: vector<u8>, to: vector<u8>, amount: u128) {
        let acct = vec_map::get_mut(&mut _state.accounts, &from);

        assert!(acct.balance > amount, EAmountInvalid);
        assert!(acct.nonce == nonce, ENonceInvalid);
        assert!(vector::length(&to) == 20, EToInvalid);

        acct.balance = acct.balance - amount;
        acct.nonce = nonce + 1;

        if (vec_map::contains(&_state.accounts, &to)) {
            let to_acct = vec_map::get_mut(&mut _state.accounts, &to);
            to_acct.balance = to_acct.balance + amount;
        } else {
            let to_acct = Account {
                addr: to,
                balance: amount,
                nonce: 0,
                code: vector::empty(),
            };
            vec_map::insert(&mut _state.accounts, to, to_acct);
        }
    }

    public entry fun call(_state: &State, nonce: u128, from: vector<u8>, to: vector<u8>, amount: u128, data: vector<u8>) {
        let _ = nonce;
        let _ = from;
        let _ = to;
        let _ = amount;
        let _ = data;
        event::emit(CallResult{
            status: 0,
            data: vector::empty(),
        })
    }
}

// #[test_only]
// module vm::test_vm {
//     #[test]
//     public fun test_basic() {
//         use sui::test_scenario;

//         use sui::tx_context;
//         use sui::transfer;
//         use sui::object::{Self};

//         // create a dummy TxContext for testing
//         let ctx = tx_context::dummy();
//     }
// }