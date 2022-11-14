module vm::u160 {
    use std::vector;

    use vm::u256::{Self, Big256};

    const EINVALID_LENGTH: u64 = 0;

    /// Big160 internals
    /// 
    /// 000000000000000000000000ffffffff eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    /// padded with zeros       [  v1  ] [              v0              ]
    ///
    struct Big160 has copy, drop, store {
        v1: u128,   // most significant 32 bit. padded with zeros.
        v0: u128,   // next significant 128 bit
    }

    public fun zero(): Big160 {
        Big160 {
            v0: 0,
            v1: 0,
        }
    }

    public fun new(v0: u128, v1: u128): Big160 {
        Big160 {
            v0,
            v1,
        }
    }

    /// convert to u8 array of length 20
    public fun to_vec(a: &Big160): vector<u8> {
        let ret: vector<u8> = vector::empty();
        u128_to_u8a4(&mut ret, a.v1);
        u128_to_u8a16(&mut ret, a.v0);
        ret
    }
    
    /// convert to u8 array of length 16
    fun u128_to_u8a16(vec: &mut vector<u8>, a: u128) {
        let i = 0;
        while (i < 16) {
            let byte = (((a >> ((15 - i) * 8)) & 0xff) as u8);
            vector::push_back(vec, byte);
            i = i + 1;
        };
    }

    /// convert to u8 array of length 4
    fun u128_to_u8a4(vec: &mut vector<u8>, a: u128) {
        let i = 0;
        while (i < 4) {
            let byte = (((a >> ((3 - i) * 8)) & 0xff) as u8);
            vector::push_back(vec, byte);
            i = i + 1;
        };
    }

    /// convert from u8 array of length < 20
    public fun from_vec(vec: &vector<u8>, offset: u64, len: u64): Big160 {
        assert!(len <= 20, EINVALID_LENGTH);
        
        if (len == 20) {
            let v1 = vec_to_u128(vec, offset, 4);
            let v0 = vec_to_u128(vec, offset+4, 16);
            return Big160 { v0, v1, }
        } else if (len >= 16) {
            let rem = len % 16;
            let v1 = vec_to_u128(vec, offset, rem);
            let v0 = vec_to_u128(vec, offset+rem, 16);
            return Big160 { v0, v1, }
        } else {
            let v0 = vec_to_u128(vec, offset, len);
            return Big160 { v0, v1: 0, }
        }
    }

    fun vec_to_u128(vec: &vector<u8>, offset: u64, size: u64): u128 {
        let ret: u128 = 0;

        let i = 0;
        let pow: u128 = 1;
        while(i < size) {
            if (i > 0) { // to avoid overflow
                pow = pow * 256u128;
            };

            let byte = *vector::borrow(vec, offset + size - i - 1);
            let byte: u128 = (byte as u128) * pow;
            ret = ret + byte;
            i = i + 1;
        };
        ret
    }

    public fun to_u256(n: Big160): Big256 {
        let v0 = ((n.v0 & 0xffffffffffffffff) as u64);
        let v1 = ((n.v0 >> 64) as u64);
        let v2 = (n.v1 as u64);
        u256::new(v0, v1, v2, 0)
    }

    public fun from_u256(n: Big256): Big160 {
        let n_v0 = u256::get(&n, 0);
        let v0_lsb: u128 = (n_v0 as u128);
        let v0_msb: u128 = ((n_v0 as u128) << 64);
        let v0 = v0_lsb + v0_msb;

        let n_v1 = u256::get(&n, 1);
        let v1 = (n_v1 as u128);

        new(v0, v1)
    }

    #[test]
    fun test_u128_to_u8a16() {
        let a = 0x00112233445566778899aabbccddeeff;
        let dst = vector::empty();

        u128_to_u8a16(&mut dst, a);
        assert!(vector::length(&dst) == 16, 0);
        
        let i = 0;
        while(i < 16) {
            let byte = *vector::borrow(&dst, i);
            assert!(byte == (0x11*(i as u8)), 0);
            i = i + 1;
        }
    }

    #[test]
    fun test_u128_to_u8a4() {
        let a = 0x00112233445566778899aabbccddeeff;
        let dst = vector::empty();

        u128_to_u8a4(&mut dst, a);
        assert!(vector::length(&dst) == 4, 0);
        
        let i = 0;
        while(i < 4) {
            let byte = *vector::borrow(&dst, i);
            assert!(byte == (0x11*(0xc + (i as u8))), 0);
            i = i + 1;
        }
    }

    #[test]
    fun test_to_vec() {
        let a = Big160 {
            v0: 0x00112233445566778899aabbccddeeff,
            v1: 0x00000000000000000000000011223344,
        };

        let dst = to_vec(&a);
        assert!(vector::length(&dst) == 20, 0);

        let i = 0;
        while(i < 4) {
            let byte = *vector::borrow(&dst, i);
            assert!(byte == (0x11 + 0x11*(i as u8)), 0);
            i = i + 1;
        };

        let i = 0;
        while(i < 16) {
            let byte = *vector::borrow(&dst, 4 + i);
            assert!(byte == (0x11*(i as u8)), 0);
            i = i + 1;
        };
    }

    #[test]
    fun test_vec_to_u128() {
        let vec = vector::empty();

        let i = 0;
        while(i < 16) {
            vector::push_back(&mut vec, 0x11 * i);
            i = i + 1;
        };

        let n = vec_to_u128(&vec, 0, 16);
        assert!(n == 0x00112233445566778899aabbccddeeff, 0);
    }

    #[test]
    fun test_from_vec() {
        let vec = vector::empty();
        let i = 0;
        while(i < 20) {
            vector::push_back(&mut vec, i + 1);
            i = i + 1;
        };

        let a = from_vec(&vec, 0, vector::length(&vec));

        assert!(a.v0 == 0x05060708090a0b0c0d0e0f1011121314, 0);
        assert!(a.v1 == 0x00000000000000000000000001020304, 0);

        {
            let vec = vector::empty();
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000000000000, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = vector::empty();
            vector::push_back(&mut vec, 0x11);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000000000011, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(2);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000000000001, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(3);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000000000102, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(4);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000000010203, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(5);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000001020304, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(6);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000000102030405, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(7);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000000010203040506, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(8);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000001020304050607, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(9);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000000102030405060708, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(10);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000000010203040506070809, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(11);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0000000000000102030405060708090a, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(12);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000000000102030405060708090a0b, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(13);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x000000000102030405060708090a0b0c, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(14);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0000000102030405060708090a0b0c0d, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(15);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x00000102030405060708090a0b0c0d0e, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(16);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x000102030405060708090a0b0c0d0e0f, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(17);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0102030405060708090a0b0c0d0e0f10, 0);
            assert!(a.v1 == 0x00000000000000000000000000000000, 0);
        };
        {
            let vec = create_vec(18);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x02030405060708090a0b0c0d0e0f1011, 0);
            assert!(a.v1 == 0x00000000000000000000000000000001, 0);
        };
        {
            let vec = create_vec(19);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x030405060708090a0b0c0d0e0f101112, 0);
            assert!(a.v1 == 0x00000000000000000000000000000102, 0);
        };
        {
            let vec = create_vec(20);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0405060708090a0b0c0d0e0f10111213, 0);
            assert!(a.v1 == 0x00000000000000000000000000010203, 0);
        };

        {
            let vec = create_vec(40);
            {
                let a = from_vec(&vec, 10, 3);
                assert!(a.v0 == 0x000000000000000000000000000a0b0c, 0);
                assert!(a.v1 == 0x00000000000000000000000000000000, 0);
            };
            {
                let a = from_vec(&vec, 11, 4);
                assert!(a.v0 == 0x0000000000000000000000000b0c0d0e, 0);
                assert!(a.v1 == 0x00000000000000000000000000000000, 0);
            };
            {
                let a = from_vec(&vec, 5, 20);
                assert!(a.v0 == 0x090a0b0c0d0e0f101112131415161718, 0);
                assert!(a.v1 == 0x00000000000000000000000005060708, 0);
            };
            {
                let a = from_vec(&vec, 25, 10);
                assert!(a.v0 == 0x000000000000191a1b1c1d1e1f202122, 0);
                assert!(a.v1 == 0x00000000000000000000000000000000, 0);
            };
        };
    }

    #[test_only]
    fun create_vec(size: u8): vector<u8> {
        let vec = vector::empty();
        let i = 0;
        while(i < size) {
            vector::push_back(&mut vec, i);
            i = i + 1;
        };
        vec
    }
}