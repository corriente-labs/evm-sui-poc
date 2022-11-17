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
        
        let vec = u256::to_vec(&val);

        let index = 0;
        while(index < 32) {
            let src = *vector::borrow(&vec, index);
            let dst = vector::borrow_mut(&mut mem.data, offset + index);
            *dst = src;
            index = index + 1;
        };
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
        let new_len = offset + size;
        
        let spillover = new_len - len;
        let count = spillover;
        while(count > 0) {
            vector::push_back<u8>(&mut mem.data, 0);
            count = count - 1;
        };

        if (spillover > 0) {
            let remainder = new_len % 32;
            if (remainder > 0) {
                let pad_len = WORDSIZE_BYTE_u64 - remainder;
                while(pad_len > 0) {
                    vector::push_back<u8>(&mut mem.data, 0);
                    pad_len = pad_len - 1;
                };
            };
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
    fun test_expand() {
        {
            let mem = empty();
            expand(&mut mem, 0, 0);
            assert!(vector::length(&mem.data) == 0, 0);

            expand(&mut mem, 0, 32);
            assert!(vector::length(&mem.data) == 32, 0);

            expand(&mut mem, 13, 32);
            assert!(vector::length(&mem.data) == 64, 0);

            expand(&mut mem, 64, 32);
            assert!(vector::length(&mem.data) == 96, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 0, 1);
            assert!(vector::length(&mem.data) == 32, 0);

            expand(&mut mem, 10, 23);
            assert!(vector::length(&mem.data) == 64, 0);

            expand(&mut mem, 33, 32);
            assert!(vector::length(&mem.data) == 96, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 1, 1);
            assert!(vector::length(&mem.data) == 32, 0);

            expand(&mut mem, 16, 17);
            assert!(vector::length(&mem.data) == 64, 0);

            expand(&mut mem, 40, 56);
            assert!(vector::length(&mem.data) == 96, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 16, 16);
            assert!(vector::length(&mem.data) == 32, 0);

            expand(&mut mem, 16, 17);
            assert!(vector::length(&mem.data) == 64, 0);

            expand(&mut mem, 5, 320);
            assert!(vector::length(&mem.data) == 352, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 16, 17);
            assert!(vector::length(&mem.data) == 64, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 0, 33);
            assert!(vector::length(&mem.data) == 64, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 0, 64);
            assert!(vector::length(&mem.data) == 64, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 0, 320);
            assert!(vector::length(&mem.data) == 320, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 0, 321);
            assert!(vector::length(&mem.data) == 352, 0);

            expand(&mut mem, 320, 40);
            assert!(vector::length(&mem.data) == 384, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 32, 64);
            assert!(vector::length(&mem.data) == 96, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 11, 64);
            assert!(vector::length(&mem.data) == 96, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 11, 65);
            assert!(vector::length(&mem.data) == 96, 0);
        };

        {
            let mem = empty();
            expand(&mut mem, 11, 96);
            assert!(vector::length(&mem.data) == 128, 0);
        };
    }

    #[test]
    fun test_mload_from_empty() {
        let mem = empty();

        let val = mload_inner(&mut mem, 0);
        assert!(u256::is_zero(&val), 0);
        assert!(vector::length(&mem.data) == 32, 1);

        let val = mload_inner(&mut mem, 1);
        assert!(u256::is_zero(&val), 0);
        assert!(vector::length(&mem.data) == 64, 1);
    }

    #[test]
    fun test_mstore() {
        {
            let mem = empty();

            let offset = 0;
            let val = u256::new(
                0xffffffffffffffff,
                0xffffffffffffffff,
                0xffffffffffffffff,
                0xffffffffffffffff,
            );

            mstore_inner(&mut mem, offset, val);
            assert!(vector::length(&mem.data) == 32, 1);
            
            let index = 0;
            while(index < 32) {
                let d = *vector::borrow(&mem.data, index);
                assert!(d == 0xff, 0);

                index = index + 1;
            };
        };

        {
            let mem = empty();

            let offset = 1;
            let val = u256::new(
                0xffffffffffffffff,
                0xffffffffffffffff,
                0xffffffffffffffff,
                0xffffffffffffffff,
            );
            {
                mstore_inner(&mut mem, offset, val);
            
                assert!(vector::length(&mem.data) == 64, 1);
                
                let index = 0;
                let d = *vector::borrow(&mem.data, index);
                assert!(d == 0x00, 0);

                let index = 1;
                while(index < 33) {
                    let d = *vector::borrow(&mem.data, index);
                    assert!(d == 0xff, 0);

                    index = index + 1;
                };

                let index = 33;
                while(index < 64) {
                    let d = *vector::borrow(&mem.data, index);
                    assert!(d == 0x00, 0);

                    index = index + 1;
                };
            };
            
            let offset = 20;
            let val = u256::new(
                0xeeeeeeeeeeeeeeee,
                0xeeeeeeeeeeeeeeee,
                0xeeeeeeeeeeeeeeee,
                0xeeeeeeeeeeeeeeee,
            );
            {
                mstore_inner(&mut mem, offset, val);
            
                assert!(vector::length(&mem.data) == 64, 1);
                
                let index = 0;
                let d = *vector::borrow(&mem.data, index);
                assert!(d == 0x00, 0);

                let index = 1;
                while(index < 20) {
                    let d = *vector::borrow(&mem.data, index);
                    assert!(d == 0xff, 0);

                    index = index + 1;
                };

                while(index < 52) {
                    let d = *vector::borrow(&mem.data, index);
                    assert!(d == 0xee, 0);

                    index = index + 1;
                };

                let index = 52;
                while(index < 64) {
                    let d = *vector::borrow(&mem.data, index);
                    assert!(d == 0x00, 0);

                    index = index + 1;
                };
            };
        };

    }

    #[test]
    fun test_mstore8() {
        {
            let mem = empty();

            let offset = 0;
            let val = 0xff;

            mstore8_inner(&mut mem, offset, val);
            assert!(vector::length(&mem.data) == 32, 1);
            
            let index = 0;

            let d = *vector::borrow(&mem.data, index);
            assert!(d == 0xff, 0);

            let index = 1;
            while(index < 32) {
                let d = *vector::borrow(&mem.data, index);
                assert!(d == 0x00, 0);

                index = index + 1;
            };
        };

        {
            let mem = empty();

            {
                let offset = 0;
                let val = u256::new(
                    0xffffffffffffffff,
                    0xffffffffffffffff,
                    0xffffffffffffffff,
                    0xffffffffffffffff,
                );

                mstore_inner(&mut mem, offset, val);
                assert!(vector::length(&mem.data) == 32, 1);
                
                let index = 0;
                while(index < 32) {
                    let d = *vector::borrow(&mem.data, index);
                    assert!(d == 0xff, 0);

                    index = index + 1;
                };
            };

            {
                let offset = 3;
                let val = 0xee;

                mstore8_inner(&mut mem, offset, val);
                assert!(vector::length(&mem.data) == 32, 1);

                let index = 0;
                while(index < 32) {
                    if (index == 3) {
                        let d = *vector::borrow(&mem.data, index);
                        assert!(d == 0xee, 0);
                    } else {
                        let d = *vector::borrow(&mem.data, index);
                        assert!(d == 0xff, 0);
                    };
                    index = index + 1;
                };
            };

            {
                let offset = 33;
                let val = 0xdd;

                mstore8_inner(&mut mem, offset, val);
                assert!(vector::length(&mem.data) == 64, 1);

                let index = 0;
                while(index < 64) {
                    if (index == 3) {
                        let d = *vector::borrow(&mem.data, index);
                        assert!(d == 0xee, 0);
                    } else if (index == 33) {
                        let d = *vector::borrow(&mem.data, index);
                        assert!(d == 0xdd, 0);
                    } else if (index < 32) {
                        let d = *vector::borrow(&mem.data, index);
                        assert!(d == 0xff, 0);
                    } else {
                        let d = *vector::borrow(&mem.data, index);
                        assert!(d == 0x00, 0);
                    };
                    index = index + 1;
                };
            };
        };
    }
}