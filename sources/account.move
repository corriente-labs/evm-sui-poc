module vm::account {
    use std::vector;

    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;

    use vm::u160::{Big160};
    use vm::u256::{Self, Big256};

    struct Account has store {
        addr: Big160,
        balance: u64,
        nonce: u128,
        code: vector<u8>,
        storage: Table<Big256, Big256>,
    }
    public fun new(ctx: &mut TxContext, addr: Big160, balance: u64, nonce: u128, code: vector<u8>): Account {
        Account {
            addr,
            balance,
            nonce,
            code,
            storage: table::new(ctx),
        }
    }

    public fun empty(ctx: &mut TxContext, addr: Big160, val: u64): Account {
        Account {
            addr,
            balance: val,
            nonce: 0,
            code: vector::empty(),
            storage: table::new(ctx),
        }
    }

    public fun addr(acct: &Account): Big160 {
        acct.addr
    }
    public fun balance(acct: &Account): u64 {
        acct.balance
    }
    public fun set_balance(acct: &mut Account, balance: u64) {
        acct.balance = balance;
    }
    public fun add_balance(acct: &mut Account, amount: u64) {
        acct.balance = acct.balance + amount;
    }
    public fun nonce(acct: &Account): u128 {
        acct.nonce
    }
    public fun set_nonce(acct: &mut Account, nonce: u128) {
        acct.nonce = nonce;
    }
    public fun nonce_increment(acct: &mut Account) {
        acct.nonce = acct.nonce + 1;
    }
    public fun code(acct: &Account): &vector<u8> {
        &acct.code
    }
    public fun set_code(acct: &mut Account, code: vector<u8>) {
        acct.code = code;
    }

    public fun get_value(acct: &Account, key: Big256): Big256 {
        if (table::contains(&acct.storage, key)) {
            *table::borrow(&acct.storage, key)
        } else {
            u256::zero()
        }
    }
    public fun set_value(acct: &mut Account, key: Big256, val: Big256) {
        if (table::contains(&acct.storage, key)) {
            let v = table::borrow_mut(&mut acct.storage, key);
            *v = val;
        } else {
            table::add(&mut acct.storage, key, val);
        };
    }

}