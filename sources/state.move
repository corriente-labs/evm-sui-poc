module vm::state {
    use std::vector;

    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;
    use sui::sui::{SUI};
    use sui::coin::{Coin, Self};

    use vm::account::{Self, Account};
    use vm::u160::{Big160};

    const EAmountInvalid: u64 = 0;

    struct State has key, store {
        id: UID,
        accounts: Table<Big160, Account>,
        height: u128,
        pool: Coin<SUI>,
    }

    public fun create(ctx: &mut TxContext): State {
        let state = State {
            id: object::new(ctx),
            accounts: table::new(ctx),
            height: 0,
            pool: coin::zero(ctx),
        };
        state
    }

    public fun id(state: &State): &UID {
        &state.id
    }
    public fun accounts(state: &State): &Table<Big160, Account> {
        &state.accounts
    }
    public fun accounts_mut(state: &mut State): &mut Table<Big160, Account> {
        &mut state.accounts
    }

    public fun add(state: &mut State, addr: Big160, acct: Account) {
        table::add(&mut state.accounts, addr, acct);
    }
    public fun contains_account(state: &State, addr: Big160): bool {
        table::contains(&state.accounts, addr)
    }
    public fun get_account(state: &State, addr: Big160): &Account {
        table::borrow(&state.accounts, addr)
    }
    public fun get_account_mut(state: &mut State, addr: Big160): &mut Account {
        table::borrow_mut(&mut state.accounts, addr)
    }

    public fun deposit(state: &mut State, addr: Big160, amount: u64, ctx: &mut TxContext) {
        if (table::contains(&state.accounts, addr)) {
            let acct = table::borrow_mut(&mut state.accounts, addr);
            let current_balance = account::balance(acct);
            account::set_balance(acct, current_balance + amount);
        } else {
            let acct = account::new(ctx, addr, amount, 0, vector::empty());
            table::add(&mut state.accounts, addr, acct);
        }
    }
    public fun withdraw(state: &mut State, addr: Big160, amount: u64) {
        let acct = table::borrow_mut(&mut state.accounts, addr);
        let current_balance = account::balance(acct);

        assert!(current_balance >= amount, EAmountInvalid);
        account::set_balance(acct, current_balance - amount);
    }

    public fun height(state: &State): u128 {
        state.height
    }
    public fun height_mut(state: &mut State): &mut u128 {
        &mut state.height
    }
    public fun pool(state: &State): &Coin<SUI> {
        &state.pool
    }
    public fun pool_balance(state: &State): u64 {
        coin::value(&state.pool)
    }
    public fun pool_mut(state: &mut State): &mut Coin<SUI> {
        &mut state.pool
    }
}