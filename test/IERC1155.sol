// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IERC1155 {
    //--------------------------------Required by spec--------------------------------
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values
    );
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

    function uri(uint256 id) external view returns (string memory);
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    )
        external;

    function balanceOfBatch(
        address[] calldata owners,
        uint256[] calldata ids
    )
        external
        view
        returns (uint256[] memory);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function balanceOf(address owner, uint256 id) external view returns (uint256);
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    //--------------------------------Additional--------------------------------
    function setURI(string calldata newuri) external;
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external;
    function batchMint(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function batchBurn(address from, uint256[] calldata ids, uint256[] calldata amounts) external;
}
