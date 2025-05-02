// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/* ───── external deps ─────────────────────────────────────────────────── */
import { ERC721Enumerable }  from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import { ERC721URIStorage }  from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

/* ───── project-local deps ─────────────────────────────────────────────── */
import { PositionKeyLib } from "./libs/PositionKeyLib.sol";
import { VaultEE }  from "./interfaces/SuperInterface.sol";

/* ───── reader interface to CoreVault ──────────────────────────────────── */
interface ICoreVaultReader {
    struct PositionData {
        uint8   state;       // cast of enum PositionState
        uint64  opened;
        uint64  closed;
        uint128 collateral;
        uint128 size;
        uint128 entryPriceE18;
    }

    function isStrategyApproved(address strat) external view returns (bool);
    function positionData(bytes32 posKey)
        external
        view
        returns (PositionData memory);
}

/* ─────────────────────────────────────────────────────────────────────────
      Non-fungible Prediction Manager  (stateless)
      tokenId  == uint256(positionKey)
─────────────────────────────────────────────────────────────────────────*/
contract NonfungiblePredictionManager is ERC721Enumerable, ERC721URIStorage {
    using Strings for uint256;

    address public immutable coreVault; // CoreVault contract address
    ICoreVaultReader private immutable vaultReader;

    constructor(address _coreVault)
        ERC721("Prediction Position", "PPOS")
    {
        require(_coreVault != address(0), "NPM: zero vault");
        coreVault   = _coreVault;
        vaultReader = ICoreVaultReader(_coreVault);
    }

    /* ================================================================
                              MODIFIERS
    ================================================================ */
    modifier onlyVaultOrApprovedStrategy(address owner) {
        require(
            vaultReader.isStrategyApproved(msg.sender) &&
            isApprovedForAll(owner, msg.sender) && (msg.sender == coreVault),
            "onlyVaultOrApprovedStrategy Error"
        );
        _;
    }

    /* ================================================================
                Core mint / update / close  (vault / strategy)
    ================================================================ */

    /// Mint new NFT or update existing one.
    function mintOrUpdate(
        bytes32 posKey,
        address owner
    ) external onlyVaultOrApprovedStrategy(owner) {
        uint256 tokenId = uint256(posKey);
        if (ownerOf(tokenId)==address(0)) { 
            _safeMint(owner, tokenId);
        } else if (ownerOf(tokenId) != owner) {
            revert("NPM: owner mismatch");
        }
        emit VaultEE.PositionStateChange(posKey, VaultEE.PositionState.OPEN);
    }

    /// Close position & burn NFT.
    function close(bytes32 posKey)
        external
        onlyVaultOrApprovedStrategy(ownerOf(uint256(posKey)))
    {
        uint256 tokenId = uint256(posKey);
        _burn(tokenId);
        emit VaultEE.PositionStateChange(posKey,VaultEE.PositionState.CLOSED); // PositionState.CLOSED → 3
    }

    /* ================================================================
                           Metadata (optional)
    ================================================================ */
    function tokenURI(uint256 id)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        bytes32 posKey = bytes32(id);
        ICoreVaultReader.PositionData memory p = vaultReader.positionData(posKey);

        bytes memory json = abi.encodePacked(
            '{"name":"Prediction Position #', id.toString(),
            '","attributes":[',
              '{"trait_type":"Collateral","value":', uint256(p.collateral).toString(), '},',
              '{"trait_type":"Size","value":',       uint256(p.size).toString(), '},',
              '{"trait_type":"EntryPrice","value":', uint256(p.entryPriceE18).toString(), '}',
            ']}'
        );
        return string(
            abi.encodePacked("data:application/json;base64,", Base64.encode(json))
        );
    }

    /* ================================================================
                     ERC-721 boilerplate overrides
    ================================================================ */
    function _update(
        address to,
        uint256 id,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, id, auth);
    }

    function _increaseBalance(address acct, uint128 by)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(acct, by);
    }


    function supportsInterface(bytes4 iid)
        public
        view
        override(ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return
            iid == type(IERC721).interfaceId ||
            super.supportsInterface(iid);
    }
}
