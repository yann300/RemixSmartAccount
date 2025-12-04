// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./core/Helpers.sol";
import "./core/BaseAccount.sol";

import "hardhat/console.sol";

/**
 * RemixSmartAccount.sol
 */
contract RemixSmartAccount is BaseAccount, IERC165, IERC1271, ERC1155Holder, ERC721Holder {

    // USDC Token Address (Mainnet: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Maximum allowed USDC balance ($10 in USDC, assuming 6 decimals)
    uint256 public constant MAX_USDC_BALANCE = 10 * 1e6;

    // Maximum allowed ERC1155 token balance (10 tokens)
    uint256 public constant MAX_ERC1155_BALANCE = 10;

    // address of entryPoint v0.8
    function entryPoint() public pure override returns (IEntryPoint) {
        return IEntryPoint(0x4337084D9E255Ff0702461CF8895CE9E3b5Ff108);
    }

    /**
     * Make this account callable through ERC-4337 EntryPoint.
     * The UserOperation should be signed by this account's private key.
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual override returns (uint256 validationData) {

        return _checkSignature(userOpHash, userOp.signature) ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) public view override returns (bytes4 magicValue) {
        return _checkSignature(hash, signature) ? this.isValidSignature.selector : bytes4(0xffffffff);
    }

    function _checkSignature(bytes32 hash, bytes memory signature) internal view returns (bool) {
        return ECDSA.recover(hash, signature) == address(this);
    }

    function _requireForExecute() internal view virtual override {
        require(
            msg.sender == address(this) ||
            msg.sender == address(entryPoint()),
            "not from self or EntryPoint"
        );
    }

    function supportsInterface(bytes4 id) public override(ERC1155Holder, IERC165) pure returns (bool) {
        return
            id == type(IERC165).interfaceId ||
            id == type(IAccount).interfaceId ||
            id == type(IERC1271).interfaceId ||
            id == type(IERC1155Receiver).interfaceId ||
            id == type(IERC721Receiver).interfaceId;
    }

    // Function to check and enforce USDC balance limit
    function _checkTokenBalance(address token, uint id, uint value) internal view {
        uint balance = IERC1155(token).balanceOf(address(this), id);
        console.log("balance", balance);
        console.log(value, MAX_ERC1155_BALANCE);
        require(
            balance <= MAX_ERC1155_BALANCE,
            "ERC1155 balance would exceed 10 tokens limit"
        );
    }

    /**
     * ERC1155 single token transfer hook
     * Only accepts the transfer if the balance after transfer is less than 10 tokens
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override returns (bytes4) {
        _checkTokenBalance(msg.sender, id, value);
        return this.onERC1155Received.selector;
    }

    /**
     * ERC1155 batch token transfer hook
     * Only accepts the transfer if the total balance after transfer is less than 10 tokens
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override returns (bytes4) {
        // Calculate total tokens being transferred
        uint256 totalValue = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            _checkTokenBalance(msg.sender, id, values[i]);
        }
        
        return this.onERC1155BatchReceived.selector;
    }

    // accept incoming calls (with or without value), to mimic an EOA.
    fallback() external payable {
        require(msg.value == 0, "Ether not accepted");
    }

    receive() external payable {
        revert("Ether not accepted");
    }
}
