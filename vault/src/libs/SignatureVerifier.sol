
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title SignatureVerifier
 * @notice Abstract contract for signature verification
 */
abstract contract SignatureVerifier is EIP712 {
    using ECDSA for bytes32;

    // Nonce tracking for replay protection
    mapping(address => uint256) public nonces;

    // Trade typehash
    bytes32 private constant TRADE_TYPEHASH = keccak256("Trade(address user,address adaptor,bool buy,address exchange,address tokenAddress,uint256 tokenId,uint256 amount,uint256 nonce,bytes data)");

    constructor(string memory name, string memory version) EIP712(name, version) {}

    /**
     * @notice Verify a signature for a trade
     * @param user User address
     * @param adaptor Adaptor address
     * @param isBuy Whether this is a buy or sell
     * @param exchange Exchange address
     * @param tokenAddress Token address
     * @param tokenId Token ID
     * @param amount Amount of tokens
     * @param data Additional data
     * @param signature Signature bytes
     * @return Whether the signature is valid
     */
    function _verifySignature(
        address user,
        address adaptor,
        bool isBuy,
        address exchange,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        bytes memory data,
        bytes memory signature
    ) internal returns (bool) {
        bytes32 structHash = keccak256(abi.encode(
            TRADE_TYPEHASH,
            user,
            adaptor,
            isBuy,
            exchange,
            tokenAddress,
            tokenId,
            amount,
            nonces[user],
            keccak256(data)
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.recover(signature);

        if (signer == user) {
            nonces[user]++;
            return true;
        }
        return false;
    }
}
