# README

## Polynance-Vault

Polynance-Vault is a **capital-efficient, yield-bearing back-end** for any kind of on-chain prediction strategy.
Three architectural facts drive the design:

| #     | Fact                                                                                                                                                          | Why it matters                                                                                                                              |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **1** | **All idle USDC is continuously supplied to Aave v3** and comes back only when a strategy locks it.                                                           | Earns risk-free yield instead of sitting cold. The vault simply holds `aUSDC` while accounting for the underlying USDC balance one-for-one. |
| **2** | **Strategies are permissionless.** Anyone can deploy a contract that implements `IStrategy` and start using the vault hooks; CoreVault never whitelists them. | Encourages experimentation: delta-neutral hedging bots, volatility harvesters, copy-trader funds, etc.                                      |
| **3** | **Any prediction market venue can be plugged in by writing a small `IAdaptor` implementation.**                                                               | The vault itself never “learns” a venue; the adaptor converts generic buy/sell intents into venue-specific calldata.                        |

---

## High-level flow

```
             +---------------------- CoreVault ----------------------+
             |                      (aUSDC)                          |
             | 1. Converts USDC→aUSDC on deposit                     |
User ↔ Vault | 2. Tracks idle vs locked balances (in USDC units)     |
(deposit)    | 3. Mints/Burns Position-NFTs                          |
             +-------------------▲---------------▲------------------+
                                 │               │IVaultStrategyHook
             Permissionless       │               │ lock / unlock / adjustExposure
           +----------------------┴----+    +-----┴-------------------+
           |        Strategy A (Degen) | …  | Strategy B (Market-Make)|  ∞ Strategies
           +-------------▲-------------+    +------------▲-----------+
                         │IAdaptor                 │IAdaptor
           +-------------┴----+              +-----┴--------------+
           | Polymarket CTF   |              | Augur v2           |  ∞ Adaptors
           +------------------+              +--------------------+
```

### Life cycle in practice

1. **Deposit** – User sends USDC → Vault converts to `aUSDC` and adds to `idleCollateral`.
2. **Open** – Strategy pulls a quote from its adaptor, calls `lockCollateral()`; Vault redeems `aUSDC`, mints an ERC-721 position token to the user, and transfers USDC to the strategy for execution.
3. **Active management** – Strategy can call `adjustExposure()` any time; Vault and Aave handle the cash-in/cash-out.
4. **Settle/Liquidate** – Strategy sends funds back, Vault burns the NFT and re-supplies any freed collateral to Aave.

---

## Contract surfaces

| Contract                               | Purpose                                                                                                          | Key API                                                                                       |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| **`CoreVault.sol`**                    | Single treasury & accounting layer. Holds only `aUSDC` unless a strategy actively needs raw USDC.                | `deposit()`, `withdraw()`, **Hooks**: `lockCollateral`, `unlockCollateral`, `adjustExposure`. |
| **`NonfungiblePredictionManager.sol`** | Pure ERC-721 mirror of vault state. Token-ID = `bytes32(posKey)` so front-ends can query without on-chain loops. | `tokenURI()` returns live JSON (state, collateral, size, price).                              |
| **`IStrategy.sol`**                    | Anything that wants to trade on the user’s behalf implements this. No ownership checks.                          | `openPosition`, `rebalance`, `settle`, `liquidate`, plus the hook interface.                  |
| **`IAdaptor.sol`**                     | Thin translation layer per venue. Encodes *how* to place an order but never touches USDC.                        | `priceE18`, `buildBuy`, `buildSell`, `execute`.                                               |

> **No governance approval path exists**: if your strategy compiles and speaks the interface, you’re good.

---

## Aave integration cheatsheet

```solidity
IERC20 USDC  = IERC20(0x...);
IPool  AAVE  = IPool(0x...);          // aUSDC pool

// Inside CoreVault
function _toAave(uint256 amount) internal {
    USDC.approve(address(AAVE), amount);
    AAVE.supply(address(USDC), amount, address(this), 0);
}

function _fromAave(uint256 amount) internal {
    AAVE.withdraw(address(USDC), amount, address(this));
}
```

The public accounting (`idleCollateral`, `totalLocked`) is denominated in **underlying USDC** so front-ends never need to understand aTokens.

---

## How to build on top

### Add a new prediction venue

```solidity
contract AzuroAdaptor is IAdaptor {
    function priceE18(address ex, address market, uint256 id)
        external view returns (uint256) { … }

    function buildBuy(address market, uint256 id, uint128 amt)
        external pure returns (bytes memory payload) { … }

    function buildSell(address market, uint256 id, uint128 amt)
        external pure returns (bytes memory payload) { … }

    function execute(bytes calldata payload)
        external returns (int256 usdcΔ, uint128 tokΔ) { … }
}
```

Deploy, package the address, and any strategy can start calling it immediately.

### Ship your own strategy

```solidity
contract MyMomentumBot is IStrategy, ReentrancyGuard {
    CoreVault immutable vault = CoreVault(0xVault);
    IERC20   immutable usdc  = IERC20(0xUSDC);
    IAdaptor immutable gyro  = IAdaptor(0xGyroscopeAdaptor);

    function openPosition( … ) external override {
        bytes32 key = keccak256(abi.encode(…));

        // ask vault to fund us
        vault.lockCollateral(key, 10_000e6);

        // build & execute venue-specific trade
        (int256 usdcΔ,) = vault.adjustExposure(
            key,
            address(gyro),
            gyro.buildBuy(market, outcome, 10_000e6)
        );

        require(usdcΔ == -10_000e6, "spend mismatch");
    }
}
```

No registration, no allow-listing, just **ship**.

---

## Local dev & tests

```bash
forge install openzeppelin/contracts aave/core-v3
forge build
forge test -vv
```

Environment variables you may want:

```bash
export MAINNET_RPC=https://mainnet.infura.io/v3/…
export FORK_BLOCK=19999999
```

---

## Security notes

* **Invariant** – `aUSDC.balanceOf(this).scaledBalanceOf(...) + rawUSDC == idle + locked`. Checked after every state-mutating call.
* **Re-entrancy** – All vault hooks are `nonReentrant`.
* **Adaptor isolation** – Adaptors handle *logic* only; they never receive approvals or hold tokens.

---

## License

MIT © 2025 Polynance contributors
