module vm::vm {
    use sui::object::{Self, UID, uid_to_address};
    use sui::tx_context::TxContext;
    use sui::sui::{SUI};
    use sui::coin::{Coin, Self};
    use sui::event;
    use sui::transfer;
    use std::vector;

    use vm::state::{State, Self};
    use vm::account::{Account, Self};

    use vm::u160::{Big160};
    // use vm::u256::{Self, Big256};

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
        addr: Big160,
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

    public entry fun get_account(_state: &StateV1, addr: Big160) {
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

    public fun account(_state: &StateV1, addr: Big160): &Account {
        let state = state(_state);
        state::get_account(state, addr)
    }

    public fun deposit(_state: &mut StateV1, addr: Big160, coin: Coin<SUI>, ctx: &mut TxContext) {
        let val = coin::value(&coin);
        let state = state_mut(_state);

        state::deposit(state, addr, val, ctx);

        let pool = state::pool_mut(state);
        coin::join(pool, coin);
    }

    public fun withdraw(_state: &mut StateV1, addr: Big160, amount: u64, ctx: &mut TxContext): Coin<SUI> {
        let state = state_mut(_state);

        state::withdraw(state, addr, amount);

        let pool = state::pool_mut(state);
        coin::take(coin::balance_mut(pool), amount, ctx)
    }

    #[test_only]
    public entry fun edit_account(_state: &mut StateV1, addr: Big160, nonce: u128, balance: u64, code: vector<u8>, ctx: &mut TxContext) {
        let state = state_mut(_state);

        if (state::contains_account(state, addr)) {
            let acct = state::get_account_mut(state, addr);
            account::set_balance(acct, balance);
            account::set_nonce(acct, nonce);
            account::set_code(acct, code);
        } else {
            let acct = account::new(ctx, addr, balance, nonce, code);
            state::add(state, addr, acct);
        }
    }

    public entry fun call(_state: &StateV1, tx: vector<u8>) {
        event::emit(CallResult{
            status: 0,
            state_addr: uid_to_address(&_state.id),
            data: tx,
        })
    }

    public fun transfer(_state: &mut StateV1, nonce: u128, from: Big160, to: Big160, amount: u64, ctx: &mut TxContext) {
        let state = state_mut(_state);

        let acct = state::get_account_mut(state, from);
        let current_nonce = account::nonce(acct);

        assert!(current_nonce == nonce, ENonceInvalid);

        account::nonce_increment(acct);
        state::withdraw(state, from, amount);
        state::deposit(state, to, amount, ctx);
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

    use vm::u160::{Self};

    #[test]
    public fun test_transfer() {
        let sender = @0x1111;
        let scenario_val = test::begin(sender);
        let scenario = &mut scenario_val;
        let a = @0x000a;
        let b = @0x000b;

        next_tx(scenario, sender); {
            let coin = mint<SUI>(100, ctx(scenario));
            sui::transfer(coin, sender);
        };

        next_tx(scenario, sender); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);

            let val = coin::value<SUI>(&coin);
            assert!(val == 100, 0);

            let sent = coin::split(&mut coin, 10, ctx(scenario));
            sui::transfer(sent, a);

            let val = coin::value<SUI>(&coin);
            assert!(val == 90, 0);

            test::return_to_sender(scenario, coin);
        };
        next_tx(scenario, sender); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);

            let val = coin::value<SUI>(&coin);
            assert!(val == 90, 0);

            test::return_to_sender(scenario, coin);
        };

        next_tx(scenario, a); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);

            let val = coin::value<SUI>(&coin);
            assert!(val == 10, 0);

            let sent = coin::split(&mut coin, 1, ctx(scenario));
            sui::transfer(sent, b);

            test::return_to_sender(scenario, coin);
        };
        next_tx(scenario, a); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);

            let val = coin::value<SUI>(&coin);
            assert!(val == 9, 0);

            test::return_to_sender(scenario, coin);
        };

        next_tx(scenario, b); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);

            let val = coin::value<SUI>(&coin);
            assert!(val == 1, 0);

            test::return_to_sender(scenario, coin);
        };

        test::end(scenario_val);
    }

    #[test]
    public fun test_deposit_transfer_withdraw() {
        let sender = @0x1111;
        let scenario_val = test::begin(sender);
        let scenario = &mut scenario_val;

        let a = @0x000a;
        let b = @0x000b;

        let a_evm = x"ffff0000000000000000000000000000aaaaaaaa";
        let a_evm = u160::from_vec(&a_evm, 0, 20);

        let b_evm = x"ffff0000000000000000000000000000bbbbbbbb";
        let b_evm = u160::from_vec(&b_evm, 0, 20);

        next_tx(scenario, a); {
            let coin = mint<SUI>(1000, ctx(scenario));
            sui::transfer(coin, a);
        };

        next_tx(scenario, a); {
            vm::create(ctx(scenario));
        };

        // a deposits 900
        next_tx(scenario, a); {
            let state_val = test::take_shared<StateV1>(scenario);
            let state = &mut state_val;

            let amount = 900;
            let original = test::take_from_sender<Coin<SUI>>(scenario);
            let coin = coin::split<SUI>(&mut original, amount, ctx(scenario));

            vm::deposit(state, a_evm, coin, ctx(scenario)); // deposit 900
            let balance = vm::pool_balance(state);
            assert!(balance == 900, 0);

            let acct = vm::account(state, a_evm);
            assert!(account::balance(acct) == 900, 0);
            assert!(account::nonce(acct) == 0, 0);

            test::return_shared(state_val);
            test::return_to_sender(scenario, original);
        };

        // a transfers 10 to b
        next_tx(scenario, a); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);

            let val = coin::value<SUI>(&coin);
            assert!(val == 100, 0);

            let sent = coin::split(&mut coin, 10, ctx(scenario));
            sui::transfer(sent, b);
            let val = coin::value<SUI>(&coin);
            assert!(val == 90, 0);
            
            test::return_to_sender(scenario, coin);
        };

        // b deposits 9
        next_tx(scenario, b); {
            let state_val = test::take_shared<StateV1>(scenario);
            let state_v1 = &mut state_val;

            let coin = test::take_from_sender<Coin<SUI>>(scenario);
            let val = coin::value<SUI>(&coin);
            assert!(val == 10, 0);

            let amount = 1;
            let sent = coin::split(&mut coin, amount, ctx(scenario));

            vm::deposit(state_v1, b_evm, coin, ctx(scenario));
            let balance = state::pool_balance(vm::state(state_v1));
            assert!(balance == 909, 0);

            let acct = vm::account(state_v1, a_evm);
            assert!(account::balance(acct) == 900, 0);
            assert!(account::nonce(acct) == 0, 0);

            let acct = vm::account(state_v1, b_evm);
            assert!(account::balance(acct) == 9, 0);
            assert!(account::nonce(acct) == 0, 0);

            sui::transfer(sent, b);
            test::return_shared(state_val);
        };

        // transfer
        next_tx(scenario, a); {
            let state_val = test::take_shared<StateV1>(scenario);
            let state_v1 = &mut state_val;

            vm::transfer(state_v1, 0, a_evm, b_evm, 1, ctx(scenario));
            vm::transfer(state_v1, 1, a_evm, b_evm, 1, ctx(scenario));
            vm::transfer(state_v1, 0, b_evm, a_evm, 1, ctx(scenario));

            let balance = vm::pool_balance(state_v1);
            assert!(balance == 909, 0);

            let acct = vm::account(state_v1, a_evm);
            assert!(account::balance(acct) == 899, 0);
            assert!(account::nonce(acct) == 2, 0);

            let acct = vm::account(state_v1, b_evm);
            assert!(account::balance(acct) == 10, 0);
            assert!(account::nonce(acct) == 1, 0);

            test::return_shared(state_val);
        };

        // a withdraws 100
        next_tx(scenario, a); {
            let state_val = test::take_shared<StateV1>(scenario);
            let state_v1 = &mut state_val;

            let coin_withdrawn = vm::withdraw(state_v1, a_evm, 100, ctx(scenario));
            let val = coin::value(&coin_withdrawn);
            assert!(val == 100, 0);

            let balance = vm::pool_balance(state_v1);
            assert!(balance == 809, 0);

            let acct = vm::account(state_v1, a_evm);
            assert!(account::balance(acct) == 799, 0);

            let acct = vm::account(state_v1, b_evm);
            assert!(account::balance(acct) == 10, 0);

            let coin = test::take_from_sender<Coin<SUI>>(scenario);
            coin::join(&mut coin, coin_withdrawn);
            let val = coin::value<SUI>(&coin);
            assert!(val == 190, 0);

            test::return_to_sender(scenario, coin);
            test::return_shared(state_val);
        };

        next_tx(scenario, a); {
            let coin = test::take_from_sender<Coin<SUI>>(scenario);
            let val = coin::value<SUI>(&coin);
            assert!(val == 190, 0);
            
            test::return_to_sender(scenario, coin);
        };

        test::end(scenario_val);
    }
}
