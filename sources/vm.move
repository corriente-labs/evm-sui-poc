module vm::vm {
    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::TxContext;
    use sui::sui::{SUI};
    use sui::coin::{Coin, Self};
    use sui::event;
    use sui::transfer;
    use std::vector;

    const EAmountInvalid: u64 = 0;
    const ENonceInvalid: u64 = 1;
    const EToInvalid: u64 = 2;

    struct Account has store {
        addr: vector<u8>,
        balance: u64,
        nonce: u128,
        code: vector<u8>,
    }
    
    struct State has key, store {
        id: UID,
        accounts: VecMap<vector<u8>, Account>,
        height: u128,
        pool: Coin<SUI>,
    }

    struct GetAccount has copy, drop {
        addr: vector<u8>,
        balance: u64,
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
            pool: coin::zero(ctx),
        };
        transfer::share_object(state);
    }

    public fun pool_balance(_state: &State): u64 {
        let val = coin::value(&_state.pool);
        val
    }

    public entry fun get_account(_state: &State, addr: vector<u8>) {
        let acct = vec_map::get(&_state.accounts, &addr);
        event::emit(GetAccount {
            addr: acct.addr,
            balance: acct.balance,
            nonce: acct.nonce,
            code: acct.code,
        });
    }

    public fun account(_state: &State, addr: &vector<u8>): &Account {
        let acct = vec_map::get(&_state.accounts, addr);
        acct
    }

    public fun deposit(_state: &mut State, addr: vector<u8>, coin: Coin<SUI>) {
        let val = coin::value(&coin);
        if (vec_map::contains(&_state.accounts, &addr)) {
            let acct = vec_map::get_mut(&mut _state.accounts, &addr);
            acct.balance = val;
            acct.nonce = 0;
            acct.code = vector::empty();
        } else {
            let acct = Account {
                addr: addr,
                balance: val,
                nonce: 0,
                code: vector::empty(),
            };
            vec_map::insert(&mut _state.accounts, addr, acct);
        };

        coin::join(&mut _state.pool, coin);
    }

    public entry fun withdraw(_state: &mut State, nonce: u128, from: vector<u8>, to: address, amount: u64, ctx: &mut TxContext) {
        let acct = vec_map::get_mut(&mut _state.accounts, &from);
        assert!(acct.nonce == nonce, ENonceInvalid);
        assert!(acct.balance >= amount, EAmountInvalid);
        
        acct.balance = acct.balance - amount;
        acct.nonce = acct.nonce + 1;

        coin::split_and_transfer(&mut _state.pool, amount, to, ctx);
    }

    #[test_only]
    public entry fun edit_account(_state: &mut State, addr: vector<u8>, nonce: u128, balance: u64, code: vector<u8>) {
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

    public entry fun transfer(_state: &mut State, nonce: u128, from: vector<u8>, to: vector<u8>, amount: u64) {
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

#[test_only]
module vm::test_vm {
    use sui::sui::{SUI, Self};
    use sui::coin::{Coin, Self, mint_for_testing as mint};
    use sui::test_scenario::{Self as test, next_tx, ctx};

    #[test]
    public fun test_transfer() {
        let sender = @0x1111;
        let scenario = test::begin(&sender);
        let a = @0x000a;
        let b = @0x000b;

        next_tx(&mut scenario, &sender); {
            let coin = mint<SUI>(100, ctx(&mut scenario));
            sui::transfer(coin, sender);
        };

        next_tx(&mut scenario, &sender); {
            let coin = test::take_owned<Coin<SUI>>(&mut scenario);

            let val = coin::value(&coin);
            assert!(val == 100, 0);

            coin::split_and_transfer(&mut coin, 10, a, ctx(&mut scenario));
            let val = coin::value(&coin);
            assert!(val == 90, 0);

            test::return_owned(&mut scenario, coin);
        };
        next_tx(&mut scenario, &sender); {
            let coin = test::take_owned<Coin<SUI>>(&mut scenario);

            let val = coin::value(&coin);
            assert!(val == 90, 0);

            test::return_owned(&mut scenario, coin);
        };

        next_tx(&mut scenario, &a); {
            let coin = test::take_owned<Coin<SUI>>(&mut scenario);

            let val = coin::value(&coin);
            assert!(val == 10, 0);

            coin::split_and_transfer(&mut coin, 1, b, ctx(&mut scenario));

            test::return_owned(&mut scenario, coin);
        };
        next_tx(&mut scenario, &a); {
            let coin = test::take_owned<Coin<SUI>>(&mut scenario);

            let val = coin::value(&coin);
            assert!(val == 9, 0);

            test::return_owned(&mut scenario, coin);
        };

        next_tx(&mut scenario, &b); {
            let coin = test::take_owned<Coin<SUI>>(&mut scenario);

            let val = coin::value(&coin);
            assert!(val == 1, 0);

            test::return_owned(&mut scenario, coin);
        };
    }

    // #[test]
    // public fun test_basic() {
    //     use sui::test_scenario;

    //     use sui::tx_context;
    //     use sui::transfer;
    //     use sui::object::{Self};

    //     // create a dummy TxContext for testing
    //     let ctx = tx_context::dummy();
    // }
}