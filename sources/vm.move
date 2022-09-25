module vm::vm {
    use sui::object::{UID};
    // use sui::tx_context::TxContext;

    struct Sword has key, store {
        id: UID,
        magic: u64,
        strength: u64,
    }
    public fun magic(self: &Sword): u64 {
        self.magic
    }

    public fun strength(self: &Sword): u64 {
        self.strength
    }

    #[test]
    public fun test_sword_create() {
        use sui::tx_context;
        use sui::transfer;
        use sui::object::{Self};

        // create a dummy TxContext for testing
        let ctx = tx_context::dummy();

        // create a sword
        let sword = Sword {
            id: object::new(&mut ctx),
            magic: 42,
            strength: 7,
        };

        // check if accessor functions return correct values
        assert!(magic(&sword) == 42 && strength(&sword) == 7, 1);

        let dummy_address = @0xCAFE;
        transfer::transfer(sword, dummy_address);
    }
}