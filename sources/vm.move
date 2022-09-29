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

    public fun acct_balance(acct: &Account): u64 {
        acct.balance
    }
    public fun acct_nonce(acct: &Account): u128 {
        acct.nonce
    }
    public fun acct_code(acct: &Account): vector<u8> {
        acct.code
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

    public fun withdraw(_state: &mut State, nonce: u128, from: vector<u8>, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        let acct = vec_map::get_mut(&mut _state.accounts, &from);
        assert!(acct.nonce == nonce, ENonceInvalid);
        assert!(acct.balance >= amount, EAmountInvalid);
        
        acct.balance = acct.balance - amount;
        acct.nonce = acct.nonce + 1;

        coin::take(coin::balance_mut(&mut _state.pool), amount, ctx)
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

    use vm::vm::{Self, State};

    #[test]
    public fun test_transfer() {
        let sender = @0x1111;
        let scenario = &mut test::begin(&sender);
        let a = @0x000a;
        let b = @0x000b;

        next_tx(scenario, &sender); {
            let coin = mint<SUI>(100, ctx(scenario));
            sui::transfer(coin, sender);
        };

        next_tx(scenario, &sender); {
            let coin = test::take_owned<Coin<SUI>>(scenario);

            let val = coin::value(&coin);
            assert!(val == 100, 0);

            coin::split_and_transfer(&mut coin, 10, a, ctx(scenario));
            let val = coin::value(&coin);
            assert!(val == 90, 0);

            test::return_owned(scenario, coin);
        };
        next_tx(scenario, &sender); {
            let coin = test::take_owned<Coin<SUI>>(scenario);

            let val = coin::value(&coin);
            assert!(val == 90, 0);

            test::return_owned(scenario, coin);
        };

        next_tx(scenario, &a); {
            let coin = test::take_owned<Coin<SUI>>(scenario);

            let val = coin::value(&coin);
            assert!(val == 10, 0);

            coin::split_and_transfer(&mut coin, 1, b, ctx(scenario));

            test::return_owned(scenario, coin);
        };
        next_tx(scenario, &a); {
            let coin = test::take_owned<Coin<SUI>>(scenario);

            let val = coin::value(&coin);
            assert!(val == 9, 0);

            test::return_owned(scenario, coin);
        };

        next_tx(scenario, &b); {
            let coin = test::take_owned<Coin<SUI>>(scenario);

            let val = coin::value(&coin);
            assert!(val == 1, 0);

            test::return_owned(scenario, coin);
        };
    }

    #[test]
    public fun test_basic() {
        let sender = @0x1111;
        let scenario = &mut test::begin(&sender);

        let a = @0x000a;
        let b = @0x000b;

        let a_evm = x"ffff0000000000000000000000000000aaaaaaaa";
        let b_evm = x"ffff0000000000000000000000000000bbbbbbbb";

        next_tx(scenario, &a); {
            let coin = mint<SUI>(1000, ctx(scenario));
            sui::transfer(coin, a);
        };

        next_tx(scenario, &a); {
            vm::create(ctx(scenario));
        };

        // a deposits 900
        next_tx(scenario, &a); {
            let wrapper = test::take_shared<State>(scenario);
            let state = test::borrow_mut(&mut wrapper);

            let amount = 100;
            let coin = test::take_owned<Coin<SUI>>(scenario);
            coin::split(&mut coin, amount, ctx(scenario));

            vm::deposit(state, a_evm, coin);
            let balance = vm::pool_balance(state);
            assert!(balance == 900, 0);

            let acct = vm::account(state, &a_evm);
            assert!(vm::acct_balance(acct) == 900, 0);
            assert!(vm::acct_nonce(acct) == 0, 0);

            test::return_shared(scenario, wrapper);
        };

        // a transfers 10 to b
        next_tx(scenario, &a); {
            let coin = test::take_owned<Coin<SUI>>(scenario);

            let val = coin::value(&coin);
            assert!(val == 100, 0);

            coin::split_and_transfer(&mut coin, 10, b, ctx(scenario));
            let val = coin::value(&coin);
            assert!(val == 90, 0);
            
            test::return_owned(scenario, coin);
        };

        // b deposits 9
        next_tx(scenario, &b); {
            let wrapper = test::take_shared<State>(scenario);
            let state = test::borrow_mut(&mut wrapper);

            let coin = test::take_owned<Coin<SUI>>(scenario);
            let val = coin::value(&coin);
            assert!(val == 10, 0);

            let amount = 1;
            coin::split(&mut coin, amount, ctx(scenario));

            vm::deposit(state, b_evm, coin);
            let balance = vm::pool_balance(state);
            assert!(balance == 909, 0);

            let acct = vm::account(state, &a_evm);
            assert!(vm::acct_balance(acct) == 900, 0);
            assert!(vm::acct_nonce(acct) == 0, 0);

            let acct = vm::account(state, &b_evm);
            assert!(vm::acct_balance(acct) == 9, 0);
            assert!(vm::acct_nonce(acct) == 0, 0);

            test::return_shared(scenario, wrapper);
        };

        // transfer
        next_tx(scenario, &a); {
            let wrapper = test::take_shared<State>(scenario);
            let state = test::borrow_mut(&mut wrapper);

            vm::transfer(state, 0, a_evm, b_evm, 1);
            vm::transfer(state, 1, a_evm, b_evm, 1);
            vm::transfer(state, 0, b_evm, a_evm, 1);

            let balance = vm::pool_balance(state);
            assert!(balance == 909, 0);

            let acct = vm::account(state, &a_evm);
            assert!(vm::acct_balance(acct) == 899, 0);
            assert!(vm::acct_nonce(acct) == 2, 0);

            let acct = vm::account(state, &b_evm);
            assert!(vm::acct_balance(acct) == 10, 0);
            assert!(vm::acct_nonce(acct) == 1, 0);

            test::return_shared(scenario, wrapper);
        };

        // a withdraws 100
        next_tx(scenario, &a); {
            let wrapper = test::take_shared<State>(scenario);
            let state = test::borrow_mut(&mut wrapper);

            let coin_withdrawn = vm::withdraw(state, 2, a_evm, 100, ctx(scenario));
            let val = coin::value(&coin_withdrawn);
            assert!(val == 100, 0);

            let balance = vm::pool_balance(state);
            assert!(balance == 809, 0);

            let acct = vm::account(state, &a_evm);
            assert!(vm::acct_balance(acct) == 799, 0);
            assert!(vm::acct_nonce(acct) == 3, 0);

            let acct = vm::account(state, &b_evm);
            assert!(vm::acct_balance(acct) == 10, 0);
            assert!(vm::acct_nonce(acct) == 1, 0);

            let coin = test::take_owned<Coin<SUI>>(scenario);
            coin::join(&mut coin, coin_withdrawn);
            let val = coin::value(&coin);
            assert!(val == 190, 0);

            test::return_shared(scenario, wrapper);
            test::return_owned(scenario, coin);
        };

        next_tx(scenario, &a); {
            let coin = test::take_owned<Coin<SUI>>(scenario);
            let val = coin::value(&coin);
            assert!(val == 190, 0);
            
            test::return_owned(scenario, coin);
        };
    }
}