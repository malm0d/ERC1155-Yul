//Questions:
//https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html#bytes-and-string
//In yul, do we need to adhere to this?

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
            case 0x02fe5305 {
                _setUri()
            }

            //setApprovalForAll(address,bool)
            case 0xa22cb465 {
                let operator := decodeAsAddress(0)
                let approved := decodeAsUint(1)
                _setApprovalForAll(caller(), operator, approved)
            }

            //safeTransferFrom(address,address,uint256,uint256,bytes)
            case 0xf242432a {
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)
                let id := decodeAsUint(2)
                let amount := decodeAsUint(3)
                let dataOffset := decodeAsUint(4)
                _safeTransferFrom(from, to, id, amount, dataOffset)
            }

            //safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
            case 0x2eb2c2d6 {
                let from := decodeAsAddress(0)
                let to := decodeAsAddress(1)
                let idsOffset := decodeAsUint(2)
                let amountsOffset := decodeAsUint(3)
                let dataOffset := decodeAsUint(4)
                _safeBatchTransferFrom(from, to, idsOffset, amountsOffset, dataOffset)
            }

            //mint(address,uint256,uint256,bytes)
            case 0x731133e9 {
                let to := decodeAsAddress(0)
                let id := decodeAsUint(1)
                let amount := decodeAsUint(2)
                let dataOffset := decodeAsUint(3)
                _mint(to, id, amount, dataOffset)
            }

            //batchMint(address,uint256[],uint256[],bytes)
            case 0xb48ab8b6 {
                let to := decodeAsAddress(0)
                let idsOffset := decodeAsUint(1)
                let amountsOffset := decodeAsUint(2)
                let dataOffset := decodeAsUint(3)
                _batchMint(to, idsOffset, amountsOffset, dataOffset)
            }

            //burn(address,uint256,uint256)
            case 0xf5298aca {
                let from := decodeAsAddress(0)
                let id := decodeAsUint(1)
                let amount := decodeAsUint(2)
                _burn(from, id, amount)
            }

            //batchBurn(address,uint256[],uint256[])
            case 0xf6eb127a {
                let from := decodeAsAddress(0)
                let idsOffset := decodeAsUint(1)
                let amountsOffset := decodeAsUint(2)
                _batchBurn(from, idsOffset, amountsOffset)
            }

            /*------------------------------------------------------------------------------*/
            /*----------------------------    View functions    ----------------------------*/
            /*------------------------------------------------------------------------------*/

            //uri(uint256) -> string
            case 0x0e89341c {
                _getUri(decodeAsUint(0))                        //Returns from function
            }

            //supportsInterface(bytes4) -> bool
            case 0x01ffc9a7 {
                returnUint(_supportsInterface())
            }

            //balanceOf(address,uint256) -> uint256
            case 0x00fdd58e {
                let addr := decodeAsAddress(0)
                let tokenId := decodeAsUint(1)
                let bal := _getBalanceOf(addr, tokenId)
                returnUint(bal)
            }

            //balanceOfBatch(address[],uint256[]) -> uint256[]
            case 0x4e1273f4 {
                let addrOffset := decodeAsUint(0)
                let idsOffset := decodeAsUint(1)
                _balanceOfBatch(addrOffset, idsOffset)          //Returns from function
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
            
            function _supportsInterface() -> res {
                //bytes4: 0xaabbccdd
                let IERC1155InterfaceId := 0xd9b67a2600000000000000000000000000000000000000000000000000000000
                let IERC1155MetdataURIInterfaceId := 0xd9b67a2600000000000000000000000000000000000000000000000000000000
                let IERC165InterfaceId := 0x01ffc9a700000000000000000000000000000000000000000000000000000000

                let interfaceId := calldataload(0x04)
                res := or(
                    eq(interfaceId, IERC1155MetdataURIInterfaceId), 
                    or(
                        eq(interfaceId, IERC165InterfaceId), 
                        eq(interfaceId, IERC1155InterfaceId)
                    )
                )
            }

            function _balanceOfBatch(addrOffset, idsOffset) {
                let addrStartPos := add(0x04, addrOffset)       //StartPos == length position (actual data follows after)
                let idsStartPos := add(0x04, idsOffset)

                let addrLen := calldataload(addrStartPos)
                let idsLen := calldataload(idsStartPos)

                // require(eq(addrLen, idsLen))
                if iszero(eq(addrLen, idsLen)) {
                    mstore(0x00, 0x20)
                    mstore(0x20, 0x0f)
                    mstore(0x40, shl(136, 0x4c454e4754485f4d49534d41544348))  //"LENGTH_MISMATCH"
                    revert(0x00, 0x60)
                }

                let addrValuePointer := add(addrStartPos, 0x20) //Pointer to the actual data
                let idsValuePointer := add(idsStartPos, 0x20)   //Pointer to the actual data

                //return array: [addr1_bal, addr2_bal, ...]
                for { let i := 0 } lt(i, addrLen) { i := add(i, 0x01) } {
                    let addr := calldataload(addrValuePointer)
                    let id := calldataload(idsValuePointer)
                    let bal := _getBalanceOf(addr, id)

                    //store each bal starting from 0x40 (reserve 0x00 for offset, 0x20 for length)
                    //eg, first bal @ 0x40, second bal @ 0x60, ...
                    let memOffsetCopyTo := add(0x40, mul(i, 0x20))
                    mstore(memOffsetCopyTo, bal)

                    //advance pointers
                    addrValuePointer := add(addrValuePointer, 0x20)
                    idsValuePointer := add(idsValuePointer, 0x20)
                }

                let arrayValuesWordCount := mul(addrLen, 0x20)      //each bal is a word (32 bytes)

                //return: offset, length, array items
                mstore(0x00, 0x20)
                mstore(0x20, addrLen)
                return(0x00, add(0x40, arrayValuesWordCount))
            }

            function _safeTransferFrom(from, to, id, amount, dataOffset) {
                revertIfZeroAddress(to)
                require(or(eq(caller(), from), _getIsApprovedForAll(from, caller())))
                //need to throw "NOT_AUTHORIZED"

                //Update balances
                _safeSubBalanceOf(from, id, amount)
                _safeAddBalanceOf(to, id, amount)

                emitTransferSingle(caller(), from, to, id, amount)

                //onERC1155REceived callback
                if _hasCode(to) {
                    _checkOnERC1155Received(caller(), from, to, id, amount, dataOffset)
                }
            }

            //onERC1155Received(address,address,uint256,uint256,bytes) -> bytes4
            //onERC1155Received(operator,from,id,amount,data)
            function _checkOnERC1155Received(operator, from, to, id, amount, dataOffset) {
                let onERC1155ReceivedSelector := 0xf23a6e6100000000000000000000000000000000000000000000000000000000

                //Prep calldata
                mstore(0, onERC1155ReceivedSelector)
                mstore(0x04, operator)
                mstore(0x24, from)
                mstore(0x44, id)
                mstore(0x64, amount)
                mstore(0x84, 0xa0)                                              //offset for data in calldata @ 0x84: 0xa0

                let dataStartPos := add(dataOffset, 0x04)                       //Pointer to the actual data
                let dataSizeInWords := sub(calldatasize(), dataStartPos)        //Length word + data value word(s)

                //calldatacopy(memOffsetCopyTo, calldataOffsetCopyFrom, numBytesToCopy)
                calldatacopy(0xa4, dataStartPos, dataSizeInWords)               //Copy data to memory @ 0xa4

                //call(gas, addr, wei, argsOffset, argsSize, retOffset, retSize))
                //For argsSize, add 0x20 to calldatasize since no. of args in `_safeTransferFrom` is 5.
                //(This calldata is from when `_safeTransferFrom` is called).
                //Checks if the external call fails, if so, check if any return data
                if iszero(call(gas(), to, 0, 0x00, add(0x20, calldatasize()), 0x00, 0x20)) {
                    if returndatasize() {
                        //Bubble up revert reason
                        //returndatacopy(destOffset, retDataOffset, copySize)
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    revert(0x00, 0x00)  //is this needed?
                }

                //Check if the return value is equal to the selector
                let retData := mload(0x00)
                if iszero(eq(retData, onERC1155ReceivedSelector)) {
                    mstore(0x00, 0x20)
                    mstore(0x20, 0x10)
                    mstore(0x40, shl(128, 0x554e534146455f524543495049454e54))  //"UNSAFE_RECIPIENT"
                    revert(0x00, 0x60)
                }
            }

            function _safeBatchTransferFrom(from, to, idsOffset, amountsOffset, dataOffset) {
                revertIfZeroAddress(to)

                let idsStartPos := add(0x04, idsOffset)         //StartPos == length position (actual data follows after)
                let amountsStartPos := add(0x04, amountsOffset)

                let idsLen := calldataload(idsStartPos)
                let amountsLen := calldataload(amountsStartPos)
                if iszero(eq(idsLen, amountsLen)) {
                    mstore(0x00, 0x20)
                    mstore(0x20, 0x0f)
                    mstore(0x40, shl(136, 0x4c454e4754485f4d49534d41544348))    //"LENGTH_MISMATCH"
                    revert(0x00, 0x60)
                }

                require(or(eq(caller(), from), _getIsApprovedForAll(from, caller())))
                //need to throw "NOT_AUTHORIZED"

                let idsValuePointer := add(idsStartPos, 0x20)                   //Pointer to the actual data
                let amountsValuePointer := add(amountsStartPos, 0x20)           //Pointer to the actual data

                for { let i := 0 } lt(i, idsLen) { i := add(i, 0x01) } {
                    let id := calldataload(idsValuePointer)
                    let amount := calldataload(amountsValuePointer)

                    //update balances
                    _safeSubBalanceOf(from, id, amount)
                    _safeAddBalanceOf(to, id, amount)

                    //advance pointers
                    idsValuePointer := add(idsValuePointer, 0x20)
                    amountsValuePointer := add(amountsValuePointer, 0x20)
                }

                emitTransferBatch(caller(), from, to, idsLen, idsStartPos, amountsLen, amountsStartPos)

                //onERC1155BatchReceived callback
                if _hasCode(to) {
                    _checkOnERC1155BatchReceived(caller(), from, to, idsStartPos, idsLen, amountsLen)
                }
            }

            //onERC1155BatchReceived(address,address,uint256[],uint256[],bytes) -> bytes4
            //onERC1155BatchReceived(operator,from,ids,amounts,data)
            //
            //Technically, we can copy directly from the calldata from idsStartPos (0xa4) onwards,
            //since calldata:
            //  0x04: 0x24 = from
            //  0x24: 0x44 = to
            //  0x44: 0x64 = ids offset
            //  0x64: 0x84 = amounts offset
            //  0x84: 0xa4 = data offset
            //  0xa4: ~ = ids length, ids values, amounts length, amounts values, data length, data values
            function _checkOnERC1155BatchReceived(operator, from, to, idsStartPos, idsLen, amountsLen) {
                let onERC1155BatchReceivedSelector := 0xbc197c8100000000000000000000000000000000000000000000000000000000

                //Prep calldata. For dynamic data, head parts come first (abi spec)
                mstore(0, onERC1155BatchReceivedSelector)
                mstore(0x04, operator)
                mstore(0x24, from)
                mstore(0x44, 0xa0)                          //offset for ids in calldata @ 0x44: 0xa0                         
                mstore(0x64, add(0xc0, mul(idsLen, 0x20)))  //offset for amounts @ 0x64: 0xc0 + (idsLen * 0x20)
                mstore(0x84, add(0xe0, mul(add(idsLen, amountsLen), 0x20)))  //offset for data in calldata @ 0x84: 0xe0 + ((idsLen + amountsLen) * 0x20)                                     
                
                //copy rest of calldata to memory
                //calldatacopy(memOffsetCopyTo, calldataOffsetCopyFrom, numBytesToCopy)
                calldatacopy(0xa4, idsStartPos, sub(calldatasize(), idsStartPos))

                //call(gas, addr, wei, argsOffset, argsSize, retOffset, retSize))
                //For argsSize, add 0x20 to calldatasize since no. of args in `_safeBatchTransferFrom` is 5.
                //(This calldata is from when `_safeBatchTransferFrom` is called).
                //Checks if the external call fails, if so, check if any return data
                if iszero(call(gas(), to, 0, 0x00, add(0x20, calldatasize()), 0x00, 0x20)) {
                    if returndatasize() {
                        //Bubble up revert reason
                        //returndatacopy(destOffset, retDataOffset, copySize)
                        revert(0x00, returndatasize())
                    }
                    revert(0x00, 0x00)
                }

                //Check if the return value is equal to the selector
                let retData := mload(0x00)
                if iszero(eq(retData, onERC1155BatchReceivedSelector)) {
                    mstore(0x00, 0x20)
                    mstore(0x20, 0x10)
                    mstore(0x40, shl(128, 0x554e534146455f524543495049454e54))  //"UNSAFE_RECIPIENT"
                    revert(0x00, 0x60)
                }

            }

            function _mint(to, id, amount, dataOffset) { 
                revertIfZeroAddress(to)

                //Update balance
                _safeAddBalanceOf(to, id, amount)
                emitTransferSingle(caller(), 0, to, id, amount)

                //onERC1155REceived callback
                if _hasCode(to) {
                    _checkOnERC1155Received(caller(), 0, to, id, amount, dataOffset)
                }
            }

            function _batchMint(to, idsOffset, amountsOffset, dataOffset) { 
                revertIfZeroAddress(to)

                let idsStartPos := add(0x04, idsOffset)         //StartPos == length position (actual data follows after)
                let amountsStartPos := add(0x04, amountsOffset)

                let idsLen := calldataload(idsStartPos)
                let amountsLen := calldataload(amountsStartPos)
                if iszero(eq(idsLen, amountsLen)) {
                    mstore(0x00, 0x20)
                    mstore(0x20, 0x0f)
                    mstore(0x40, shl(136, 0x4c454e4754485f4d49534d41544348))    //"LENGTH_MISMATCH"
                    revert(0x00, 0x60)
                }

                let idsValuePointer := add(idsStartPos, 0x20)                   //Pointer to the actual data
                let amountsValuePointer := add(amountsStartPos, 0x20)           //Pointer to the actual data

                for { let i := 0 } lt(i, idsLen) { i := add(i, 0x01) } {
                    let id := calldataload(idsValuePointer)
                    let amount := calldataload(amountsValuePointer)

                    //update balances
                    _safeAddBalanceOf(to, id, amount)

                    //advance pointers
                    idsValuePointer := add(idsValuePointer, 0x20)
                    amountsValuePointer := add(amountsValuePointer, 0x20)
                }

                emitTransferBatch(caller(), 0, to, idsLen, idsStartPos, amountsLen, amountsStartPos)

                //onERC1155BatchReceived callback
                if _hasCode(to) {
                    _checkOnERC1155BatchReceived(caller(), 0, to, idsStartPos, idsLen, amountsLen)
                }
            }

            function _burn(from, id, amount) {
                revertIfZeroAddress(from)
                
                //Update balance
                _safeSubBalanceOf(from, id, amount)
                emitTransferSingle(caller(), from, 0, id, amount)
             }

            function _batchBurn(from, idsOffset, amountsOffset) {
                revertIfZeroAddress(from)

                let idsStartPos := add(0x04, idsOffset)         //StartPos == length position (actual data follows after)
                let amountsStartPos := add(0x04, amountsOffset)

                let idsLen := calldataload(idsStartPos)
                let amountsLen := calldataload(amountsStartPos)
                if iszero(eq(idsLen, amountsLen)) {
                    mstore(0x00, 0x20)
                    mstore(0x20, 0x0f)
                    mstore(0x40, shl(136, 0x4c454e4754485f4d49534d41544348))    //"LENGTH_MISMATCH"
                    revert(0x00, 0x60)
                }

                let idsValuePointer := add(idsStartPos, 0x20)                   //Pointer to the actual data
                let amountsValuePointer := add(amountsStartPos, 0x20)           //Pointer to the actual data

                for { let i := 0 } lt(i, idsLen) { i := add(i, 0x01) } {
                    let id := calldataload(idsValuePointer)
                    let amount := calldataload(amountsValuePointer)

                    //update balances
                    _safeSubBalanceOf(from, id, amount)

                    //advance pointers
                    idsValuePointer := add(idsValuePointer, 0x20)
                    amountsValuePointer := add(amountsValuePointer, 0x20)
                }

                emitTransferBatch(caller(), from, 0, idsLen, idsStartPos, amountsLen, amountsStartPos)
             }

            /*------------------------------------------------------------------------------*/
            /*----------------------------    Storage layout    ----------------------------*/
            /*------------------------------------------------------------------------------*/
            
            function uriSlot() -> slot { slot := 0 }
            function balanceOfSlot() -> slot { slot := 1 }
            function isApprovedForAllSlot() -> slot { slot := 2 }

            //Nested mapping: (firstKey => (secondKey => value))
            //Nested value storage location: keccak256(secondKey.concat(keccak256(firstKey.concat(mappingStorageSlot))))
            function balanceOfStorageOffset(addr, tokenId) -> innerLoc {
                //Outer location: keccak256(address.concat(balanceOfSlot()))
                mstore(0x00, addr)
                mstore(0x20, balanceOfSlot())
                let outerLoc := keccak256(0x00, 0x40)

                //Inner location: keccak256(tokenId.concat(outerLoc))
                mstore(0x00, tokenId)
                mstore(0x20, outerLoc)
                innerLoc := keccak256(0x00, 0x40)
            }

            function isApprovedForAllStorageOffset(owner, operator) -> innerLoc {
                //Outer location: keccak256(owner.concat(isApprovedForAllSlot()))
                mstore(0x00, owner)
                mstore(0x20, isApprovedForAllSlot())
                let outerLoc := keccak256(0x00, 0x40)

                //Inner location: keccak256(operator.concat(outerLoc))
                mstore(0x00, operator)
                mstore(0x20, outerLoc)
                innerLoc := keccak256(0x00, 0x40)
            }

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
                    mstore(add(lenCoverage, 0x40), wordChunk)   //Copy to memory, add 0x40 for offset + length
                    dataOffset := add(dataOffset, 0x20)         //Move to next 32 bytes of uri value
                    lenCoverage := add(lenCoverage, 0x20)       //Advance length coverage by 32 bytes
                }

                //I'm assuming that the id should be appended somewhat. Based on the spec, it should look like this: 
                //https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json
                //---do something---

                return(0, add(0x40, lenCoverage))               //(eg: offset(0x20) + length(0x20) + uri value(0x20))
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

            function _getBalanceOf(addr, tokenId) -> bal {
                //Get location of addr's balance of tokenId in storage
                let offset := balanceOfStorageOffset(addr, tokenId)
                bal := sload(offset)
            }

            function _safeAddBalanceOf(toAddr, tokenId, amount) {
                //Get location of toAddr's balance of tokenId in storage
                let offset := balanceOfStorageOffset(toAddr, tokenId)
                //Update balance in storage
                let currBal := sload(offset)
                sstore(offset, safeAdd(currBal, amount))
            }

            function _safeSubBalanceOf(fromAddr, tokenId, amount) {
                //Get location of fromAddr's balance of tokenId in storage
                let offset := balanceOfStorageOffset(fromAddr, tokenId)
                //Update balance in storage
                let currBal := sload(offset)
                sstore(offset, safeSub(currBal, amount))
            }

            function _getIsApprovedForAll(owner, operator) -> all {
                //Get location of owner's approval for operator in storage
                let offset := isApprovedForAllStorageOffset(owner, operator)
                all := sload(offset)
            }

            function _setApprovalForAll(owner, operator, approved) { 
                //Get location of owner's approval for operator in storage
                let offset := isApprovedForAllStorageOffset(owner, operator)
                //Update approval in storage
                sstore(offset, approved)

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
                mstore(0x40, sload(dataOffset))                                 //uri value

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
                let numOfWordsForIds := add(0x20, mul(idsLength, 0x20))         //Words: id length word + (1 word per id)
                
                //calldatacopy(memOffsetCopyTo, calldataOffsetCopyFrom, numBytesToCopy)
                calldatacopy(0x40, idsLoc, numOfWordsForIds)                    //Copy words for ids to memory @ 0x40

                let valuesMemOffsetToCopyTo := add(0x40, numOfWordsForIds)      //Advance from 0x40 by numOfWordsForIds

                let numOfWordsForValues := add(0x20, mul(valuesLength, 0x20))   //Words: values length word + (1 word per value)

                calldatacopy(                                                   //Copy words for values to memory @ valuesMemOffsetToCopyTo    
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

            //For checking if an address has code
            function _hasCode(addr) -> res {
                res := gt(extcodesize(addr), 0)
            }

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