module vm::memory {
    use std::vector;

    use vm::u256::{Self, Big256};

    const WORDSIZE_BYTE: u8 = 32; // 256 bit
    const WORDSIZE_BYTE_u64: u64 = 32; // 256 bit

    struct Memory has copy, drop {
        data: vector<u8>,
    }

    public fun empty(): Memory {
        Memory {
            data: vector::empty(),
        }
    }

    public fun mload(mem: &mut Memory, offset: Big256): Big256 {
        let offset = u256::as_u64(offset);
        mload_inner(mem, offset)
    }
    fun mload_inner(mem: &mut Memory, offset: u64): Big256 {
        let len = vector::length(&mem.data);

        if(offset + WORDSIZE_BYTE_u64 > len) {
            expand(mem, offset, WORDSIZE_BYTE_u64);
        };

        let val = u256::from_vec(&mem.data, offset, 32);
        val
    }

    public fun mstore(mem: &mut Memory, offset: Big256, val: Big256) {
        let offset = u256::as_u64(offset);
        mstore_inner(mem, offset, val);
    }
    fun mstore_inner(mem: &mut Memory, offset: u64, val: Big256) {
        let len = vector::length(&mem.data);
        if(offset + WORDSIZE_BYTE_u64 > len) {
            expand(mem, offset, WORDSIZE_BYTE_u64);
        };
        
        let val = u256::to_vec(&val);
        vector::append(&mut mem.data, val);
    }

    public fun mstore8(mem: &mut Memory, offset: Big256, val: u8) {
        let offset = u256::as_u64(offset);
        mstore8_inner(mem, offset, val);
    }
    fun mstore8_inner(mem: &mut Memory, offset: u64, val: u8) {
        let len = vector::length(&mem.data);

        if(offset + 1 > len) {
            expand(mem, offset, 1);
        };

        let dst = vector::borrow_mut(&mut mem.data, offset);
        *dst = val;
    }

    public fun msize(mem: &Memory): Big256 {
        let len: u64 = (vector::length(&mem.data) as u64);
        u256::from_u64(len)
    }

    public fun expand(mem: &mut Memory, offset: u64, size: u64) {
        let len = vector::length(&mem.data);
        let spillover = offset + size - len;
        while(spillover > 0) {
            vector::push_back<u8>(&mut mem.data, 0);
            spillover = spillover - 1;
        };
    }

    public fun expand_slice(
        src: &mut Memory,
        offset: u64,
        size: u64,
    ): vector<u8> {
        let len = vector::length(&src.data);

        if(offset + size > len) {
            expand(src, offset, WORDSIZE_BYTE_u64);
        };

        let ret = vector::empty();
        let count = 0;
        while(count < size) {
            let d = *vector::borrow(&src.data, offset + count);
            vector::push_back(&mut ret, d);
            count = count + 1;
        };

        ret
    }

    public fun copy_from_vec(
        dst: &mut Memory,
        dst_offset: u64,
        src: &vector<u8>,
        src_offset: u64,
        size: u64)
    : u64 {
        let len = vector::length(&dst.data);
        let pad_size = dst_offset + size - len;
        if(pad_size > 0) {
            expand(dst, dst_offset, size);
        };

        let count = 0;
        while(count < size) {
            let d = *vector::borrow(src, src_offset + count);
            let dst_digit = vector::borrow_mut(&mut dst.data, dst_offset);
            *dst_digit = d;
            count = count + 1;
        };

        pad_size
    }

    public fun push(mem: &mut Memory, d: u8) {
        vector::push_back(&mut mem.data, d);
    }

    #[test]
    fun test_mload_from_empty() {
        let mem = empty();

        let val = mload_inner(&mut mem, 0);
        assert!(u256::is_zero(&val), 0);
        assert!(vector::length(&mem.data) == 32, 1);

        let val = mload_inner(&mut mem, 1);
        assert!(u256::is_zero(&val), 0);
        assert!(vector::length(&mem.data) == 33, 1);
    }
}