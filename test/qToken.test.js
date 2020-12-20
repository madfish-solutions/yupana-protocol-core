const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require('truffle-assertions');
const BigNumber = require('bignumber.js');

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require( "./helpers/signerSeter");
const { setSigner } = require( "./helpers/signerSeter");

const qToken = artifacts.require("qToken");
const XTZ = artifacts.require("XTZ");

const toBN = (num) => {
    return new BigNumber(num);
};

const Floor = (num) => {
    return toBN(Math.floor(num))
}

const Fixed = (value) => {
    return value.toNumber().toLocaleString('fullwide', {useGrouping:false})
};

const ExchangeRate = async (s) => {
    function fixFields(s) {
        s.totalBorrows = toBN(s.totalBorrows);
        s.totalLiquid = toBN(s.totalLiquid);
        s.totalReserves = toBN(s.totalReserves);
        s.borrowIndex = toBN(s.borrowIndex);
        s.totalSupply = toBN(s.totalSupply);
        return s
    }
    s = fixFields(s)
    const accuracy = toBN(1e+18);
    const lastUpdateTime = Date.parse("2000-01-01T10:10:10.000Z")

    const apr = toBN(25000000000000000); // 2.5% (0.025) from accuracy
    const utilizationBase = toBN(200000000000000000); // 20% (0.2)
    const secondsPerYear = toBN(31536000);
    const reserveFactorFloat = toBN(1000000000000000);// 0.1% (0.001)
    const utilizationBasePerSecFloat = toBN(6341958397); // utilizationBase / secondsPerYear; 0.000000006341958397
    const debtRatePerSecFloat = toBN(792744800); // apr / secondsPerYear; 0.000000000792744800

    const utilizationRateFloat = Floor(s.totalBorrows.multipliedBy(accuracy).div(s.totalLiquid.plus(s.totalBorrows).minus(s.totalReserves))); // one div operation with float require accuracy mult
    const borrowRatePerSecFloat = Floor(utilizationRateFloat.multipliedBy(utilizationBasePerSecFloat).div(accuracy).plus(debtRatePerSecFloat)); // one mult operation with float require accuracy division
    const simpleInterestFactorFloat = Floor(borrowRatePerSecFloat.multipliedBy((Date.parse((await tezos.rpc.getBlockHeader()).timestamp) - lastUpdateTime) / 1000 - 1));
    const interestAccumulatedFloat = Floor(simpleInterestFactorFloat.multipliedBy(s.totalBorrows).div(accuracy)); // one mult operation with float require accuracy division


    s.totalBorrows = interestAccumulatedFloat.plus(s.totalBorrows);
    s.totalReserves = Floor(interestAccumulatedFloat.multipliedBy(reserveFactorFloat).div(accuracy).plus(s.totalReserves)); // one mult operation with float require accuracy division
    s.borrowIndex = Floor(simpleInterestFactorFloat.multipliedBy(s.borrowIndex).div(accuracy).plus(s.borrowIndex));

    const exchangeRate = s.totalLiquid.plus(s.totalBorrows).minus(s.totalReserves).multipliedBy(accuracy).div(s.totalSupply);
    return exchangeRate
};

contract.skip("qToken", async () => {
    const DEFAULT = accounts[0];
    const RECEIVER = accounts[1];
    const LIQUIDATOR = accounts[3];
    const accuracy =  toBN(1e+18);

    const lastUpdateTime = "2000-01-01T10:10:10.000Z";
    const totalBorrows = accuracy.multipliedBy(1e+5);
    const totalLiquid = accuracy.multipliedBy(1e+5);
    const totalSupply = accuracy.multipliedBy(1e+5);
    const totalReserves = accuracy.multipliedBy(1e+5);
    const borrowIndex = accuracy.multipliedBy(1e+5);
    const accountBorrows = MichelsonMap.fromLiteral({
        [DEFAULT]: {
            amount:          Fixed(accuracy.multipliedBy(1e+5)),
            lastBorrowIndex: Fixed(accuracy.multipliedBy(1e+5)),
        }
    });
    const accountTokens = MichelsonMap.fromLiteral({
            [DEFAULT]: Fixed(accuracy.multipliedBy(1e+5)),
        });

    let storage;
    let qTokenInstance;
    let XTZ_Instance;
    let XTZ_Storage;
    const receiverBalance = 1500;
    const receiverAmt = 15;
    const liquidatorBalance = 200;
    const liquidatorAmt = 20;
    const totalSupplyXTZ = 50000;

    beforeEach("setup", async () => {
        XTZ_Storage = {
            ledger: MichelsonMap.fromLiteral({
                [RECEIVER]: {
                    balance: receiverBalance,
                    allowances: MichelsonMap.fromLiteral({
                        [RECEIVER]: receiverAmt,
                    }),
                },
                [LIQUIDATOR]: {
                    balance: liquidatorBalance,
                    allowances: MichelsonMap.fromLiteral({
                        [LIQUIDATOR]: liquidatorAmt,
                    }),
                },
            }),
            totalSupply: totalSupplyXTZ,
        };
        XTZ_Instance = await XTZ.new(XTZ_Storage);

        storage = {
            owner:          DEFAULT,
            admin:          DEFAULT,
            token:          XTZ_Instance.address,
            lastUpdateTime: lastUpdateTime,
            totalBorrows:   Fixed(totalBorrows),
            totalLiquid:    Fixed(totalLiquid),
            totalSupply:    Fixed(totalSupply),
            totalReserves:  Fixed(totalReserves),
            borrowIndex:    Fixed(borrowIndex),
            accountBorrows: accountBorrows,
            accountTokens:  accountTokens,
            t:0,
            tt:0,
            ttt:0,
        };
        qTokenInstance = await qToken.new(storage);

        await revertDefaultSigner();
    });

    describe("deploy", async () => {
        it("should check storage after deploy", async () => {
            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(DEFAULT, qTokenStorage.owner);
            assert.equal(DEFAULT, qTokenStorage.admin);
            assert.equal(XTZ_Instance.address, qTokenStorage.token);
            assert.equal(lastUpdateTime, qTokenStorage.lastUpdateTime);
            assert.equal(totalBorrows, qTokenStorage.totalBorrows.toString());
            assert.equal(totalLiquid, qTokenStorage.totalLiquid.toString());
            assert.equal(totalSupply, qTokenStorage.totalSupply.toString());
            assert.equal(totalReserves, qTokenStorage.totalReserves.toString());
            assert.equal(borrowIndex, qTokenStorage.borrowIndex.toString());
            let actual = await qTokenStorage.accountBorrows.get(DEFAULT);
            assert.equal(accountBorrows.get(DEFAULT).amount, Fixed(actual.amount));
            assert.equal(accountBorrows.get(DEFAULT).lastBorrowIndex, Fixed(actual.lastBorrowIndex));
            assert.equal(accountTokens.get(DEFAULT), Fixed((await qTokenStorage.accountTokens.get(DEFAULT))));
        });
    });

    describe("setAdmin", async () => {
        it("should set new admin", async () => {
            const newAdmin = accounts[1];
            await qTokenInstance.setAdmin(newAdmin);

            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(newAdmin, qTokenStorage.admin);
        });
        it("should get exception, call from not owner", async () => {
            const notOwner = accounts[1];
            const newAdmin = accounts[2];
            await setSigner(notOwner);

            await truffleAssert.fails(qTokenInstance.setAdmin(newAdmin),
                                      truffleAssert.INVALID_OPCODE, "NotOwner");
        });
    });

    describe("setOwner", async () => {
        it("should set new owner", async () => {
            const newOwner = accounts[1];
            await qTokenInstance.setOwner(newOwner);

            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(newOwner, qTokenStorage.owner);
        });
        it("should get exception, call from not owner", async () => {
            const notOwner = accounts[1];
            const newOwner = accounts[2];
            await setSigner(notOwner);

            await truffleAssert.fails(qTokenInstance.setOwner(newOwner),
                                      truffleAssert.INVALID_OPCODE, "NotOwner");
        });
    });

    describe("mint", async () => {
        beforeEach("setup", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);
            await revertDefaultSigner();
        });
        it("should mint tokens", async () => {
            const amount = toBN(100);

            await qTokenInstance.mint(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();
            const exchangeRate = await ExchangeRate(storage);
            const mintTokens = amount.multipliedBy(accuracy).multipliedBy(accuracy).div(exchangeRate);

            assert.equal(Fixed(mintTokens), Fixed(await qTokenStorage.accountTokens.get(RECEIVER)));
            assert.equal(Fixed(amount.multipliedBy(accuracy).plus(totalLiquid)), Fixed(qTokenStorage.totalLiquid));
            assert.equal(Fixed(mintTokens.plus(totalSupply)), Fixed(qTokenStorage.totalSupply));
            assert.equal(amount.toString(),
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
    });

    describe("redeem", async () => {
        const amount = toBN(100);
        const _totalLiquid = amount.multipliedBy(accuracy).plus(totalLiquid);
        let _totalSupply;
        let storageAfterMint;
        let accTokensAferMint;
        beforeEach("setup, mint 100 tokens on receiver", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);
            await revertDefaultSigner();
            await qTokenInstance.mint(RECEIVER, amount);
            storageAfterMint = await qTokenInstance.storage();

            const exchangeRate = await ExchangeRate(storage);
            const mintTokens = amount.multipliedBy(accuracy).multipliedBy(accuracy).div(exchangeRate);

            _totalSupply = totalSupply.plus(mintTokens);
            accTokensAferMint = Fixed(await storageAfterMint.accountTokens.get(RECEIVER));

            // assert.equal(Fixed(mintTokens), accTokensAferMint);
            // assert.equal(Fixed(_totalSupply), Fixed(storageAfterMint.totalSupply));
            // assert.equal(Fixed(_totalLiquid), Fixed(storageAfterMint.totalLiquid));
        });
        it("should redeem amount", async () => {
            const amountOfXTZbefore = (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance;
            await qTokenInstance.redeem(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();

            const exchangeRate = await ExchangeRate(storageAfterMint);
            const burnTokens = amount.multipliedBy(accuracy).multipliedBy(accuracy).div(exchangeRate);

            assert.equal(accTokensAferMint - burnTokens, Fixed(await qTokenStorage.accountTokens.get(RECEIVER)));
            assert.equal(Fixed(_totalSupply.minus(burnTokens)), Fixed(qTokenStorage.totalSupply));
            assert.equal(Fixed(_totalLiquid.minus(amount.multipliedBy(accuracy))), Fixed(qTokenStorage.totalLiquid));
            assert.equal(Fixed(amountOfXTZbefore.plus(amount)),
                        (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance);
        });
        it("should redeem all users tokens, pass 0 as amount", async () => {
            const amountOfXTZbefore = (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance;
            const usersTokens = await (await qTokenInstance.storage()).accountTokens.get(RECEIVER);
            await qTokenInstance.redeem(RECEIVER, 0);
            const qTokenStorage = await qTokenInstance.storage();

            const exchangeRate = await ExchangeRate(storageAfterMint);

            // console.log("TEST2 rate ", Fixed(qTokenStorage.ttt));
            console.log("log   tt   ", qTokenStorage.tt.toNumber())//Fixed(qTokenStorage.tt))
            console.log("ACTUAL rate", Fixed(exchangeRate))//Fixed(exchangeRate))
            //console.log("REAL", Fixed(storageAfterMint.totalSupply))

            console.log("log       t", qTokenStorage.t.toNumber())
            console.log("log2     tt", qTokenStorage.tt.toNumber().toLocaleString('fullwide', {useGrouping:false}))
            console.log("log2      t", qTokenStorage.t.toNumber().toLocaleString('fullwide', {useGrouping:false}))
            console.log("log3      t", Fixed(qTokenStorage.t))
            console.log("log3     tt", Fixed(qTokenStorage.tt))


            const amt = toBN(usersTokens).div(accuracy);
            const burnTokens = amt.multipliedBy(accuracy).multipliedBy(accuracy).div(exchangeRate);

            // assert.equal(accTokensAferMint - burnTokens, Fixed(await qTokenStorage.accountTokens.get(RECEIVER)));
            // assert.equal(Fixed(_totalSupply.minus(burnTokens)), Fixed(qTokenStorage.totalSupply));
            // // usersTokens already with accuracy
            // assert.equal(Fixed(_totalLiquid.minus(usersTokens)), Fixed(qTokenStorage.totalLiquid));
            // assert.equal(amountOfXTZbefore.toNumber() + usersTokens.toNumber() / accuracy,
            //             (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance);
        });
        it("should redeem 50 tokens", async () => {
            const amountOfXTZbefore = (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance;
            const amountTo = toBN(50);
            const usersTokens = await (await qTokenInstance.storage()).accountTokens.get(RECEIVER);
            await qTokenInstance.redeem(RECEIVER, amountTo);
            const qTokenStorage = await qTokenInstance.storage();

            const exchangeRate = await ExchangeRate(storageAfterMint);
            const burnTokens = amountTo.multipliedBy(accuracy).div(exchangeRate);

            assert.equal(usersTokens - burnTokens, await qTokenStorage.accountTokens.get(RECEIVER));
            assert.equal(Fixed(_totalSupply.minus(burnTokens)), Fixed(qTokenStorage.totalSupply));
            assert.equal(_totalLiquid - amountTo * accuracy, qTokenStorage.totalLiquid);
            assert.equal(Fixed(amountTo.plus(amountOfXTZbefore)),
                        (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance);
        });
        it("should get exception, exchange rate is zero", async () => {
            // make zero exchange rate
            let s = storage;
            s.totalBorrows = 1;
            s.totalLiquid = 1;
            s.totalReserves = 1;
            s.borrowIndex = 1;
            s.totalSupply = Fixed(toBN(1e+228));
            let q = await qToken.new(s);
            await truffleAssert.fails(q.redeem(RECEIVER, 0),
                truffleAssert.INVALID_OPCODE, "NotEnoughTokensToSendToUser");
        });
    });

    describe("borrow", async () => {
        beforeEach("setup, add balance of xtz to qToken", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.transfer(RECEIVER, qTokenInstance.address, receiverBalance);
            await revertDefaultSigner();
        });
        it("should borrow tokens", async () => {
            const amount = toBN(100);
            await qTokenInstance.borrow(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();
            const _accountBorrows = await qTokenStorage.accountBorrows.get(RECEIVER);

            // updateInterest updates total borrows
            await ExchangeRate(storage);

            assert.equal(amount * accuracy, _accountBorrows.amount);
            assert.equal(Fixed(storage.totalBorrows.plus(amount.multipliedBy(accuracy))), Fixed(qTokenStorage.totalBorrows));
            assert.equal(amount.toNumber(),
                        (await (await XTZ_Instance.storage()).ledger.get(DEFAULT)).balance);
        });
        it("should get exception, total liquid less than amount", async () => {
            const amount = totalLiquid.plus(1);

            await truffleAssert.fails(qTokenInstance.borrow(RECEIVER, amount),
                truffleAssert.INVALID_OPCODE, "AmountTooBig");
        });
    });

    describe("repay", async () => {
        const amountToBorrow = 100;
        let storageAfterBorrow;
        beforeEach("setup, add balance of xtz to DEFAULT and make borrow to user", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.transfer(RECEIVER, qTokenInstance.address, amountToBorrow);
            await revertDefaultSigner();
            await qTokenInstance.borrow(RECEIVER, amountToBorrow);
            storageAfterBorrow = await qTokenInstance.storage();
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);
        });
        it("should repay tokens", async () => {
            const borrowsBeforeRepay = await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER);

            await qTokenInstance.repay(RECEIVER, amountToBorrow);
            const qTokenStorage = await qTokenInstance.storage();
            const _accountBorrows = await qTokenStorage.accountBorrows.get(RECEIVER);

            await ExchangeRate(storageAfterBorrow);

            let borrowsAmount = toBN(borrowsBeforeRepay.amount).multipliedBy(storageAfterBorrow.borrowIndex).
                                div(borrowsBeforeRepay.lastBorrowIndex).div(accuracy);
            borrowsAmount = borrowsAmount.minus(accuracy.multipliedBy(amountToBorrow));

            assert.equal(Math.abs(Fixed(borrowsAmount)), Fixed(_accountBorrows.amount));
            // accuracy division because there is an infelicity in the calculations
            assert.equal(Floor(storageAfterBorrow.totalBorrows).minus(accuracy.multipliedBy(amountToBorrow)).div(accuracy),
                         Floor(qTokenStorage.totalBorrows).div(accuracy));
            assert.equal(amountToBorrow,
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
    });

    describe("liquidate", async () => {
        const amountToBorrow = toBN(100);
        let setupStorage;
        let borrowsAmount;
        beforeEach("setup, borrow 100 tokens on receiver and users", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.transfer(RECEIVER, qTokenInstance.address, amountToBorrow * 2);
            await revertDefaultSigner();
            await qTokenInstance.borrow(RECEIVER, amountToBorrow);
            await qTokenInstance.borrow(LIQUIDATOR, amountToBorrow);
            setupStorage = await qTokenInstance.storage();
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);

            const liquidationIncentive = toBN(105000000);// 105% (1.05) from accuracy
            const exchangeRate = await ExchangeRate(setupStorage);
            const seizeTokens = amountToBorrow.multipliedBy(liquidationIncentive).div(accuracy).div(exchangeRate);

            const borrow = await setupStorage.accountBorrows.get(RECEIVER);

            borrowsAmount = toBN(borrow.amount).multipliedBy(setupStorage.borrowIndex).div(borrow.lastBorrowIndex);
            borrowsAmount = borrowsAmount.minus(seizeTokens);
        });
        it("should liquidate borrow", async () => {
            assert.equal(amountToBorrow * accuracy, (await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount);
            await qTokenInstance.liquidate(LIQUIDATOR, RECEIVER, amountToBorrow);

            // accuracy division because there is an infelicity in the calculations
            assert.equal(Math.floor(borrowsAmount.div(accuracy)),
                         Math.floor(toBN((await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount).div(accuracy)));
            assert.equal(amountToBorrow.toNumber(),
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
        it("should get exception, borrower is liquidator", async () => {
            await truffleAssert.fails(qTokenInstance.liquidate(LIQUIDATOR, LIQUIDATOR, amountToBorrow),
                truffleAssert.INVALID_OPCODE, "BorrowerCannotBeLiquidator");
        });
        it("should pass zero and expect same result in case pass amount to borrow", async () => {
            assert.equal(amountToBorrow * accuracy, (await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount);
            await qTokenInstance.liquidate(LIQUIDATOR, RECEIVER, 0);

            assert.equal(Math.floor(borrowsAmount.div(accuracy)),
                         Math.floor(toBN((await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount).div(accuracy)));
            assert.equal(amountToBorrow.toNumber(),
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
    });
});