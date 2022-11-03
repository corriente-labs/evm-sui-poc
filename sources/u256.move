/// The implementation of large numbers written in Move language.
/// Code derived from original work by Andrew Poelstra <apoelstra@wpsoftware.net>
///
/// Rust Bitcoin Library
/// Written in 2014 by
///	   Andrew Poelstra <apoelstra@wpsoftware.net>
///
/// To the extent possible under law, the author(s) have dedicated all
/// copyright and related and neighboring rights to this software to
/// the public domain worldwide. This software is distributed without
/// any warranty.
///
/// Simplified impl by Parity Team - https://github.com/paritytech/parity-common/blob/master/uint/src/uint.rs
///
/// Features:
///     * mul
///     * div
///     * add
///     * sub
///     * shift left
///     * shift right
///     * bitwise and, xor, or.
///     * compare
///     * if math overflows the contract crashes.
///
/// Would be nice to help with the following TODO list:
/// * pow() , sqrt().
/// * math funcs that don't abort on overflows, but just returns reminders.
/// * Export of low_u128 (see original implementation).
/// * Export of low_u64 (see original implementation).
/// * Gas Optimisation:
///     * We can optimize by replacing bytecode, as far as we know Move VM itself support slices, so probably
///       we can try to replace parts works with (`v0`,`v1`,`v2`,`v3` etc) works.
///     * More?
/// * More tests (see current tests and TODOs i left):
///     * u256_arithmetic_test - https://github.com/paritytech/bigint/blob/master/src/uint.rs#L1338
///     * More from - https://github.com/paritytech/bigint/blob/master/src/uint.rs
/// * Division:
///     * Could be improved with div_mod_small (current version probably would took a lot of resources for small numbers).
///     * Also could be improved with Knuth, TAOCP, Volume 2, section 4.3.1, Algorithm D (see link to Parity above).
module vm::u256 {
    use std::vector;

    // Errors.
    /// When can't cast `Big256` to `u128` (e.g. number too large).
    const ECAST_OVERFLOW: u64 = 0;

    /// When trying to get or put word into Big256 but it's out of index.
    const EWORDS_OVERFLOW: u64 = 1;

    /// When math overflows.
    const EOVERFLOW: u64 = 2;

    /// When attempted to divide by zero.
    const EDIV_BY_ZERO: u64 = 3;

    const EINVALID_LENGTH: u64 = 4;

    // Constants.

    /// Max `u64` value.
    const U64_MAX: u128 = 18446744073709551615;

    /// Max `u128` value.
    const U128_MAX: u128 = 340282366920938463463374607431768211455;

    /// Total words in `Big256` (64 * 4 = 256).
    const WORDS: u64 = 4;

    /// When both `Big256` equal.
    const EQUAL: u8 = 0;

    /// When `a` is less than `b`.
    const LESS_THAN: u8 = 1;

    /// When `b` is greater than `b`.
    const GREATER_THAN: u8 = 2;

    // Data structs.

    /// The `Big256` resource. 256-bits Unsigned Integer
    /// name `U256` throws error when building.
    /// Contains 4 u64 numbers.
    /// 
    /// * internals
    ///  3333333333333333 2222222222222222 1111111111111111 0000000000000000
    ///  [  v3          ] [  v2          ] [  v1          ] [  v0          ]
    struct Big256 has copy, drop, store {
        v0: u64,    // least significant 64 bits
        v1: u64,
        v2: u64,
        v3: u64,    // most significant 64 bits
    }

    /// Double `Big256` used for multiple (to store overflow).
    struct DU256 has copy, drop, store {
        v0: u64,
        v1: u64,
        v2: u64,
        v3: u64,
        v4: u64,
        v5: u64,
        v6: u64,
        v7: u64,
    }    

    /// Convert `Big256` to `u128` value if possible (otherwise it aborts).
    public fun as_u128(a: Big256): u128 {
        assert!(a.v2 == 0 && a.v3 == 0, ECAST_OVERFLOW);
        ((a.v1 as u128) << 64) + (a.v0 as u128)
    }

    /// Convert `Big256` to `u64` value if possible (otherwise it aborts).
    public fun as_u64(a: Big256): u64 {
        assert!(a.v1 == 0 && a.v2 == 0 && a.v3 == 0, ECAST_OVERFLOW);
        a.v0
    }

    /// Compares two `Big256` numbers.
    public fun compare(a: &Big256, b: &Big256): u8 {
        let i = WORDS;
        while (i > 0) {
            i = i - 1;
            let a1 = get(a, i);
            let b1 = get(b, i);

            if (a1 != b1) {
                if (a1 < b1) {
                    return LESS_THAN
                } else {
                    return GREATER_THAN
                }
            }
        };

        EQUAL
    }

    /// Returns a `Big256` from `u64` value.
    public fun from_u64(val: u64): Big256 {
        from_u128((val as u128))
    }

    /// Returns a `Big256` from `u128` value.
    public fun from_u128(val: u128): Big256 {
        let (a2, a1) = split_u128(val);

        Big256 {
            v0: a1,
            v1: a2,
            v2: 0,
            v3: 0,
        }
    }

    public fun to_vec(a: &Big256): vector<u8> {
        let ret: vector<u8> = vector::empty();
        u64_to_u8a8(&mut ret, a.v3);
        u64_to_u8a8(&mut ret, a.v2);
        u64_to_u8a8(&mut ret, a.v1);
        u64_to_u8a8(&mut ret, a.v0);
        ret
    }
    
    // convert to u8 array with length 8
    fun u64_to_u8a8(vec: &mut vector<u8>, a: u64) {
        let i = 0;
        while (i < 8) {
            let byte = (((a >> ((7 - i) * 8)) & 0xff) as u8);
            vector::push_back(vec, byte);
            i = i + 1;
        };
    }

    public fun from_vec(vec: &vector<u8>, offset: u64, len: u64): Big256 {
        assert!(len <= 32, EINVALID_LENGTH);
        let sec_len = len / 8;

        if (sec_len == 4) {
            let v3 = vec_to_u64(vec, offset, 8);
            let v2 = vec_to_u64(vec, offset+8, 8);
            let v1 = vec_to_u64(vec, offset+16, 8);
            let v0 = vec_to_u64(vec, offset+24, 8);
            return Big256 { v0, v1, v2, v3 }
        } else if (sec_len == 3) {
            let rem = len % 8;
            let v3 = vec_to_u64(vec, offset, rem);
            let v2 = vec_to_u64(vec, offset+rem, 8);
            let v1 = vec_to_u64(vec, offset+rem+8, 8);
            let v0 = vec_to_u64(vec, offset+rem+16, 8);
            return Big256 { v0, v1, v2, v3 }
        } else if (sec_len == 2) {
            let rem = len % 8;
            let v2 = vec_to_u64(vec, offset, rem);
            let v1 = vec_to_u64(vec, offset+rem, 8);
            let v0 = vec_to_u64(vec, offset+rem+8, 8);
            return Big256 { v0, v1, v2, v3: 0 }
        } else if (sec_len == 1) {
            let rem = len % 8;
            let v1 = vec_to_u64(vec, offset, rem);
            let v0 = vec_to_u64(vec, offset+rem, 8);
            return Big256 { v0, v1, v2: 0, v3: 0 }
        } else {
            let v0 = vec_to_u64(vec, offset, len);
            return Big256 { v0, v1: 0, v2: 0, v3: 0 }
        }
    }

    fun vec_to_u64(vec: &vector<u8>, offset: u64, size: u64): u64 {
        let ret: u64 = 0;

        let i = 0;
        let pow: u64 = 1;
        while(i < size) {
            if (i > 0) { // to avoid overflow
                pow = pow * 256u64;
            };

            let byte = *vector::borrow(vec, offset + size - i - 1);
            let byte: u64 = (byte as u64) * pow;
            ret = ret + byte;
            i = i + 1;
        };
        ret
    }

    // Public functions.
    /// Adds two `Big256` and returns sum.
    public fun add(a: Big256, b: Big256): Big256 {
        let ret = zero();
        let carry = 0u64;

        let i = 0;
        while (i < WORDS) {
            let a1 = get(&a, i);
            let b1 = get(&b, i);

            if (carry != 0) {
                let (res1, is_overflow1) = overflowing_add(a1, b1);
                let (res2, is_overflow2) = overflowing_add(res1, carry);
                put(&mut ret, i, res2);

                carry = 0;
                if (is_overflow1) {
                    carry = carry + 1;
                };

                if (is_overflow2) {
                    carry = carry + 1;
                }
            } else {
                let (res, is_overflow) = overflowing_add(a1, b1);
                put(&mut ret, i, res);

                carry = 0;
                if (is_overflow) {
                    carry = 1;
                };
            };

            i = i + 1;
        };

        ret
    }

    /// Multiples two `Big256`.
    public fun mul(a: Big256, b: Big256): Big256 {
        let ret = DU256 {
            v0: 0,
            v1: 0,
            v2: 0,
            v3: 0,
            v4: 0,
            v5: 0,
            v6: 0,
            v7: 0,
        };

        let i = 0;
        while (i < WORDS) {
            let carry = 0u64;
            let b1 = get(&b, i);

            let j = 0;
            while (j < WORDS) {
                let a1 = get(&a, j);

                if (a1 != 0 || carry != 0) {
                    let (hi, low) = split_u128((a1 as u128) * (b1 as u128));

                    let overflow = {
                        let existing_low = get_d(&ret, i + j);
                        let (low, o) = overflowing_add(low, existing_low);
                        put_d(&mut ret, i + j, low);
                        if (o) {
                            1
                        } else {
                            0
                        }
                    };

                    carry = {
                        let existing_hi = get_d(&ret, i + j + 1);
                        let hi = hi + overflow;
                        let (hi, o0) = overflowing_add(hi, carry);
                        let (hi, o1) = overflowing_add(hi, existing_hi);
                        put_d(&mut ret, i + j + 1, hi);

                        if (o0 || o1) {
                            1
                        } else {
                            0
                        }
                    };
                };

                j = j + 1;
            };

            i = i + 1;
        };

        let (r, _overflow) = du256_to_u256(ret);
        r
    }

    /// Subtracts two `Big256`, returns result.
    public fun sub(a: Big256, b: Big256): Big256 {
        let ret = zero();

        let carry = 0u64;

        let i = 0;
        while (i < WORDS) {
            let a1 = get(&a, i);
            let b1 = get(&b, i);

            if (carry != 0) {
                let (res1, is_overflow1) = overflowing_sub(a1, b1);
                let (res2, is_overflow2) = overflowing_sub(res1, carry);
                put(&mut ret, i, res2);

                carry = 0;
                if (is_overflow1) {
                    carry = carry + 1;
                };

                if (is_overflow2) {
                    carry = carry + 1;
                }
            } else {
                let (res, is_overflow) = overflowing_sub(a1, b1);
                put(&mut ret, i, res);

                carry = 0;
                if (is_overflow) {
                    carry = 1;
                };
            };

            i = i + 1;
        };

        ret
    }

    /// Divide `a` by `b`.
    public fun div(a: Big256, b: Big256): Big256 {
        let ret = zero();

        let a_bits = bits(&a);
        let b_bits = bits(&b);

        assert!(b_bits != 0, EDIV_BY_ZERO); // DIVIDE BY ZERO.
        if (a_bits < b_bits) {
            // Immidiatelly return.
            return ret
        };

        let shift = a_bits - b_bits;
        b = shl(b, (shift as u8));

        loop {
            let cmp = compare(&a, &b);
            if (cmp == GREATER_THAN || cmp == EQUAL) {
                let index = shift / 64;
                let m = get(&ret, index);
                let c = m | 1 << ((shift % 64) as u8);
                put(&mut ret, index, c);

                a = sub(a, b);
            };

            b = shr(b, 1);
            if (shift == 0) {
                break
            };

            shift = shift - 1;
        };

        ret
    }

    /// Binary xor `a` by `b`.
    fun bitxor(a: Big256, b: Big256): Big256 {
        let ret = zero();

        let i = 0;
        while (i < WORDS) {
            let a1 = get(&a, i);
            let b1 = get(&b, i);
            put(&mut ret, i, a1 ^ b1);

            i = i + 1;
        };

        ret
    }

    /// Binary and `a` by `b`.
    fun bitand(a: Big256, b: Big256): Big256 {
        let ret = zero();

        let i = 0;
        while (i < WORDS) {
            let a1 = get(&a, i);
            let b1 = get(&b, i);
            put(&mut ret, i, a1 & b1);

            i = i + 1;
        };

        ret
    }

    /// Binary or `a` by `b`.
    fun bitor(a: Big256, b: Big256): Big256 {
        let ret = zero();

        let i = 0;
        while (i < WORDS) {
            let a1 = get(&a, i);
            let b1 = get(&b, i);
            put(&mut ret, i, a1 | b1);

            i = i + 1;
        };

        ret
    }

    /// Shift right `a`  by `shift`.
    public fun shr(a: Big256, shift: u8): Big256 {
        let ret = zero();

        let word_shift = (shift as u64) / 64;
        let bit_shift = (shift as u64) % 64;

        let i = word_shift;
        while (i < WORDS) {
            let m = get(&a, i) >> (bit_shift as u8);
            put(&mut ret, i - word_shift, m);
            i = i + 1;
        };

        if (bit_shift > 0) {
            let j = word_shift + 1;
            while (j < WORDS) {
                let m = get(&ret, j - word_shift - 1) + (get(&a, j) << (64 - (bit_shift as u8)));
                put(&mut ret, j - word_shift - 1, m);
                j = j + 1;
            };
        };

        ret
    }

    /// Shift left `a` by `shift`.
    public fun shl(a: Big256, shift: u8): Big256 {
        let ret = zero();

        let word_shift = (shift as u64) / 64;
        let bit_shift = (shift as u64) % 64;

        let i = word_shift;
        while (i < WORDS) {
            let m = get(&a, i - word_shift) << (bit_shift as u8);
            put(&mut ret, i, m);
            i = i + 1;
        };

        if (bit_shift > 0) {
            let j = word_shift + 1;

            while (j < WORDS) {
                let m = get(&ret, j) + (get(&a, j - 1 - word_shift) >> (64 - (bit_shift as u8)));
                put(&mut ret, j, m);
                j = j + 1;
            };
        };

        ret
    }

    /// Returns `Big256` equals to zero.
    public fun zero(): Big256 {
        Big256 {
            v0: 0,
            v1: 0,
            v2: 0,
            v3: 0,
        }
    }

    // Private functions.
    /// Get bits used to store `a`.
    fun bits(a: &Big256): u64 {
        let i = 1;
        while (i < WORDS) {
            let a1 = get(a, WORDS - i);
            if (a1 > 0) {
                return ((0x40 * (WORDS - i + 1)) - (leading_zeros_u64(a1) as u64))
            };

            i = i + 1;
        };

        let a1 = get(a, 0);
        0x40 - (leading_zeros_u64(a1) as u64)
    }

    /// Get leading zeros of a binary representation of `a`.
    fun leading_zeros_u64(a: u64): u8 {
        if (a == 0) {
            return 64
        };

        let a1 = a & 0xFFFFFFFF;
        let a2 = a >> 32;

        if (a2 == 0) {
            let bit = 32;

            while (bit >= 1) {
                let b = (a1 >> (bit-1)) & 1;
                if (b != 0) {
                    break
                };

                bit = bit - 1;
            };

            (32 - bit) + 32
        } else {
            let bit = 64;
            while (bit >= 1) {
                let b = (a >> (bit-1)) & 1;
                if (b != 0) {
                    break
                };
                bit = bit - 1;
            };

            64 - bit
        }
    }

    /// Similar to Rust `overflowing_add`.
    /// Returns a tuple of the addition along with a boolean indicating whether an arithmetic overflow would occur.
    /// If an overflow would have occurred then the wrapped value is returned.
    fun overflowing_add(a: u64, b: u64): (u64, bool) {
        let a128 = (a as u128);
        let b128 = (b as u128);

        let r = a128 + b128;
        if (r > U64_MAX) {
            // overflow
            let overflow = r - U64_MAX - 1;
            ((overflow as u64), true)
        } else {
            (((a128 + b128) as u64), false)
        }
    }

    /// Similar to Rust `overflowing_sub`.
    /// Returns a tuple of the addition along with a boolean indicating whether an arithmetic overflow would occur.
    /// If an overflow would have occurred then the wrapped value is returned.
    fun overflowing_sub(a: u64, b: u64): (u64, bool) {
        if (a < b) {
            let r = b - a;
            ((U64_MAX as u64) - r + 1, true)
        } else {
            (a - b, false)
        }
    }

    /// Extracts two `u64` from `a` `u128`.
    fun split_u128(a: u128): (u64, u64) {
        let a1 = ((a >> 64) as u64);
        let a2 = ((a & 0xFFFFFFFFFFFFFFFF) as u64);

        (a1, a2)
    }

    /// Get word from `a` by index `i`.
    public fun get(a: &Big256, i: u64): u64 {
        if (i == 0) {
            a.v0
        } else if (i == 1) {
            a.v1
        } else if (i == 2) {
            a.v2
        } else if (i == 3) {
            a.v3
        } else {
            abort EWORDS_OVERFLOW
        }
    }

    /// Get word from `DU256` by index.
    fun get_d(a: &DU256, i: u64): u64 {
        if (i == 0) {
            a.v0
        } else if (i == 1) {
            a.v1
        } else if (i == 2) {
            a.v2
        } else if (i == 3) {
            a.v3
        } else if (i == 4) {
            a.v4
        } else if (i == 5) {
            a.v5
        } else if (i == 6) {
            a.v6
        } else if (i == 7) {
            a.v7
        } else {
            abort EWORDS_OVERFLOW
        }
    }

    /// Put new word `val` into `Big256` by index `i`.
    fun put(a: &mut Big256, i: u64, val: u64) {
        if (i == 0) {
            a.v0 = val;
        } else if (i == 1) {
            a.v1 = val;
        } else if (i == 2) {
            a.v2 = val;
        } else if (i == 3) {
            a.v3 = val;
        } else {
            abort EWORDS_OVERFLOW
        }
    }

    /// Put new word into `DU256` by index `i`.
    fun put_d(a: &mut DU256, i: u64, val: u64) {
        if (i == 0) {
            a.v0 = val;
        } else if (i == 1) {
            a.v1 = val;
        } else if (i == 2) {
            a.v2 = val;
        } else if (i == 3) {
            a.v3 = val;
        } else if (i == 4) {
            a.v4 = val;
        } else if (i == 5) {
            a.v5 = val;
        } else if (i == 6) {
            a.v6 = val;
        } else if (i == 7) {
            a.v7 = val;
        } else {
            abort EWORDS_OVERFLOW
        }
    }

    /// Convert `DU256` to `Big256`.
    fun du256_to_u256(a: DU256): (Big256, bool) {
        let b = Big256 {
            v0: a.v0,
            v1: a.v1,
            v2: a.v2,
            v3: a.v3,
        };

        let overflow = false;
        if (a.v4 != 0 || a.v5 != 0 || a.v6 != 0 || a.v7 != 0) {
            overflow = true;
        };

        (b, overflow)
    }

    // Tests.

    #[test]
    fun test_u64_to_u8a8() {
        let a = 0x0011223344556677;
        let dst = vector::empty();

        u64_to_u8a8(&mut dst, a);
        assert!(vector::length(&dst) == 8, 0);
        
        let i = 0;
        while(i < 8) {
            let byte = *vector::borrow(&dst, i);
            assert!(byte == (0x11*(i as u8)), 0);
            i = i + 1;
        }
    }

    #[test]
    fun test_to_vec() {
        let a = Big256 {
            v0: 0x0011223344556677,
            v1: 0x1122334455667788,
            v2: 0x2233445566778899,
            v3: 0x33445566778899aa,
        };

        let dst = to_vec(&a);

        assert!(vector::length(&dst) == 32, 0);
        let i = 0;
        while(i < 8) {
            let byte = *vector::borrow(&dst, i);
            assert!(byte == (0x33 + 0x11*(i as u8)), 0);
            i = i + 1;
        };

        let i = 0;
        while(i < 8) {
            let byte = *vector::borrow(&dst, 8 + i);
            assert!(byte == (0x22 + 0x11*(i as u8)), 0);
            i = i + 1;
        };

        let i = 0;
        while(i < 8) {
            let byte = *vector::borrow(&dst, 16 + i);
            assert!(byte == (0x11 + 0x11*(i as u8)), 0);
            i = i + 1;
        };

        let i = 0;
        while(i < 8) {
            let byte = *vector::borrow(&dst, 24 + i);
            assert!(byte == (0x11*(i as u8)), 0);
            i = i + 1;
        };
    }

    #[test]
    fun test_vec_to_u64() {
        {
            let vec = create_vec(2); // 00 01
            let n = vec_to_u64(&vec, 1, 1);
            assert!(n == 0x0000000000000001, 0);
        };
        {
            let vec = create_vec(2);
            let n = vec_to_u64(&vec, 0, 2);
            assert!(n == 0x000000000000001, 0);
        };
        {
            let vec = create_vec(3);
            let n = vec_to_u64(&vec, 0, 3);
            assert!(n == 0x000000000000102, 0);
        };
        {
            let vec = create_vec(4);
            let n = vec_to_u64(&vec, 0, 4);
            assert!(n == 0x000000000010203, 0);
        };
        {
            let vec = create_vec(5);
            let n = vec_to_u64(&vec, 0, 5);
            assert!(n == 0x000000001020304, 0);
        };
        {
            let vec = create_vec(6);
            let n = vec_to_u64(&vec, 0, 6);
            assert!(n == 0x000000102030405, 0);
        };
        {
            let vec = create_vec(7);
            let n = vec_to_u64(&vec, 0, 7);
            assert!(n == 0x000010203040506, 0);
        };
        {
            let vec = create_vec(8);
            let n = vec_to_u64(&vec, 0, 8);
            assert!(n == 0x0001020304050607, 0);
        };
    }

    #[test]
    fun test_from_vec() {
        let vec = vector::empty();
        let i = 0;
        while(i < 32) {
            vector::push_back(&mut vec, i);
            i = i + 1;
        };

        let a = from_vec(&vec, 0, 32);
        assert!(a.v0 == 0x18191a1b1c1d1e1f, 0);
        assert!(a.v1 == 0x1011121314151617, 0);
        assert!(a.v2 == 0x08090a0b0c0d0e0f, 0);
        assert!(a.v3 == 0x0001020304050607, 0);
    }

    #[test]
    fun test_from_vec_partial() {
        {
            let vec = vector::empty();
            let a = from_vec(&vec, 0, 0);
            assert!(a.v0 == 0x0000000000000000, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = vector::empty();
            vector::push_back(&mut vec, 0x11);
            let a = from_vec(&vec, 0, 1);
            assert!(a.v0 == 0x0000000000000011, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(2);
            let a = from_vec(&vec, 0, 2);
            assert!(a.v0 == 0x0000000000000001, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(3);
            let a = from_vec(&vec, 0, 3);
            assert!(a.v0 == 0x0000000000000102, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(4);
            let a = from_vec(&vec, 0, 4);
            assert!(a.v0 == 0x0000000000010203, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(5);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0000000001020304, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(6);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0000000102030405, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(7);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0000010203040506, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(8);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0001020304050607, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(9);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0102030405060708, 0);
            assert!(a.v1 == 0x0000000000000000, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(10);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0203040506070809, 0);
            assert!(a.v1 == 0x0000000000000001, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(11);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x030405060708090a, 0);
            assert!(a.v1 == 0x0000000000000102, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(12);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0405060708090a0b, 0);
            assert!(a.v1 == 0x0000000000010203, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(13);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x05060708090a0b0c, 0);
            assert!(a.v1 == 0x0000000001020304, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(14);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x060708090a0b0c0d, 0);
            assert!(a.v1 == 0x0000000102030405, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(15);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0708090a0b0c0d0e, 0);
            assert!(a.v1 == 0x0000010203040506, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(16);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x08090a0b0c0d0e0f, 0);
            assert!(a.v1 == 0x0001020304050607, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(17);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x090a0b0c0d0e0f10, 0);
            assert!(a.v1 == 0x0102030405060708, 0);
            assert!(a.v2 == 0x0000000000000000, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(18);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0a0b0c0d0e0f1011, 0);
            assert!(a.v1 == 0x0203040506070809, 0);
            assert!(a.v2 == 0x0000000000000001, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(19);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0b0c0d0e0f101112, 0);
            assert!(a.v1 == 0x030405060708090a, 0);
            assert!(a.v2 == 0x0000000000000102, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(20);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0c0d0e0f10111213, 0);
            assert!(a.v1 == 0x0405060708090a0b, 0);
            assert!(a.v2 == 0x0000000000010203, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(21);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0d0e0f1011121314, 0);
            assert!(a.v1 == 0x05060708090a0b0c, 0);
            assert!(a.v2 == 0x0000000001020304, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(22);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0e0f101112131415, 0);
            assert!(a.v1 == 0x060708090a0b0c0d, 0);
            assert!(a.v2 == 0x0000000102030405, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(23);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x0f10111213141516, 0);
            assert!(a.v1 == 0x0708090a0b0c0d0e, 0);
            assert!(a.v2 == 0x0000010203040506, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(24);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x1011121314151617, 0);
            assert!(a.v1 == 0x08090a0b0c0d0e0f, 0);
            assert!(a.v2 == 0x0001020304050607, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(25);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x1112131415161718, 0);
            assert!(a.v1 == 0x090a0b0c0d0e0f10, 0);
            assert!(a.v2 == 0x0102030405060708, 0);
            assert!(a.v3 == 0x0000000000000000, 0);
        };
        {
            let vec = create_vec(26);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x1213141516171819, 0);
            assert!(a.v1 == 0x0a0b0c0d0e0f1011, 0);
            assert!(a.v2 == 0x0203040506070809, 0);
            assert!(a.v3 == 0x0000000000000001, 0);
        };
        {
            let vec = create_vec(27);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x131415161718191a, 0);
            assert!(a.v1 == 0x0b0c0d0e0f101112, 0);
            assert!(a.v2 == 0x030405060708090a, 0);
            assert!(a.v3 == 0x0000000000000102, 0);
        };
        {
            let vec = create_vec(28);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x1415161718191a1b, 0);
            assert!(a.v1 == 0x0c0d0e0f10111213, 0);
            assert!(a.v2 == 0x0405060708090a0b, 0);
            assert!(a.v3 == 0x0000000000010203, 0);
        };
        {
            let vec = create_vec(29);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x15161718191a1b1c, 0);
            assert!(a.v1 == 0x0d0e0f1011121314, 0);
            assert!(a.v2 == 0x05060708090a0b0c, 0);
            assert!(a.v3 == 0x0000000001020304, 0);
        };
        {
            let vec = create_vec(30);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x161718191a1b1c1d, 0);
            assert!(a.v1 == 0x0e0f101112131415, 0);
            assert!(a.v2 == 0x060708090a0b0c0d, 0);
            assert!(a.v3 == 0x0000000102030405, 0);
        };
        {
            let vec = create_vec(31);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x1718191a1b1c1d1e, 0);
            assert!(a.v1 == 0x0f10111213141516, 0);
            assert!(a.v2 == 0x0708090a0b0c0d0e, 0);
            assert!(a.v3 == 0x0000010203040506, 0);
        };
        {
            let vec = create_vec(32);
            let a = from_vec(&vec, 0, vector::length(&vec));
            assert!(a.v0 == 0x18191a1b1c1d1e1f, 0);
            assert!(a.v1 == 0x1011121314151617, 0);
            assert!(a.v2 == 0x08090a0b0c0d0e0f, 0);
            assert!(a.v3 == 0x0001020304050607, 0);
        };

        {
            let vec = create_vec(64);
            {
                let a = from_vec(&vec, 10, 3);
                assert!(a.v0 == 0x00000000000a0b0c, 0);
                assert!(a.v1 == 0x0000000000000000, 0);
                assert!(a.v2 == 0x0000000000000000, 0);
                assert!(a.v3 == 0x0000000000000000, 0);
            };
            {
                let a = from_vec(&vec, 11, 4);
                assert!(a.v0 == 0x000000000b0c0d0e, 0);
                assert!(a.v1 == 0x0000000000000000, 0);
                assert!(a.v2 == 0x0000000000000000, 0);
                assert!(a.v3 == 0x0000000000000000, 0);
            };
            {
                let a = from_vec(&vec, 5, 20);
                assert!(a.v0 == 0x1112131415161718, 0);
                assert!(a.v1 == 0x090a0b0c0d0e0f10, 0);
                assert!(a.v2 == 0x0000000005060708, 0);
                assert!(a.v3 == 0x0000000000000000, 0);
            };
            {
                let a = from_vec(&vec, 25, 25);
                assert!(a.v0 == 0x2a2b2c2d2e2f3031, 0);
                assert!(a.v1 == 0x2223242526272829, 0);
                assert!(a.v2 == 0x1a1b1c1d1e1f2021, 0);
                assert!(a.v3 == 0x0000000000000019, 0);
            };
        };
    }

    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_from_vec_too_large_vec() {
        let vec = create_vec(33);
        let _a = from_vec(&vec, 0, 33);
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

    #[test]
    fun test_get_d() {
        let a = DU256 {
            v0: 1,
            v1: 2,
            v2: 3,
            v3: 4,
            v4: 5,
            v5: 6,
            v6: 7,
            v7: 8,
        };

        assert!(get_d(&a, 0) == 1, 0);
        assert!(get_d(&a, 1) == 2, 1);
        assert!(get_d(&a, 2) == 3, 2);
        assert!(get_d(&a, 3) == 4, 3);
        assert!(get_d(&a, 4) == 5, 4);
        assert!(get_d(&a, 5) == 6, 5);
        assert!(get_d(&a, 6) == 7, 6);
        assert!(get_d(&a, 7) == 8, 7);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_get_d_overflow() {
        let a = DU256 {
            v0: 1,
            v1: 2,
            v2: 3,
            v3: 4,
            v4: 5,
            v5: 6,
            v6: 7,
            v7: 8,
        };

        get_d(&a, 8);
    }

    #[test]
    fun test_put_d() {
        let a = DU256 {
            v0: 1,
            v1: 2,
            v2: 3,
            v3: 4,
            v4: 5,
            v5: 6,
            v6: 7,
            v7: 8,
        };

        put_d(&mut a, 0, 10);
        put_d(&mut a, 1, 20);
        put_d(&mut a, 2, 30);
        put_d(&mut a, 3, 40);
        put_d(&mut a, 4, 50);
        put_d(&mut a, 5, 60);
        put_d(&mut a, 6, 70);
        put_d(&mut a, 7, 80);

        assert!(get_d(&a, 0) == 10, 0);
        assert!(get_d(&a, 1) == 20, 1);
        assert!(get_d(&a, 2) == 30, 2);
        assert!(get_d(&a, 3) == 40, 3);
        assert!(get_d(&a, 4) == 50, 4);
        assert!(get_d(&a, 5) == 60, 5);
        assert!(get_d(&a, 6) == 70, 6);
        assert!(get_d(&a, 7) == 80, 7);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_put_d_overflow() {
        let a = DU256 {
            v0: 1,
            v1: 2,
            v2: 3,
            v3: 4,
            v4: 5,
            v5: 6,
            v6: 7,
            v7: 8,
        };

        put_d(&mut a, 8, 0);
    }

    #[test]
    fun test_du256_to_u256() {
        let a = DU256 {
            v0: 255,
            v1: 100,
            v2: 50,
            v3: 300,
            v4: 0,
            v5: 0,
            v6: 0,
            v7: 0,
        };

        let (m, overflow) = du256_to_u256(a);
        assert!(!overflow, 0);
        assert!(m.v0 == a.v0, 1);
        assert!(m.v1 == a.v1, 2);
        assert!(m.v2 == a.v2, 3);
        assert!(m.v3 == a.v3, 4);

        a.v4 = 100;
        a.v5 = 5;

        let (m, overflow) = du256_to_u256(a);
        assert!(overflow, 5);
        assert!(m.v0 == a.v0, 6);
        assert!(m.v1 == a.v1, 7);
        assert!(m.v2 == a.v2, 8);
        assert!(m.v3 == a.v3, 9);
    }

    #[test]
    fun test_get() {
        let a = Big256 {
            v0: 1,
            v1: 2,
            v2: 3,
            v3: 4,
        };

        assert!(get(&a, 0) == 1, 0);
        assert!(get(&a, 1) == 2, 1);
        assert!(get(&a, 2) == 3, 2);
        assert!(get(&a, 3) == 4, 3);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_get_aborts() {
        let _ = get(&zero(), 4);
    }

    #[test]
    fun test_put() {
        let a = zero();
        put(&mut a, 0, 255);
        assert!(get(&a, 0) == 255, 0);

        put(&mut a, 1, (U64_MAX as u64));
        assert!(get(&a, 1) == (U64_MAX as u64), 1);

        put(&mut a, 2, 100);
        assert!(get(&a, 2) == 100, 2);

        put(&mut a, 3, 3);
        assert!(get(&a, 3) == 3, 3);

        put(&mut a, 2, 0);
        assert!(get(&a, 2) == 0, 4);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_put_overflow() {
        let a = zero();
        put(&mut a, 6, 255);
    }

    #[test]
    fun test_from_u128() {
        let i = 0;
        while (i < 1024) {
            let big = from_u128(i);
            assert!(as_u128(big) == i, 0);
            i = i + 1;
        };
    }

    #[test]
    fun test_add() {
        let a = from_u128(1000);
        let b = from_u128(500);

        let s = as_u128(add(a, b));
        assert!(s == 1500, 0);

        a = from_u128(U64_MAX);
        b = from_u128(U64_MAX);

        s = as_u128(add(a, b));
        assert!(s == (U64_MAX + U64_MAX), 1);
    }

    #[test]
    fun test_add_overflow() {
        let max = (U64_MAX as u64);

        let a = Big256 {
            v0: max,
            v1: max,
            v2: max,
            v3: max
        };

        let s = add(a, from_u128(1));
        assert!(s.v0 == 0, 0);
        assert!(s.v1 == 0, 1);
        assert!(s.v2 == 0, 2);
        assert!(s.v3 == 0, 3);
    }

    #[test]
    fun test_sub() {
        let a = from_u128(1000);
        let b = from_u128(500);

        let s = as_u128(sub(a, b));
        assert!(s == 500, 0);
    }

    #[test]
    fun test_sub_overflow() {
        let max = (U64_MAX as u64);
        
        let a = from_u128(0);
        let b = from_u128(1);

        let s = sub(a, b);
        assert!(s.v0 == max, 0);
        assert!(s.v1 == max, 1);
        assert!(s.v2 == max, 2);
        assert!(s.v3 == max, 3);
    }

    #[test]
    #[expected_failure(abort_code = 0)]
    fun test_too_big_to_cast_to_u128() {
        let a = from_u128(U128_MAX);
        let b = from_u128(U128_MAX);

        let _ = as_u128(add(a, b));
    }

    #[test]
    fun test_overflowing_add() {
        let (n, z) = overflowing_add(10, 10);
        assert!(n == 20, 0);
        assert!(!z, 1);

        (n, z) = overflowing_add((U64_MAX as u64), 1);
        assert!(n == 0, 2);
        assert!(z, 3);

        (n, z) = overflowing_add((U64_MAX as u64), 10);
        assert!(n == 9, 4);
        assert!(z, 5);

        (n, z) = overflowing_add(5, 8);
        assert!(n == 13, 6);
        assert!(!z, 7);
    }

    #[test]
    fun test_overflowing_sub() {
        let (n, z) = overflowing_sub(10, 5);
        assert!(n == 5, 0);
        assert!(!z, 1);

        (n, z) = overflowing_sub(0, 1);
        assert!(n == (U64_MAX as u64), 2);
        assert!(z, 3);

        (n, z) = overflowing_sub(10, 10);
        assert!(n == 0, 4);
        assert!(!z, 5);
    }

    #[test]
    fun test_split_u128() {
        let (a1, a2) = split_u128(100);
        assert!(a1 == 0, 0);
        assert!(a2 == 100, 1);

        (a1, a2) = split_u128(U64_MAX + 1);
        assert!(a1 == 1, 2);
        assert!(a2 == 0, 3);
    }

    #[test]
    fun test_mul() {
        let a = from_u128(285);
        let b = from_u128(375);

        let c = as_u128(mul(a, b));
        assert!(c == 106875, 0);

        a = from_u128(0);
        b = from_u128(1);

        c = as_u128(mul(a, b));

        assert!(c == 0, 1);

        a = from_u128(U64_MAX);
        b = from_u128(2);

        c = as_u128(mul(a, b));

        assert!(c == 36893488147419103230, 2);

        a = from_u128(U128_MAX);
        b = from_u128(U128_MAX);

        let z = mul(a, b);
        assert!(bits(&z) == 256, 3);
    }

    #[test]
    fun test_mul_overflow() {
        let max = (U64_MAX as u64);

        // a =  0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        let a = Big256 {
            v0: max,
            v1: max,
            v2: max,
            v3: max,
        };

        // z = 0x1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe
        let z = mul(a, from_u128(2));

        assert!(z.v0 == max - 1, 0);
        assert!(z.v1 == max, 0);
        assert!(z.v2 == max, 0);
        assert!(z.v3 == max, 0);
    }

    #[test]
    fun test_zero() {
        let a = as_u128(zero());
        assert!(a == 0, 0);

        let a = zero();
        assert!(a.v0 == 0, 1);
        assert!(a.v1 == 0, 2);
        assert!(a.v2 == 0, 3);
        assert!(a.v3 == 0, 4);
    }

    #[test]
    fun test_or() {
        let a = from_u128(0);
        let b = from_u128(1);
        let c = bitor(a, b);
        assert!(as_u128(c) == 1, 0);

        let a = from_u128(0x0f0f0f0f0f0f0f0fu128);
        let b = from_u128(0xf0f0f0f0f0f0f0f0u128);
        let c = bitor(a, b);
        assert!(as_u128(c) == 0xffffffffffffffffu128, 1);
    }

    #[test]
    fun test_and() {
        let a = from_u128(0);
        let b = from_u128(1);
        let c = bitand(a, b);
        assert!(as_u128(c) == 0, 0);

        let a = from_u128(0x0f0f0f0f0f0f0f0fu128);
        let b = from_u128(0xf0f0f0f0f0f0f0f0u128);
        let c = bitand(a, b);
        assert!(as_u128(c) == 0, 1);

        let a = from_u128(0x0f0f0f0f0f0f0f0fu128);
        let b = from_u128(0x0f0f0f0f0f0f0f0fu128);
        let c = bitand(a, b);
        assert!(as_u128(c) == 0x0f0f0f0f0f0f0f0fu128, 1);
    }

    #[test]
    fun test_xor() {
        let a = from_u128(0);
        let b = from_u128(1);
        let c = bitxor(a, b);
        assert!(as_u128(c) == 1, 0);

        let a = from_u128(0x0f0f0f0f0f0f0f0fu128);
        let b = from_u128(0xf0f0f0f0f0f0f0f0u128);
        let c = bitxor(a, b);
        assert!(as_u128(c) == 0xffffffffffffffffu128, 1);
    }

    #[test]
    fun test_from_u64() {
        let a = as_u128(from_u64(100));
        assert!(a == 100, 0);

        // TODO: more tests.
    }

    #[test]
    fun test_compare() {
        let a = from_u128(1000);
        let b = from_u128(50);

        let cmp = compare(&a, &b);
        assert!(cmp == 2, 0);

        a = from_u128(100);
        b = from_u128(100);
        cmp = compare(&a, &b);

        assert!(cmp == 0, 1);

        a = from_u128(50);
        b = from_u128(75);

        cmp = compare(&a, &b);
        assert!(cmp == 1, 2);
    }

    #[test]
    fun test_leading_zeros_u64() {
        let a = leading_zeros_u64(0);
        assert!(a == 64, 0);

        let a = leading_zeros_u64(1);
        assert!(a == 63, 1);

        // TODO: more tests.
    }

    #[test]
    fun test_bits() {
        let a = bits(&from_u128(0));
        assert!(a == 0, 0);

        a = bits(&from_u128(255));
        assert!(a == 8, 1);

        a = bits(&from_u128(256));
        assert!(a == 9, 2);

        a = bits(&from_u128(300));
        assert!(a == 9, 3);

        a = bits(&from_u128(60000));
        assert!(a == 16, 4);

        a = bits(&from_u128(70000));
        assert!(a == 17, 5);

        let b = from_u64(70000);
        let sh = shl(b, 100);
        assert!(bits(&sh) == 117, 6);

        let sh = shl(sh, 100);
        assert!(bits(&sh) == 217, 7);

        let sh = shl(sh, 100);
        assert!(bits(&sh) == 0, 8);
    }

    #[test]
    fun test_shift_left() {
        let a = from_u128(100);
        let b = shl(a, 2);

        assert!(as_u128(b) == 400, 0);

        // TODO: more shift left tests.
    }

    #[test]
    fun test_shift_right() {
        let a = from_u128(100);
        let b = shr(a, 2);

        assert!(as_u128(b) == 25, 0);

        // TODO: more shift right tests.
    }

    #[test]
    fun test_div() {
        let a = from_u128(100);
        let b = from_u128(5);
        let d = div(a, b);

        assert!(as_u128(d) == 20, 0);

        let a = from_u128(U64_MAX);
        let b = from_u128(U128_MAX);
        let d = div(a, b);
        assert!(as_u128(d) == 0, 1);

        let a = from_u128(U64_MAX);
        let b = from_u128(U128_MAX);
        let d = div(a, b);
        assert!(as_u128(d) == 0, 2);

        let a = from_u128(U128_MAX);
        let b = from_u128(U64_MAX);
        let d = div(a, b);
        assert!(as_u128(d) == 18446744073709551617, 2);
    }

    #[test]
    #[expected_failure(abort_code=3)]
    fun test_div_by_zero() {
        let a = from_u128(1);
        let _z = div(a, from_u128(0));
    }

    #[test]
    fun test_as_u64() {
        let _ = as_u64(from_u64((U64_MAX as u64)));
        let _ = as_u64(from_u128(1));
    }

    #[test]
    #[expected_failure(abort_code=0)]
    fun test_as_u64_overflow() {
        let _ = as_u64(from_u128(U128_MAX));
    }
}