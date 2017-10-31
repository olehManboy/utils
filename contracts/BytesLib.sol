pragma solidity ^0.4.15;


library BytesLib {
    function concat(bytes _preBytes, bytes _postBytes) internal pure returns (bytes) {
        bytes memory tempBytes;
        
        assembly {
            let length := mload(_preBytes)
            mstore(tempBytes, length)
            
            let mc := add(tempBytes, 0x20)
            let end := add(mc, length)
            
            for {
                let cc := add(_preBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }
            
            length := mload(_postBytes)
            mstore(tempBytes, add(length, mload(tempBytes)))
            
            mc := end
            end := add(mc, length)
            
            for {
                let cc := add(_postBytes, 0x20)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }
            
            //update free-memory pointer
            //allocating the array padded to 32 bytes like the compiler does now
            mstore(0x40, and(add(end, 31), not(31)))
        }
        
        return tempBytes;
    }
    
    function concatStorage(bytes storage _preBytes, bytes _postBytes) internal {
        assembly {
            // we know _preBytes_offset is 0
            let fslot := sload(_preBytes_slot)
            let slength := div(and(fslot, sub(mul(0x100, iszero(and(fslot, 1))), 1)), 2)
            let mlength := mload(_postBytes)
            let newlength := add(slength, mlength)
            // slength can contain both the length and contents of the array
            // if length < 32 bytes so let's prepare for that
            // v. http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage
            switch add(lt(slength, 32), lt(newlength, 32))
            case 2 {
                // uint256(bytes_storage) = uint256(bytes_storage) + uint256(bytes_memory) + new_length
                sstore(
                    _preBytes_slot,
                    // all the modifications to the slot are inside this
                    // next block
                    add(
                        // we can just add to the slot contents because the 
                        // bytes we want to change are the LSBs
                        fslot,
                        add(
                            mul(
                                div(
                                    // load the bytes from memory
                                    mload(add(_postBytes, 0x20)),
                                    // zero all bytes to the right
                                    exp(0x100, sub(32, mlength))
                                ),
                                // and now shift left one byte to leave
                                // space for the length in the slot
                                exp(0x100, sub(32, newlength))
                            ),
                            // increase length by the double of the memory
                            // bytes length
                            mul(mlength, 2)
                        )
                    )
                )
            }
            case 1 {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes_slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))
                
                // save new length
                sstore(_preBytes_slot, add(mul(newlength, 2), 1))
                
                let submod := sub(32, slength)
                let mc := add(_postBytes, submod)
                let end := add(add(_postBytes, 0x20), mlength)
                let mask := sub(exp(0x100, submod), 1)
                
                sstore(
                    sc,
                    add(
                        and(
                            fslot,
                            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00
                        ),
                        and(mload(mc), mask)
                    )
                )
                
                for { 
                    mc := add(mc, 0x20)
                    sc := add(sc, 1)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }
            }
            default {
                // get the keccak hash to get the contents of the array
                mstore(0x0, _preBytes_slot)
                let sc := add(keccak256(0x0, 0x20), div(slength, 32))
                
                // save new length
                sstore(_preBytes_slot, add(mul(newlength, 2), 1))
                
                let slengthmod := mod(slength, 32)
                let submod := sub(32, slengthmod)
                let mc := add(_postBytes, submod)
                let end := add(mc, mlength)
                let mask := sub(exp(0x100, submod), 1)
                
                sstore(sc, add(sload(sc), and(mload(mc), mask)))
                
                for { 
                    mc := add(mc, 0x20)
                } lt(mc, end) {
                    sc := add(sc, 1)
                    mc := add(mc, 0x20)
                } {
                    sstore(sc, mload(mc))
                }
            }
        }
    }
    
    function slice(bytes _bytes, uint _start, uint _length) internal  pure returns (bytes) {
        require(_bytes.length >= (_start + _length));
        
        bytes memory tempBytes;
        
        assembly {
            let lengthmod := and(_length, 31)
            
            let mc := add(tempBytes, lengthmod)
            let end := add(mc, _length)
            
            for {
                let cc := add(add(_bytes, lengthmod), _start)
            } lt(mc, end) {
                mc := add(mc, 0x20)
                cc := add(cc, 0x20)
            } {
                mstore(mc, mload(cc))
            }
            
            mstore(tempBytes, _length)
            
            //update free-memory pointer
            //allocating the array padded to 32 bytes like the compiler does now
            mstore(0x40, and(add(mc, 31), not(31)))
        }
        
        return tempBytes;
    }
    
    function toAddress(bytes _bytes, uint _start) internal  pure returns (address) {
        require(_bytes.length >= (_start + 20));
        address tempAddress;
        
        assembly {
            mstore(tempAddress, div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000))
        }
        
        return tempAddress;
    }
    
    function toUint(bytes _bytes, uint _start) internal  pure returns (uint256) {
        require(_bytes.length >= (_start + 32));
        uint256 tempUint;
        
        assembly {
            mstore(tempUint, mload(add(add(_bytes, 0x20), _start)))
        }
        
        return tempUint;
    }
}
