object "ERC1155" {
    //Executable code of ERC1155 object (constructor)
    code {
        //Copy "runtime" object to memory
        datacopy(0, dataoffset("runtime"), datasize("runtime"))
        //then return copied data from memory (== codecopy in EVM)
        return(0, datasize("runtime"))
    }

    //Bulk of ERC1155 contract
    object "runtime" {
        code {
            //Get function selector from calldata
            let fnSelector := shr(0xE0, calldataload(0x00))

            //Function dispatching
            switch fnSelector

            /*----------------------------------------------------------------------------------*/
            /*----------------------------    External functions    ----------------------------*/
            /*----------------------------------------------------------------------------------*/
            
            //setURI(string)
            case 0x02fe5305 {}

            //setApprovalForAll(address,bool)
            case 0xa22cb465 {
                let operator := decodeAsAddress(0)
                let approved := decodeAsUint(1)
                _setApprovalForAll(caller(), operator, approved)
            }

            //safeTransferFrom(address,address,uint256,uint256,bytes)
            case 0xf242432a {}

            //safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
            case 0x2eb2c2d6 {}

            //mint(address,uint256muint256,bytes)
            case 0x731133e9 {}

            //batchMint(address,uint256[],uint256[],bytes)
            case 0xb48ab8b6 {}

            //burn(address,uint256,uint256)
            case 0xf5298aca {}

            //batchBurn(address,uint256[],uint256[])
            case 0xf6eb127a {}

            /*------------------------------------------------------------------------------*/
            /*----------------------------    View functions    ----------------------------*/
            /*------------------------------------------------------------------------------*/

            //uri(uint256) -> string
            case 0x0e89341c {}

            //balanceOfBatch(address[],uint256[]) -> uint256[]
            case 0x4e1273f4 {}

            //supportsInterface(bytes4) -> bool
            case 0x01ffc9a7 {}

            //balanceOf(address,uint256) -> uint256
            case 0x00fdd58e {
                let addr := decodeAsAddress(0)
                let tokenId := decodeAsUint(1)
                let bal := _getBalanceOf(addr, tokenId)
                returnUint(bal)
            }

            //isApprovedForAll(address,address) -> bool
            case 0xe985e9c5 {
                let owner := decodeAsAddress(0)
                let operator := decodeAsAddress(1)
                let all := _getIsApprovedForAll(owner, operator)
                returnUint(all)
            }

            //technically we do not need a fallback, but here we just do nothing
            default {
                return(0x00, 0x00)
            }

            /*----------------------------------------------------------------------------------*/
            /*----------------------------    Internal functions    ----------------------------*/
            /*----------------------------------------------------------------------------------*/

            /*------------------------------------------------------------------------------*/
            /*----------------------------    Storage layout    ----------------------------*/
            /*------------------------------------------------------------------------------*/
            
            function uriSlot() -> slot { slot := 0 }
            function balanceOfSlot() -> slot { slot := 1 }
            function isApprovedForAllSlot() -> slot { slot := 2 }

            /*------------------------------------------------------------------------------*/
            /*----------------------------    Storage access    ----------------------------*/
            /*------------------------------------------------------------------------------*/

            function _getUri(id) {
                //Location of uri value in storage (keccak256(abi.encode(slot)))
                mstore(0x00, uriSlot())
                let dataOffset := keccak256(0x00, 0x20)

                //Return: offset, length, uri value (per abi specs)
                mstore(0x00, 0x20)                              //copy offset to memory
                let valueLen := sload(uriSlot())
                mstore(0x20, valueLen)                          //copy length to memory

                //Copy uri value to memory. 
                //We need to account for uri value that exceeds 32 bytes, while dealing in 32 byte words.
                let wordChunk, lenCoverage                      //0, 0
                for {} lt(lenCoverage, valueLen) {} {
                    wordChunk := sload(dataOffset)              //Load 32 bytes of uri value
                    mstore(add(lenConverage, 0x40), wordChunk)  //Copy to memory, add 0x40 for offset + length
                    dataOffset := add(dataOffset, 0x20)         //Move to next 32 bytes of uri value
                    lenCoverage := add(lenCoverage, 0x20)       //Advance length coverage by 32 bytes
                }

                return(0, add(0x40, lenConverage))              //(eg: offset(0x20) + length(0x20) + uri value(0x20))
            }

            function _setUri() {
                //calldata: selector, offset, length, value
                let uriOffset := decodeAsUint(0)
                let uriLen := calldataload(add(0x04, uriOffset))

                //Uri length is stored at slot
                //Uri value location: keccak256(abi.encodePacked(slot))
                sstore(uriSlot(), uriLen)
                mstore(0x00, uriSlot())
                let dataOffset := keccak256(0x00, 0x20)

                //Copy uri value to storage
                //We need to account for uri value that exceeds 32 bytes, while dealing in 32 byte words.
                let valueByteWordLen := sub(calldatasize(), 0x44)               //(eg: 0x64 - 0x44 = 0x20)
                let wordChunkPos := add(0x20, add(0x04, uriOffset))             //(eg: 0x20 + 0x24 = 0x44)
                for { let i := 0x00 } lt(i, valueByteWordLen) { i := add(i, 0x20) } {
                    sstore(dataOffset, calldataload(wordChunkPos))
                    wordChunkPos := add(wordChunkPos, 0x20)
                    dataOffset := add(dataOffset, 0x20)
                }
                emitURI()
            }

            //Nested mapping: (firstKey => (secondKey => value))
            //Nested value storage location: keccak256(secondKey.concat(keccak256(firstKey.concat(mappingStorageSlot))))
            function _getBalanceOf(addr, tokenId) -> bal {
                //Outer location: keccak256(address.concat(balanceOfSlot()))
                mstore(0x00, addr)
                mstore(0x20, balanceOfSlot())
                let outerLoc := keccak256(0x00, 0x40)

                //Inner location: keccak256(tokenId.concat(outerLoc))
                mstore(0x00, tokenId)
                mstore(0x20, outerLoc)
                let innerLoc := keccak256(0x00, 0x40)

                bal := sload(innerLoc)
            }

            function _safeAddBalanceOf(toAddr, tokenId, amount) {
                //Get location of toAddr's balance of tokenId in storage
                mstore(0x00, toAddr)
                mstore(0x20, balanceOfSlot())
                let outerLoc := keccak256(0x00, 0x40)
                mstore(0x00, tokenId)
                mstore(0x20, outerLoc)
                let innerLoc := keccak256(0x00, 0x40)

                //Update balance in storage
                let currBal := sload(innerLoc)
                sstore(innerLoc, safeAdd(currBal, amount))
            }

            function _safeSubBalanceOf(fromAddr, tokenId, amount) {
                //Get location of fromAddr's balance of tokenId in storage
                mstore(0x00, fromAddr)
                mstore(0x20, balanceOfSlot())
                let outerLoc := keccak256(0x00, 0x40)
                mstore(0x00, tokenId)
                mstore(0x20, outerLoc)
                let innerLoc := keccak256(0x00, 0x40)

                //Update balance in storage
                let currBal := sload(innerLoc)
                sstore(innerLoc, safeSub(currBal, amount))
            }

            //Nested mapping: (firstKey => (secondKey => value))
            //Nested value storage location: keccak256(secondKey.concat(keccak256(firstKey.concat(mappingStorageSlot))))
            function _getIsApprovedForAll(owner, operator) -> all {
                //Outer location: keccak256(owner.concat(isApprovedForAllSlot()))
                mstore(0x00, owner)
                mstore(0x20, isApprovedForAllSlot())
                let outerLoc := keccak256(0x00, 0x40)

                //Inner location: keccak256(operator.concat(outerLoc))
                mstore(0x00, operator)
                mstore(0x20, outerLoc)
                let innerLoc := keccak256(0x00, 0x40)

                all := sload(innerLoc)
            }

            function _setApprovalForAll(owner, operator, approved) { 
                //Get location of owner's approval for operator in storage
                mstore(0x00, owner)
                mstore(0x20, isApprovedForAllSlot())
                let outerLoc := keccak256(0x00, 0x40)
                mstore(0x00, operator)
                mstore(0x20, outerLoc)
                let innerLoc := keccak256(0x00, 0x40)

                //Update approval in storage
                sstore(innerLoc, approved)

                emitApprovalForAll(owner, operator, approved)
            }

            /*------------------------------------------------------------------------------*/
            /*----------------------------    Event emitters    ----------------------------*/
            /*------------------------------------------------------------------------------*/
            //Non-indexed event args need to be stored in memory and they are loaded into the LOG opcodes
            //through the offset and size arguments. Topics are the indexed arguments.

            //event URI(string value, uint256 indexed id);
            function emitURI() {
                mstore(0x00, uriSlot())
                let dataOffset := keccak256(0x00, 0x20)

                //Store uri offset, length and value in memory for LOG (per abi specs)
                mstore(0x00, 0x20)                                              //offset
                mstore(0x20, sload(uriSlot()))                                  //length
                mstore(0x40, sload(dataoffset))                                 //uri value

                //keccak256("URI(string,uint256)")
                let signatureHash := 0x6bb7ff708619ba0610cba295a58592e0451dee2622938c8755667688daf3529b

                //LOG1(offset, size, topic)
                log1(0x00, 0x60, signatureHash)
            }

            //event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
            function emitApprovalForAll(owner, operator, approved) {
                mstore(0x00, approved)

                //keccak256("ApprovalForAll(address,address,bool)")
                let signatureHash := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31

                //LOG3(offset, size, topic1, topic2, topic3)
                log3(0x00, 0x20, signatureHash, owner, operator)
            }

            //event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
            function emitTransferSingle(operator, from, to, id, value) {
                mstore(0x00, id)
                mstore(0x20, value)

                //keccak256("TransferSingle(address,address,address,uint256,uint256)")
                let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62

                //LOG4(offset, size, topic1, topic2, topic3, topic4)
                log4(0x00, 0x40, signatureHash, operator, from, to)
            }

            //function safeBatchTransferFrom(address from, address to, uint256[] ids, uint256[] values, bytes data)
            //event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
            function emitTransferBatch(
                operator, 
                from, 
                to, 
                idsLength,
                idsLoc, 
                valuesLength,
                valuesLoc
            ) {
                //From the abi spec, the head parts of all arguments come first, so for dynamic types, this is the offset.
                //To copy to memory:
                //0x00: 0x20 = (offset for ids @ 0x40)
                //0x20: 0x40 = (offset for values @ 0x60 + (no. of ids * 32 byte words)
                //0x40: 0x60 = (ids length, eg: 0x02)
                //0x60: 0x80 = ids[0]
                //0x80: 0xa0 = ids[1]
                //0xa0: 0xc0 = (values length)
                //0xc0: <0xc0 + numValues*0x20> = [...values]

                mstore(0x00, 0x40)                                              //offset for ids
                mstore(0x20, add(0x60, mul(idsLength, 0x20)))                   //offset for values
                let numOfWordsForIds := mul(add(idsLength, 0x01), 0x20)         //Words: id length word + (1 word per id)
                
                //calldatacopy(memOffsetCopyTo, calldataOffsetCopyFrom, numBytesToCopy)
                calldatacopy(0x40, idsLoc, numOfWordsForIds)                    //Copy words for ids to memory

                let numOfWordsForValues := mul(add(valuesLength, 0x01), 0x20)   //Words: values length word + (1 word per value
                let valuesMemOffsetToCopyTo := add(0x40, numOfWordsForIds)

                calldatacopy(                                                   //Copy words for values to memory    
                    valuesMemOffsetToCopyTo, 
                    valuesLoc, 
                    numOfWordsForValues
                )
                
                //keccak256("TransferBatch(address,address,address,uint256[],uint256[])")
                let signatureHash := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb

                let memSize := mul(0x20, add(add(idsLength, valuesLength), 4))   //4 = 2 offset words + 2 length words

                //LOG4(offset, size, topic1, topic2, topic3, topic4)
                log4(0x00, memSize, signatureHash, operator, from, to)
            }

            /*---------------------------------------------------------------------------------*/
            /*----------------------------    Calldata encoding    ----------------------------*/
            /*---------------------------------------------------------------------------------*/
            
            function returnUint(i) {
                mstore(0x00, i)
                return(0x00, 0x20)
            }

            function returnTrue() {
                returnUint(0x01)
            }

            //Loads the 32 byte word from calldata at the specified offset
            //calldataArgs: 0x04 + (offset * 0x20). The latter calculates the offset for the specific arg in calldata
            //Reverts if calldatasize is less than expected position + 32 bytes, meaning calldata is incomplete.
            //Must be able to read 32 bytes from calldata.
            function decodeAsUint(offset) -> v {
                let pos := add(0x04, mul(offset, 0x20))
                if lt(calldatasize(), add(pos, 0x20)) {
                    revert(0, 0)
                }
                v := calldataload(pos)
            }

            //Checks if address is valid (withibn uint160 max), reverts if not
            function decodeAsAddress(offset) -> v {
                v := decodeAsUint(offset)
                if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
                    revert(0, 0)
                }
            }

            /*-----------------------------------------------------------------------*/
            /*----------------------------    Utility    ----------------------------*/
            /*-----------------------------------------------------------------------*/

            //negation: if condition == 0, reverts
            function require(condition) {
                if iszero(condition) {
                    revert(0x00, 0x00)
                }
            }
            
            //Overflow safe: res cannot be less than a or b
            function safeAdd(a,b) -> res {
                res := add(a, b)
                if or(lt(res, a), lt(res, b)) {
                    revert(0x00, 0x00)
                }
            }

            //Underflow safe: res cannot be greater than a
            function safeSub(a, b) -> res {
                res := sub(a, b)
                if gt(res, a) {
                    revert(0x00, 0x00)
                }
            }

            //!(a > b)
            function lte(a, b) -> res {
                res := iszero(gt(a, b))
            }

            //!(a < b)
            function gte(a, b) -> res {
                res := iszero(lt(a, b))
            }

            function revertIfZeroAddress(addr) {
                require(addr)
            }
        }
    }
}