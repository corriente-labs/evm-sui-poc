module vm::account {

    struct Account has store {
        addr: vector<u8>,
        balance: u64,
        nonce: u128,
        code: vector<u8>,
    }
    public fun create(addr: vector<u8>, balance: u64, nonce: u128, code: vector<u8>): Account {
        Account {
            addr,
            balance,
            nonce,
            code,
        }
    }

    public fun addr(acct: &Account): vector<u8> {
        acct.addr
    }
    public fun balance(acct: &Account): u64 {
        acct.balance
    }
    public fun set_balance(acct: &mut Account, balance: u64) {
        acct.balance = balance;
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
    public fun code(acct: &Account): vector<u8> {
        acct.code
    }
    public fun set_code(acct: &mut Account, code: vector<u8>) {
        acct.code = code;
    }
}