// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultUser,VaultEE} from "../interfaces/SuperInterface.sol";
import {VaultStorage}  from "../libs/VaultStorage.sol";

abstract contract VaultUserAPI is IVaultUser, ReentrancyGuard {
    using SafeERC20 for IERC20;

    function depositCollateral(uint256 amount) external override nonReentrant {
        VaultStorage.Layout storage v = VaultStorage.$$();
        v.collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        v.idleCollateral += uint128(amount);

        emit VaultEE.CollateralFlow(bytes32(0), VaultEE.Flow.IN_USER, amount);
    }

    function withdrawCollateral(uint256 amount) external override nonReentrant {
        VaultStorage.Layout storage v = VaultStorage.$$();
        if (v.idleCollateral < amount) revert VaultEE.CollateralShortfall(bytes32(0), amount, v.idleCollateral);

        v.idleCollateral -= uint128(amount);
        v.collateralToken.safeTransfer(msg.sender, amount);

        emit VaultEE.CollateralFlow(bytes32(0), VaultEE.Flow.OUT_USER, amount);
    }
}
