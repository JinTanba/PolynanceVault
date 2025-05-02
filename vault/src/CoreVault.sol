// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VaultUserAPI} from "./mixins/VaultUserAPI.sol";
import {VaultStrategyHooks} from "./mixins/VaultStrategyHooks.sol";
import {VaultStorage} from "./libs/VaultStorage.sol";
import {NonfungiblePredictionManager} from "./NonfungiblePredictionManager.sol";


contract CoreVault is VaultUserAPI, VaultStrategyHooks {
    
    constructor(address usdc) {
        VaultStorage.Layout storage $ = VaultStorage.$$();
        $.collateralToken = IERC20(usdc);
        $.npm = new NonfungiblePredictionManager(address(this));
        $.oparators[msg.sender] = true;
    }

    function positionData(bytes32 posKey) external view returns(VaultStorage.PositionData memory){
        return VaultStorage.$$().pos[posKey];
    }

    function setStrategy(address strg, bool onoff) external {
        require(VaultStorage.$$().oparators[msg.sender], "Auth: Permisson error");
        VaultStorage.$$().approvedStrategy[strg] = onoff;
    }

    function collateralOf(bytes32 key) external view returns (uint256) {
        return VaultStorage.$$().pos[key].collateral;
    }

    function isApprovedStrategy(address strat, address user) external view returns (bool) {
        return VaultStorage.$$().npm.isApprovedForAll(user, strat);
    }

    function isStrategyApproved(address strg) external view returns(bool) {
        return VaultStorage.$$().approvedStrategy[strg];
    }

    function invariant_balance() external view returns (bool ok) {
        VaultStorage.Layout storage v = VaultStorage.$$();
        ok = v.collateralToken.balanceOf(address(this)) == uint256(v.idleCollateral) + uint256(v.totalLocked);
        //If this is no OK. this is worst thing
    }



}
