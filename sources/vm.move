module vm::vm {
    use sui::object::{Self, UID, uid_to_address};
    use sui::vec_map::{Self};
    use sui::tx_context::TxContext;
    use sui::sui::{SUI};
    use sui::coin::{Coin, Self};
    use sui::event;
    use sui::transfer;
    use std::vector;

    use vm::state::{State, Self};
    use vm::account::{Account, Self};

    const EAmountInvalid: u64 = 0;
    const ENonceInvalid: u64 = 1;
    const EToInvalid: u64 = 2;

    // state wrapper
    struct StateV1 has key, store {
        id: UID,
        state: State,
    }
    public fun state(state: &StateV1): &State {
        &state.state
    }
    fun state_mut(state: &mut StateV1): &mut State {
        &mut state.state
    }

    struct Init has copy, drop {
        state_addr: address
    }

    struct GetAccount has copy, drop {
        addr: vector<u8>,
        balance: u64,
        nonce: u128,
        code: vector<u8>,
    }

    struct CallResult has copy, drop {
        status: u128,
        state_addr: address,
        data: vector<u8>,
    }

    public entry fun create(ctx: &mut TxContext) {
        let state = state::create(ctx);
        let state_v1 = StateV1 {
            id: object::new(ctx),
            state: state,
        };
        let state_addr = uid_to_address(&state_v1.id);
        transfer::share_object(state_v1);
        event::emit(Init {
            state_addr: state_addr,
        });
    }

    public fun pool_balance(_state: &StateV1): u64 {
        let state = state(_state);
        let pool = state::pool(state);
        let val = coin::value(pool);
        val
    }

    public entry fun get_account(_state: &StateV1, addr: vector<u8>) {
        let _ = state(_state);
        // let accounts = state::accounts(state);
        // let acct = vec_map::get(accounts, &addr);
        event::emit(GetAccount {
            addr: addr,
            balance: 2,
            nonce: 3,
            code: vector::empty(),
        });
    }

    public fun account(_state: &StateV1, addr: &vector<u8>): &Account {
        let state = state(_state);
        let accounts = state::accounts(state);
        let acct = vec_map::get(accounts, addr);
        acct
    }

    public fun deposit(_state: &mut StateV1, addr: vector<u8>, coin: Coin<SUI>) {
        let val = coin::value(&coin);

        let state = state_mut(_state);
        let accounts = state::accounts_mut(state);
        if (vec_map::contains(accounts, &addr)) {
            let acct = vec_map::get_mut(accounts, &addr);
            let current_balance = account::balance(acct);
            account::set_balance(acct, current_balance + val);
        } else {
            let acct = account::create(addr, val, 0, vector::empty());
            vec_map::insert(accounts, addr, acct);
        };

        let pool = state::pool_mut(state);
        coin::join(pool, coin);
    }

    public fun withdraw(_state: &mut StateV1, nonce: u128, from: vector<u8>, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        let state = state_mut(_state);
        let accounts = state::accounts_mut(state);
        let acct = vec_map::get_mut(accounts, &from);
        
        let current_nonce = account::nonce(acct);
        assert!(current_nonce == nonce, ENonceInvalid);
        account::nonce_increment(acct);

        let current_balance = account::balance(acct);
        assert!(current_balance >= amount, EAmountInvalid);
        account::set_balance(acct, current_balance - amount);

        let pool = state::pool_mut(state);
        coin::take(coin::balance_mut(pool), amount, ctx)
    }

    #[test_only]
    public entry fun edit_account(_state: &mut StateV1, addr: vector<u8>, nonce: u128, balance: u64, code: vector<u8>) {
        let state = state_mut(_state);
        let accounts = state::accounts_mut(state);

        if (vec_map::contains(accounts, &addr)) {
            let acct = vec_map::get_mut(accounts, &addr);
            account::set_balance(acct, balance);
            account::set_nonce(acct, nonce);
            account::set_code(acct, code);
        } else {
            let acct = account::create(addr, balance, nonce, code);
            vec_map::insert(accounts, addr, acct);
        }
    }

    public entry fun call(_state: &StateV1, tx: vector<u8>) {
        event::emit(CallResult{
            status: 0,
            state_addr: uid_to_address(&_state.id),
            data: tx,
        })
    }

    public fun transfer(_state: &mut StateV1, nonce: u128, from: vector<u8>, to: vector<u8>, amount: u64) {
        let state = state_mut(_state);
        let accounts = state::accounts_mut(state);
        let from_acct = vec_map::get_mut(accounts, &from);

        assert!(vector::length(&to) == 20, EToInvalid);

        let current_nonce = account::nonce(from_acct);
        assert!(current_nonce == nonce, ENonceInvalid);
        account::nonce_increment(from_acct);

        let current_balance = account::balance(from_acct);
        assert!(current_balance >= amount, EAmountInvalid);
        account::set_balance(from_acct, current_balance - amount);

        if (vec_map::contains(accounts, &to)) {
            let to_acct = vec_map::get_mut(accounts, &to);
            let current_balance = account::balance(to_acct);
            account::set_balance(to_acct, current_balance + amount);
        } else {
            let to_acct = account::create(to, amount, 0, vector::empty());
            vec_map::insert(accounts, to, to_acct);
        }
    }

    // public fun call(_state: &StateV1, nonce: u128, from: vector<u8>, to: vector<u8>, amount: u128, data: vector<u8>) {
    //     let _ = nonce;
    //     let _ = from;
    //     let _ = to;
    //     let _ = amount;
    //     let _ = data;
    //     event::emit(CallResult{
    //         status: 0,
    //         state_addr: uid_to_address(&_state.id),
    //         data: vector::empty(),
    //     })
    // }
}

#[test_only]
module vm::test_vm {
    use sui::sui::{SUI, Self};
    use sui::coin::{Coin, Self, mint_for_testing as mint};
    use sui::test_scenario::{Self as test, next_tx, ctx};

    use vm::vm::{Self, StateV1};
    use vm::state::{Self};
    use vm::account::{Self};

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
    public fun test_deposit_transfer_withdraw() {
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
            let wrapper = test::take_shared<StateV1>(scenario);
            let state = test::borrow_mut(&mut wrapper);

            let amount = 100;
            let coin = test::take_owned<Coin<SUI>>(scenario);
            coin::split(&mut coin, amount, ctx(scenario));

            vm::deposit(state, a_evm, coin);
            let balance = vm::pool_balance(state);
            assert!(balance == 900, 0);

            let acct = vm::account(state, &a_evm);
            assert!(account::balance(acct) == 900, 0);
            assert!(account::nonce(acct) == 0, 0);

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
            let wrapper = test::take_shared<StateV1>(scenario);
            let state_v1 = test::borrow_mut(&mut wrapper);

            let coin = test::take_owned<Coin<SUI>>(scenario);
            let val = coin::value(&coin);
            assert!(val == 10, 0);

            let amount = 1;
            coin::split(&mut coin, amount, ctx(scenario));

            vm::deposit(state_v1, b_evm, coin);
            let balance = state::pool_balance(vm::state(state_v1));
            assert!(balance == 909, 0);

            let acct = vm::account(state_v1, &a_evm);
            assert!(account::balance(acct) == 900, 0);
            assert!(account::nonce(acct) == 0, 0);

            let acct = vm::account(state_v1, &b_evm);
            assert!(account::balance(acct) == 9, 0);
            assert!(account::nonce(acct) == 0, 0);

            test::return_shared(scenario, wrapper);
        };

        // transfer
        next_tx(scenario, &a); {
            let wrapper = test::take_shared<StateV1>(scenario);
            let state_v1 = test::borrow_mut(&mut wrapper);

            vm::transfer(state_v1, 0, a_evm, b_evm, 1);
            vm::transfer(state_v1, 1, a_evm, b_evm, 1);
            vm::transfer(state_v1, 0, b_evm, a_evm, 1);

            let balance = vm::pool_balance(state_v1);
            assert!(balance == 909, 0);

            let acct = vm::account(state_v1, &a_evm);
            assert!(account::balance(acct) == 899, 0);
            assert!(account::nonce(acct) == 2, 0);

            let acct = vm::account(state_v1, &b_evm);
            assert!(account::balance(acct) == 10, 0);
            assert!(account::nonce(acct) == 1, 0);

            test::return_shared(scenario, wrapper);
        };

        // a withdraws 100
        next_tx(scenario, &a); {
            let wrapper = test::take_shared<StateV1>(scenario);
            let state_v1 = test::borrow_mut(&mut wrapper);

            let coin_withdrawn = vm::withdraw(state_v1, 2, a_evm, 100, ctx(scenario));
            let val = coin::value(&coin_withdrawn);
            assert!(val == 100, 0);

            let balance = vm::pool_balance(state_v1);
            assert!(balance == 809, 0);

            let acct = vm::account(state_v1, &a_evm);
            assert!(account::balance(acct) == 799, 0);
            assert!(account::nonce(acct) == 3, 0);

            let acct = vm::account(state_v1, &b_evm);
            assert!(account::balance(acct) == 10, 0);
            assert!(account::nonce(acct) == 1, 0);

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