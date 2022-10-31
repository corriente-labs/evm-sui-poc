module vm::memory {
    use std::vector;

    use vm::u256::{Self, U256};

    const WORDSIZE_BYTE: u8 = 16; // 128 bit
    const WORDSIZE_BYTE_u64: u64 = 16; // 128 bit

    struct Memory has copy {
        data: vector<u8>,
    }

    public fun empty(): Memory {
        Memory {
            data: vector::empty(),
        }
    }

    public fun mload(mem: &mut Memory, offset: U256): U256 {
        let _ = mem;
        let _ = offset;
        u256::zero()
    }

    public fun mstore(mem: &mut Memory, offset: U256, val: U256) {
        let _ = mem;
        let _ = offset;
        let _ = val;
    }

    public fun msize(mem: &Memory): U256 {
        let len: u64 = (vector::length(&mem.data) as u64);
        u256::from_u64(len)
    }
}