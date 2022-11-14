module vm::memory {
    use std::vector;

    use vm::u256::{Self, Big256};

    const WORDSIZE_BYTE: u8 = 16; // 128 bit
    const WORDSIZE_BYTE_u64: u64 = 16; // 128 bit

    struct Memory has copy, drop {
        data: vector<u8>,
    }

    public fun empty(): Memory {
        Memory {
            data: vector::empty(),
        }
    }

    public fun mload(mem: &mut Memory, offset: Big256): Big256 {
        let _ = mem;
        let _ = offset;
        u256::zero()
    }

    public fun mstore(mem: &mut Memory, offset: Big256, val: Big256) {
        let _ = mem;
        let _ = offset;
        let _ = val;
    }

    public fun msize(mem: &Memory): Big256 {
        let len: u64 = (vector::length(&mem.data) as u64);
        u256::from_u64(len)
    }

    public fun expand(mem: &mut Memory, offset: u64, size: u64) {
        let _ = mem;
        let _ = offset;
        let _ = size;
    }

    public fun slice(
        src: &Memory,
        offset: u64,
        size: u64,
    ): vector<u8> {
        vector::empty()
    }

    public fun copy_from_vec(
        dst: &mut Memory,
        dst_offset: u64,
        src: &vector<u8>,
        src_offset: u64,
        size: u64): u64
    {
        let pad_size = 0;
        pad_size
    }

    public fun push(mem: &mut Memory, d: u8) {
        vector::push_back(&mut mem.data, d);
    }
}