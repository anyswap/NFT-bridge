// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

library NFTHelper {
    using Address for address;

    // wrap here as some impl have return type, some don't have
    function safeMint(
        address token,
        address to,
        uint256 tokenId
    ) internal {
        // mint(address,uint256)
        _callOptionalReturn(token, abi.encodeWithSelector(0x40c10f19, to, tokenId));
    }

    // wrap here as some impl will revert if tokenId is not exist
    function ownerOf(address token, uint256 tokenId) internal returns (address owner) {
        // ownerOf(uint256)
        (bool success, bytes memory returndata) = token.call(abi.encodeWithSelector(0x6352211e, tokenId));
        if (success && returndata.length > 0) {
            (owner) = abi.decode(returndata, (address));
        }
    }

    function _callOptionalReturn(address token, bytes memory data) private {
        bytes memory returndata = token.functionCall(data, "NFTHelper: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "NFTHelper: did not succeed");
        }
    }
}

interface IERC721Transfer {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

// NFTTokenWrapper: used when we have deployed nft token that does not support nft router.
// the target nft token should have public method `mint(address,uint256)`
// and this wrapper contract should have the `mint` privilege
contract NFTTokenWrapper is IERC721Transfer, AccessControlEnumerable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public immutable token; // the target nft token this contract is wrapping

    bool public allMintPaused; // pause all mint calling
    mapping(address => bool) public mintPaused; // pause specify minters' mint calling

    constructor(address _token, address _admin) {
        require(_token != address(0), "zero token address");
        require(_admin != address(0), "zero admin address");
        token = _token;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function owner() external view returns (address) {
        return getRoleMember(DEFAULT_ADMIN_ROLE, 0);
    }

    function setAllMintPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        allMintPaused = paused;
    }

    function setMintPaused(address minter, bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(MINTER_ROLE, minter), "not minter");
        mintPaused[minter] = paused;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external onlyRole(MINTER_ROLE) {
        require(tokenId > 0, "Token ID invalid");
        bool exist = NFTHelper.ownerOf(token, tokenId) != address(0);
        if (!exist) {
            NFTHelper.safeMint(token, to, tokenId);
        } else {
            IERC721Transfer(token).safeTransferFrom(from, to, tokenId);
        }
    }
}
