module vm::vm {
    use std::vector;

    use sui::object::{Self, UID, uid_to_address};
    use sui::tx_context::TxContext;
    use sui::sui::{SUI};
    use sui::coin::{Coin, Self};
    use sui::event;
    use sui::transfer;
    use sui::ecdsa;
    
    use vm::state::{State, Self};
    use vm::account::{Account, Self};

    use vm::u160::{Self, Big160};
    use vm::u256::{Self, Big256};
    use vm::memory::{Self, Memory};

    const WORDSIZE_BYTE: u8 = 32; // 256 bit
    const WORDSIZE_BYTE_u64: u64 = 32; // 256 bit
    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

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
    struct EvmEvent has copy, drop {
        data: vector<u8>,
        topics: vector<Big256>,
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

    const ECALL_DEPTH_OVERFLOW: u64 = 1001;
    const ECALL_INVALID_JUMP: u64 = 1002;

    fun call_inner(state: &mut State,
        origin: Big160,
        caller_addr: Big160,
        to: Big160,
        value: Big256,
        code: &vector<u8>,
        calldata: &vector<u8>,
        stack: &mut vector<Big256>,
        mem: &mut Memory,
        ret_data: &mut vector<u8>,
        depth: &mut u64,
    ): vector<u8> {
        let pc = 0u64;

        assert!(*depth < 1024, ECALL_DEPTH_OVERFLOW);

        while(pc < vector::length(code)) {
            let op = *vector::borrow<u8>(code, pc);

            // stop
            if (op == 0x00) {
                break
            };

            // add
            if (op == 0x01) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::add(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // mul
            if (op == 0x02) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::mul(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // sub
            if (op == 0x03) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::sub(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // div
            if (op == 0x04) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::div(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // // sdiv
            // if (op == 0x05) {
            //     let lhs = vector::pop_back(stack);
            //     let rhs = vector::pop_back(stack);
            //     let result = u256::sdiv(lhs, rhs);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // mod
            // if (op == 0x06) {
            //     let lhs = vector::pop_back(stack);
            //     let rhs = vector::pop_back(stack);
            //     let result = u256::mod(lhs, rhs);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // smod
            // if (op == 0x07) {
            //     let lhs = vector::pop_back(stack);
            //     let rhs = vector::pop_back(stack);
            //     let result = u256::smod(lhs, rhs);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // addmod
            // if (op == 0x08) {
            //     let lhs = vector::pop_back(stack);
            //     let rhs = vector::pop_back(stack);
            //     let n = vector::pop_back(stack);
            //     let result = u256::addmod(lhs, rhs, n);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // mulmod
            // if (op == 0x09) {
            //     let lhs = vector::pop_back(stack);
            //     let rhs = vector::pop_back(stack);
            //     let n = vector::pop_back(stack);
            //     let result = u256::mulmod(lhs, rhs, n);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // exp
            // if (op == 0x0a) {
            //     let a = vector::pop_back(stack);
            //     let exp = vector::pop_back(stack);
            //     let result = u256::exp(a, exp);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // signextend
            // if (op == 0x0b) {
            //     let b = vector::pop_back(stack);
            //     let x = vector::pop_back(stack);
            //     let result = u256::signextend(b, x);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // lt
            if (op == 0x10) {
                let a = vector::pop_back(stack);
                let b = vector::pop_back(stack);
                let result = u256::compare(&a, &b);
                
                if (result == LESS_THAN) {
                    vector::push_back(stack, u256::one());
                } else {
                    vector::push_back(stack, u256::zero());
                };

                pc = pc + 1;
                continue
            };

            // gt
            if (op == 0x11) {
                let a = vector::pop_back(stack);
                let b = vector::pop_back(stack);
                let result = u256::compare(&a, &b);
                
                if (result == GREATER_THAN) {
                    vector::push_back(stack, u256::one());
                } else {
                    vector::push_back(stack, u256::zero());
                };

                pc = pc + 1;
                continue
            };

            // // slt
            // if (op == 0x12) {
            //     let a = vector::pop_back(stack);
            //     let b = vector::pop_back(stack);
            //     let result = u256::signed_compare(&a, &b);
                
            //     if (result == LESS_THAN) {
            //         vector::push_back(stack, u256::one());
            //     } else {
            //         vector::push_back(stack, u256::zero());
            //     };

            //     pc = pc + 1;
            //     continue
            // };

            // // sgt
            // if (op == 0x13) {
            //     let a = vector::pop_back(stack);
            //     let b = vector::pop_back(stack);
            //     let result = u256::signed_compare(&a, &b);
                
            //     if (result == GREATER_THAN) {
            //         vector::push_back(stack, u256::one());
            //     } else {
            //         vector::push_back(stack, u256::zero());
            //     };

            //     pc = pc + 1;
            //     continue
            // };

            // eq
            if (op == 0x14) {
                let a = vector::pop_back(stack);
                let b = vector::pop_back(stack);
                let result = u256::compare(&a, &b);
                
                if (result == EQUAL) {
                    vector::push_back(stack, u256::one());
                } else {
                    vector::push_back(stack, u256::zero());
                };

                pc = pc + 1;
                continue
            };

            // iszero
            if (op == 0x14) {
                let a = vector::pop_back(stack);
                if (u256::is_zero(&a)) {
                    vector::push_back(stack, u256::one());
                } else {
                    vector::push_back(stack, u256::zero());
                };

                pc = pc + 1;
                continue
            };

            // and
            if (op == 0x16) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::bitand(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // or
            if (op == 0x17) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::bitor(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // xor
            if (op == 0x18) {
                let lhs = vector::pop_back(stack);
                let rhs = vector::pop_back(stack);
                let result = u256::bitxor(lhs, rhs);
                vector::push_back(stack, result);
                pc = pc + 1;
                continue
            };

            // // not
            // if (op == 0x19) {
            //     let a = vector::pop_back(stack);
            //     let result = u256::bitnot(a);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // // byte
            // if (op == 0x1a) {
            //     let i = vector::pop_back(stack);
            //     let x = vector::pop_back(stack);
            //     let result = u256::byte(i, x);
            //     vector::push_back(stack, result);
            //     pc = pc + 1;
            //     continue
            // };

            // shl
            if (op == 0x1b) {
                let shift = vector::pop_back(stack);
                if (u256::lt_256(shift)) {
                    let shift = u256::as_u8(shift);
                    let val = vector::pop_back(stack);
                    let result = u256::shl(val, shift);
                    vector::push_back(stack, result);
                } else {
                    vector::push_back(stack, u256::zero());
                };
                
                pc = pc + 1;
                continue
            };

            // shr
            if (op == 0x1c) {
                let shift = vector::pop_back(stack);
                if (u256::lt_256(shift)) {
                    let shift = u256::as_u8(shift);
                    let val = vector::pop_back(stack);
                    let result = u256::shr(val, shift);
                    vector::push_back(stack, result);
                } else {
                    vector::push_back(stack, u256::zero());
                };

                pc = pc + 1;
                continue
            };

            // // sar
            // if (op == 0x1d) {
            //     let shift = vector::pop_back(stack);
            //     let val = vector::pop_back(stack);
            //     let result = u256::sar(val, shift);
            //     vector::push_back(stack, result);

            //     pc = pc + 1;
            //     continue
            // };

            // sha3
            if (op == 0x20) {
                let offset = vector::pop_back(stack);
                let offset = u256::as_u64(offset);

                let size = vector::pop_back(stack);
                let size = u256::as_u64(size);

                let preimage = memory::expand_slice(mem, offset, size);
                let image = ecdsa::keccak256(&preimage);
                let image = u256::from_vec(&image, 0, 32);
                vector::push_back(stack, image);

                pc = pc + 1;
                continue
            };

            // address
            if (op == 0x30) {
                vector::push_back(stack, u160::to_u256(to));
                pc = pc + 1;
                continue
            };

            // balance
            if (op == 0x31) {
                let addr = vector::pop_back(stack);
                let addr = u160::from_u256(addr);
                if(state::contains_account(state, addr)) {
                    let acct = state::get_account(state, addr);
                    let balance = account::balance(acct);
                    let balance = u256::from_u64(balance);
                    vector::push_back(stack, balance);
                } else {
                    vector::push_back(stack, u256::zero());
                };
                pc = pc + 1;
                continue
            };

            // origin
            if (op == 0x32) {
                vector::push_back(stack, u160::to_u256(origin));
                pc = pc + 1;
                continue
            };

            // caller
            if (op == 0x33) {
                vector::push_back(stack, u160::to_u256(caller_addr));
                pc = pc + 1;
                continue
            };
            
            // callvalue
            if (op == 0x34) {
                vector::push_back(stack, value);
                pc = pc + 1;
                continue
            };
            
            // calldataload
            if (op == 0x35) {
                let offset = vector::pop_back(stack);
                let offset = u256::as_u64(offset);

                let vec = vector::empty<u8>();

                let index = 0;
                while(offset + index < vector::length(calldata) && index < WORDSIZE_BYTE_u64) {
                    let value = *vector::borrow(calldata, offset + index);
                    vector::push_back(&mut vec, value);
                    index = index + 1;
                };

                // fill with padding
                while(index < WORDSIZE_BYTE_u64) {
                    vector::push_back(&mut vec, 0);
                    index = index + 1;
                };

                let val = u256::from_vec(&vec, 0, WORDSIZE_BYTE_u64);
                vector::push_back(stack, val);    // push resulting value

                pc = pc + 1;
                continue
            };
            
            // calldatasize
            if (op == 0x36) {
                let size = vector::length(calldata);
                vector::push_back(stack, u256::from_u64(size));
                pc = pc + 1;
                continue
            };
            
            // calldatacopy
            if (op == 0x37) {
                let dest_offset = vector::pop_back(stack);
                let dest_offset = u256::as_u64(dest_offset);

                let offset = vector::pop_back(stack);
                let offset = u256::as_u64(offset);
                
                let size = vector::pop_back(stack);
                let size = u256::as_u64(size);
                
                memory::expand(mem, offset, size);

                // copy calldata elements to memory
                let pad_size = memory::copy_from_vec(mem, dest_offset, calldata, offset, size);

                // fill with padding
                let index = 0;
                while (index < pad_size) {
                    memory::push(mem, 0);
                    index = index + 1;
                };

                pc = pc + 1;
                continue
            };

            // TODO
            // codesize
            if (op == 0x38) {
                pc = pc + 1;
                continue
            };

            // TODO
            // codecopy
            if (op == 0x39) {
                pc = pc + 1;
                continue
            };

            // TODO
            // gasprice
            if (op == 0x3a) {
                pc = pc + 1;
                continue
            };

            // TODO
            // extcodesize
            if (op == 0x3b) {
                pc = pc + 1;
                continue
            };

            // TODO
            // extcodecopy
            if (op == 0x3c) {
                pc = pc + 1;
                continue
            };

            // returndatasize
            if (op == 0x3d) {
                let size = vector::length(ret_data);
                let size = u256::from_u64(size);

                vector::push_back(stack, size);
                pc = pc + 1;
                continue
            };

            // TODO
            // returndatacopy
            if (op == 0x3e) {
                pc = pc + 1;
                continue
            };

            // TODO
            // extcodehash
            if (op == 0x3f) {
                pc = pc + 1;
                continue
            };

            // TODO
            // coinbase
            if (op == 0x41) {
                pc = pc + 1;
                continue
            };

            // TODO
            // timestamp
            if (op == 0x42) {
                pc = pc + 1;
                continue
            };

            // TODO
            // number
            if (op == 0x43) {
                pc = pc + 1;
                continue
            };

            // TODO
            // prevrandao
            if (op == 0x44) {
                pc = pc + 1;
                continue
            };

            // TODO
            // gaslimit
            if (op == 0x45) {
                pc = pc + 1;
                continue
            };

            // TODO
            // chainid
            if (op == 0x46) {
                pc = pc + 1;
                continue
            };

            // selfbalance
            if (op == 0x47) {
                let addr = vector::pop_back(stack);
                let addr = u160::from_u256(addr);
                let acct = state::get_account(state, addr);
                let balance = account::balance(acct);
                let balance = u256::from_u64(balance);
                vector::push_back(stack, balance);
                pc = pc + 1;
                continue
            };

            // TODO
            // basefee
            if (op == 0x48) {
                pc = pc + 1;
                continue
            };

            // pop
            if (op == 0x50) {
                let _ = vector::pop_back(stack);
                pc = pc + 1;
            };

            // mload
            if (op == 0x51) {
                let offset = vector::pop_back(stack);
                let val = memory::mload(mem, offset);
                vector::push_back(stack, val);
                pc = pc + 1;
                continue
            };

            // mstore
            if (op == 0x52) {
                let offset = vector::pop_back(stack);
                let val = vector::pop_back(stack);
                memory::mstore(mem, offset, val);
                pc = pc + 1;
                continue
            };

            // TODO
            // mstore8
            // if (op == 0x53) {
            //     let offset = vector::pop_back(stack);
            //     let val = vector::pop_back(stack);
            //     memory::mstore(mem, offset, val);
            //     pc = pc + 1;
            //     continue
            // };

            // sload
            if (op == 0x54) {
                let key = vector::pop_back(stack);

                let acct = state::get_account(state, to);
                let val = account::get_value(acct, key);

                vector::push_back(stack, val);
                pc = pc + 1;
                continue
            };

            // sstore
            if (op == 0x55) {
                let key = vector::pop_back(stack);
                let val = vector::pop_back(stack);
                
                let acct = state::get_account_mut(state, to);
                account::set_value(acct, key, val);

                pc = pc + 1;
                continue
            };

            // jump
            if (op == 0x56) {
                let dest_pc = vector::pop_back(stack);
                pc = u256::as_u64(dest_pc);

                let dest_op = *vector::borrow(code, pc);
                assert!(dest_op == 0x58, ECALL_INVALID_JUMP);

                continue
            };

            // jumpi
            if (op == 0x57) {
                let dest_pc = vector::pop_back(stack);
                let b = vector::pop_back(stack);

                if (u256::is_zero(&b)) {
                    pc = pc + 1;
                } else {
                    pc = u256::as_u64(dest_pc);
                    let dest_op = *vector::borrow(code, pc);
                    assert!(dest_op == 0x58, ECALL_INVALID_JUMP);
                };
                
                continue
            };

            // pc
            if (op == 0x58) {
                let val = u256::from_u64(pc);
                vector::push_back(stack, val);
                pc = pc + 1;
                continue
            };

            // msize
            if (op == 0x59) {
                let size = memory::msize(mem);
                vector::push_back(stack, size);
                pc = pc + 1;
                continue
            };

            // TODO
            // gas
            // if (op == 0x5a) {
            //     pc = pc + 1;
            //     continue
            // };

            // jumpdest
            if (op == 0x5b) {
                pc = pc + 1;
                continue
            };

            // push-n
            if (op >= 0x60 && op <= 0x7f) {
                let len = (op as u64) - 0x60;
                let val = u256::from_vec(code, pc, len);
                vector::push_back(stack, val);
                pc = pc + 2 + len;
                continue
            };

            // dup-n
            if (op >= 0x80 && op <= 0x8f) {
                let len = vector::length(stack);
                let index = len - 1 - ((op as u64) - 0x80);
                let value = vector::borrow(stack, index);
                vector::push_back(stack, *value);
                pc = pc + 1;
                continue
            };

            // swap-n
            if (op >= 0x90 && op <= 0x9f) {
                let len = vector::length(stack);
                let index = len - 1 - ((op as u64) - 0x90);
                vector::swap(stack, index, len - 1);
                pc = pc + 1;
                continue
            };

            // log-n
            if (op >= 0xa0 && op <= 0xa4) {
                let offset = vector::pop_back(stack);
                let offset = u256::as_u64(offset);

                let size = vector::pop_back(stack);
                let size = u256::as_u64(size);

                let data = memory::expand_slice(mem, offset, size);

                let topics = vector::empty();

                let count = 0;
                while (count < op - 0xa0) {
                    let topic = vector::pop_back(stack);
                    vector::push_back(&mut topics, topic);
                    count = count + 1;
                };

                event::emit(EvmEvent{
                    data: data,
                    topics: topics,
                });

                pc = pc + 1;
                continue
            };

            // create
            if (op == 0xf0) {
                pc = pc + 1;
                continue
            };

            // call
            if (op == 0xf1) {
                pc = pc + 1;
                continue
            };

            // callcode
            if (op == 0xf2) {
                pc = pc + 1;
                continue
            };

            // return
            if (op == 0xf3) {
                pc = pc + 1;
                continue
            };

            // delegatecall
            if (op == 0xf4) {
                pc = pc + 1;
                continue
            };

            // create2
            if (op == 0xf5) {
                pc = pc + 1;
                continue
            };

            // staticcall
            if (op == 0xfa) {
                pc = pc + 1;
                continue
            };

            // invalid
            if (op == 0xfe) {
                pc = pc + 1;
                continue
            };

            // selfdestruct
            if (op == 0xff) {
                pc = pc + 1;
                continue
            };
        };

        vector::empty()
    }
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
