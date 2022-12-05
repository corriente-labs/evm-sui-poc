#[test_only]
module vm::vm_test {
    use std::vector;

    use sui::sui::{SUI, Self};
    use sui::coin::{mint_for_testing as mint};
    use sui::test_scenario::{Self as test, next_tx, ctx};
    use sui::transfer;

    use vm::vm::{Self};

    use vm::u160::{Self};
    use vm::u256::{Self, Big256};
    use vm::memory::{Self};

    #[test]
    public fun test_empty_code() {
        let sender = @0x111111;
        let scenario_val = test::begin(sender);
        let scenario = &mut scenario_val;

        next_tx(scenario, sender); {
            let coin = mint<SUI>(1000, ctx(scenario));
            sui::transfer(coin, sender);
        };

        next_tx(scenario, sender); {
            let state_val = vm::create_state(ctx(scenario));
            let state = vm::state_mut(&mut state_val);

            let code = x"00";
            let calldata = x"00";
            let stack = vector::empty<Big256>();
            let mem = memory::empty();
            let depth = 0;

            let (success, ret) = vm::call_inner(
                state,
                u160::zero(),
                u160::zero(),
                u160::zero(),
                u256::zero(),
                &code,
                &calldata,
                &mut stack,
                &mut mem,
                &mut depth,
                ctx(scenario),
            );

            assert!(success, 0);
            assert!(vector::length(&ret) == 0, 0);

            transfer::share_object(state_val);
        };

        test::end(scenario_val);
    }

    #[test]
    public fun test_basic_code() {
        let sender = @0x111111;
        let scenario_val = test::begin(sender);
        let scenario = &mut scenario_val;

        next_tx(scenario, sender); {
            let coin = mint<SUI>(1000, ctx(scenario));
            sui::transfer(coin, sender);
        };

        next_tx(scenario, sender); {
            let state_val = vm::create_state(ctx(scenario));
            let state = vm::state_mut(&mut state_val);

            // return 1 + 2
            let code = x"600160020160005260206000f3";
            let calldata = x"00";
            let stack = vector::empty<Big256>();
            let mem = memory::empty();
            let depth = 0;

            let (success, ret) = vm::call_inner(
                state,
                u160::zero(),
                u160::zero(),
                u160::zero(),
                u256::zero(),
                &code,
                &calldata,
                &mut stack,
                &mut mem,
                &mut depth,
                ctx(scenario),
            );

            assert!(success, 0);
            assert!(vector::length(&ret) == 32, 0);
            let index = 0;
            while(index < 32) {
                let byte = *vector::borrow(&ret, index);
                if (index == 31) {
                    assert!(byte == 3, index);
                } else {
                    assert!(byte == 0, index);
                };
                index = index + 1;
            };

            transfer::share_object(state_val);
        };

        test::end(scenario_val);
    }
}