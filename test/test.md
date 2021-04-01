# Test scenario

### List of contracts

1. Factory
2. Controller
3. qToken

## 1. Factory

**Atomic requirements:**

1. Deploys new protocol token (qToken) if the new token is enabled as the collateral.
2. Only admin can enable the support of the token.
3. The asset support can only be added once.
4. Should notify the Controller contract about new supported token.

**Custom contract entrypoints:**

1. LaunchToken
2. SetFactoryAdmin
3. SetNewOwner
4. SetTokenFunction
5. SetUseFunction

**Test cases to cover requirements:**

1. Should deploy new asset by admin.
2. Shouldn't deploy the asset if called by non-admin.
3. Should add the new asset.
4. Shouldn't add the asset in the second time.

**For each success case check:**

1. The new addresses are added to `tokenList`.
2. The initial `qToken` storage is correct.
3. The `Controller` storage is updated correctly.

**For each fail case check:**

1. The transactions is reverted.
2. The revert message is correct.

**Test cases to cover entrypoints calls:**

1. Should update the controller address if called by the owner.
2. Shouldn't update the controller address if called by non-admin.
3. Should update the owner address if called by the owner.
4. Shouldn't update the owner address if called by non-admin.
5. Should set the token function if called by the owner.
6. Shouldn't set the token function if called by non-admin.
7. Should set the qToken function if called by the owner.
8. Shouldn't set the qToken function if called by non-admin.
9. Should add up to 5 token functions.
10. Shouldn't accept more than 5 token functions.
11. Shouldn't allow to replace the token functions.
12. Should add up to 9 qToken functions.
13. Shouldn't accept more than 9 qToken functions.
14. Shouldn't allow to replace the qToken functions.


## 2. Controller

**Atomic requirements:**

1. Calls qToken functions
2. Should call qToken functions
3. Should update data in qToken

**Custom contract entrypoints:**

1. UpdatePrice
2. SetOracle
3. Register
4. UpdateQToken
5. ExitMarket
6. SafeMint
7. SafeRedeem
8. EnsuredRedeem
9. SafeBorrow
10. EnsuredBorrow
11. SafeRepay
12. SafeLiquidate
13. EnsuredLiquidate

**Test cases to cover requirements:**

**For each success case check:**

1. qToken storage
2. Operation result
3. Controller storage
4. Occasionally wXTZ storage

**For each fail case check:**

1. The transactions is reverted.
2. The revert message is correct.
3. Storages has not been updated

### Main Controller entrypoints

#### SetOracle

**Test cases to cover entrypoint call:**

1. Should update the oracle address if called by the admin.
2. Shouldn't update the oracle address if called by non-admin.

#### SafeMint

**Test cases to cover entrypoint call:**

1. Should contains in qToken in qTokens list
2. Shouldn't call if qToken not in qTokens list
3. Should be approved by user to contract and balance should be same or more
3. qToken contract storage should be upd after valid transaction
4. Main tokens (for ex wXTZ) should be transfered to contract after qToken.mint was called

#### SafeBorrow

**Test cases to cover entrypoint call:**

1. Should contains in qToken in qTokens list
2. Shouldn't call if qToken not in qTokens list
3. Ensure shortfail = 0
4. Shouldn`t call if collateralToken already entered to market
5. Collateral token must be minted
6. Shouldn't call if collateral token dont minted

#### SafeRedeem

**Test cases to cover entrypoint call:**

1. Should contains in qToken in qTokens list
2. Shouldn't call if qToken not in qTokens list
3. Check way if user enter the market. Should return list of operations: qToken.updateControllerState(user)  (qToken is the contract the user set as the collateral) + self.redeemMiddle
4. Check way if user did not enter the market. Should call qToken.redeem
5. Should calculate the redeemed amount.
6. Should transfer the amount of underlying tokens


#### SafeRepay

**Test cases to cover entrypoint call:**

1. Should contains in qToken in qTokens list
2. Shouldn't call if qToken not in qTokens list
3. Should call if user have borrow.
4. Shouldn't call if user doesnt have borrow.
5. Should call if user have tokens.
6. Shouldn't call if user doesnt have tokens.
7. Amount of collateral should be withdrawn (transferred) from the sender


#### ExitMarket

**Test cases to cover entrypoint call:**

1. Should delete date in controller.storage.accountMembership if entered in market and borrow not exist
2. Should`nt delete date in controller.storage.accountMembership if dont entered in market and borrow exist


#### SafeLiquidate

**Test cases to cover entrypoint call:**

1. Should contains in qToken in qTokens list
2. Shouldn't call if qToken not in qTokens list
3. Should send qToken.liquidate if ensure shortfail =/= 0
4. Shouldn't send qToken.liquidate if ensure shortfail =/= 0
5. Should failed if liquidator dont have borrower token.
6. Shouldn't failed if liquidator have borrower token.
7. Shouldn't failed if borrower havent borrow

## 3. qToken

**Atomic requirements:**

1. Wraps the token and adds its address to storage.tokenAddress
2. Must have an admin in the form of a controller contract
3. Must have all the functions of a FA1.2 token

**Custom contract entrypoints:**

1. Mint
2. Redeem
3. Borrow
4. Repay
5. Liquidate
6. Seize
7. UpdateControllerState
8. FA1.2 standart methods

**Test cases to cover requirements:**

**For each success case check:**

1. qToken storage
2. Operation result
3. Should be approved by user to contract and balance should be same or more
4. Occasionally wXTZ storage

**For each fail case check:**

1. The transactions is reverted.
2. The revert message is correct.
3. Storages has not been updated

### Main qToken entrypoints

#### Mint

**Test cases to cover entrypoint call:**

1. Should executed only by authorized admin (Controller contract)
2. The amount of underlying tokens should be withdrawn(transferred from user)

#### Borrow

**Test cases to cover entrypoint call:**

1. Should executed only by authorized admin (Controller contract)
2. Should fail if available totalLiquid is lower than borrowed amount
3. Should`nt fail if available totalLiquid is same or more than borrowed amount
3. Amount of collateral should be transfered to the sender

#### Redeem

**Test cases to cover entrypoint call:**

1. Should executed only by authorized admin (Controller contract)
2. Should calculate the redeemed amount.
3. Should transfer the amount of underlying tokens

#### Repay

**Test cases to cover entrypoint call:**

1. Should executed only by authorized admin (Controller contract)
2. Amount of collateral should be withdrawn (transferred) from the sender

#### Liquidate

**Test cases to cover entrypoint call:**

1. Should executed only by authorized admin (Controller contract)
2. Borrower cannot be liquidator
3. Amount should be withdrawn(transferred) from sender address
4. Liquidator should have tokens borrower
5. Seize should be called to pay the collateral to the liquidator

#### Seize

**Test cases to cover entrypoint call:**

1. Should executed only by authorized admin (Controller contract)
2. Should check calculations
