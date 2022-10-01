module vm::state {
    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::TxContext;
    use sui::sui::{SUI};
    use sui::coin::{Coin, Self};
    use vm::account::{Account};

    struct State has key, store {
        id: UID,
        accounts: VecMap<vector<u8>, Account>,
        height: u128,
        pool: Coin<SUI>,
    }

    public fun create(ctx: &mut TxContext): State {
        let state = State {
            id: object::new(ctx),
            accounts: vec_map::empty(),
            height: 0,
            pool: coin::zero(ctx),
        };
        state
    }

    public fun id(state: &State): &UID {
        &state.id
    }
    public fun accounts(state: &State): &VecMap<vector<u8>, Account> {
        &state.accounts
    }
    public fun accounts_mut(state: &mut State): &mut VecMap<vector<u8>, Account> {
        &mut state.accounts
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