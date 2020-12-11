const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require('truffle-assertions');

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require( "./helpers/signerSeter");
const { setSigner } = require( "./helpers/signerSeter");

const qToken = artifacts.require("qToken");
const XTZ = artifacts.require("XTZ");

contract("qToken", async () => {
    const DEFAULT = accounts[0];
    const RECEIVER = accounts[1];
    const LIQUIDATOR = accounts[3];

    const lastUpdateTime = "2000-01-01T10:10:10.000Z";
    const totalBorrows = 1e+5;
    const totalLiquid = 1e+5;
    const totalSupply = 1e+5;
    const totalReserves = 1e+5;
    const borrowIndex = 1e+5;
    const accountBorrows = MichelsonMap.fromLiteral({
        [DEFAULT]: {
            amount:          1e+5,
            lastBorrowIndex: 1e+5,
        }
    });
    const accountTokens = MichelsonMap.fromLiteral({
            [DEFAULT]: 1e+5,
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
            totalBorrows:   totalBorrows,
            totalLiquid:    totalLiquid,
            totalSupply:    totalSupply,
            totalReserves:  totalReserves,
            borrowIndex:    borrowIndex,
            accountBorrows: accountBorrows,
            accountTokens:  accountTokens,
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
            assert.equal(totalBorrows, qTokenStorage.totalBorrows);
            assert.equal(totalLiquid, qTokenStorage.totalLiquid);
            assert.equal(totalSupply, qTokenStorage.totalSupply);
            assert.equal(totalReserves, qTokenStorage.totalReserves);
            assert.equal(borrowIndex, qTokenStorage.borrowIndex);
            let actual = await qTokenStorage.accountBorrows.get(DEFAULT);
            assert.equal(accountBorrows.get(DEFAULT).amount, actual.amount);
            assert.equal(accountBorrows.get(DEFAULT).lastBorrowIndex, actual.lastBorrowIndex);
            assert.equal(accountTokens.get(DEFAULT), await qTokenStorage.accountTokens.get(DEFAULT));
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
            const amount = 100;

            await qTokenInstance.mint(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();

            assert.equal(amount, await qTokenStorage.accountTokens.get(RECEIVER));
            assert.equal(totalLiquid + amount, qTokenStorage.totalLiquid);
            assert.equal(totalSupply + amount, qTokenStorage.totalSupply);
            assert.equal(amount,
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
    });

    describe("redeem", async () => {
        const amount = 100;
        const _totalLiquid = totalLiquid + amount;
        const _totalSupply = totalSupply + amount;
        beforeEach("setup, mint 100 tokens on receiver", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);
            await revertDefaultSigner();
            await qTokenInstance.mint(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();

            assert.equal(amount, await qTokenStorage.accountTokens.get(RECEIVER));
            assert.equal(_totalSupply, qTokenStorage.totalSupply);
            assert.equal(_totalLiquid, qTokenStorage.totalLiquid);
        });
        it("should redeem amount", async () => {
            const amountOfXTZbefore = (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance;
            await qTokenInstance.redeem(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();

            assert.equal(0, await qTokenStorage.accountTokens.get(RECEIVER));
            assert.equal(_totalSupply - amount, qTokenStorage.totalSupply);
            assert.equal(_totalLiquid - amount, qTokenStorage.totalLiquid);
            assert.equal(amountOfXTZbefore.toNumber() + amount,
                        (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance);
        });
        it("should redeem all users tokens, pass 0 as amount", async () => {
            const amountOfXTZbefore = (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance;
            const usersTokens = await (await qTokenInstance.storage()).accountTokens.get(RECEIVER);
            await qTokenInstance.redeem(RECEIVER, 0);
            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(0, await qTokenStorage.accountTokens.get(RECEIVER));
            assert.equal(_totalSupply - usersTokens, qTokenStorage.totalSupply);
            assert.equal(_totalLiquid - usersTokens, qTokenStorage.totalLiquid);
            assert.equal(amountOfXTZbefore.toNumber() + usersTokens.toNumber(),
                        (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance);
        });
        it("should redeem 50 tokens", async () => {
            const amountOfXTZbefore = (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance;
            const amountTo = 50;
            const usersTokens = await (await qTokenInstance.storage()).accountTokens.get(RECEIVER);
            await qTokenInstance.redeem(RECEIVER, amountTo);
            const qTokenStorage = await qTokenInstance.storage();

            assert.equal(usersTokens - amountTo, await qTokenStorage.accountTokens.get(RECEIVER));
            assert.equal(_totalSupply - amountTo, qTokenStorage.totalSupply);
            assert.equal(_totalLiquid - amountTo, qTokenStorage.totalLiquid);
            assert.equal(amountOfXTZbefore.toNumber() + amountTo,
                        (await (await XTZ_Instance.storage()).ledger.get(RECEIVER)).balance);
        });
        it("should get exception, exchange rate is zero", async () => {
            // make zero exchange rate
            let s = storage; s.totalSupply = 1e+18;
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
            const amount = 100;

            await qTokenInstance.borrow(RECEIVER, amount);
            const qTokenStorage = await qTokenInstance.storage();
            const _accountBorrows = await qTokenStorage.accountBorrows.get(RECEIVER);

            assert.equal(amount, _accountBorrows.amount);
            assert.equal(totalBorrows + amount, qTokenStorage.totalBorrows);
            assert.equal(amount,
                        (await (await XTZ_Instance.storage()).ledger.get(DEFAULT)).balance);
        });
        it("should get exception, total liquid less than amount", async () => {
            const amount = totalLiquid + 1;

            await truffleAssert.fails(qTokenInstance.borrow(RECEIVER, amount),
                truffleAssert.INVALID_OPCODE, "AmountTooBig");
        });
    });

    describe("repay", async () => {
        const amountToBorrow = 100;
        beforeEach("setup, add balance of xtz to DEFAULT and make borrow to user", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.transfer(RECEIVER, qTokenInstance.address, amountToBorrow);
            await revertDefaultSigner();
            await qTokenInstance.borrow(RECEIVER, amountToBorrow);
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);
        });
        it("should repay tokens", async () => {
            await qTokenInstance.repay(RECEIVER, amountToBorrow);
            const qTokenStorage = await qTokenInstance.storage();
            const _accountBorrows = await qTokenStorage.accountBorrows.get(RECEIVER);

            assert.equal(0, _accountBorrows.amount);
            //should be equal, coz we make borrow 100 and repay 100, so it's 0 now
            assert.equal(totalBorrows, qTokenStorage.totalBorrows);
            assert.equal(amountToBorrow,
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
    });

    describe("liquidate", async () => {
        const amountToBorrow = 100;
        beforeEach("setup, borrow 100 tokens on receiver and users", async () => {
            await setSigner(RECEIVER);
            await XTZ_Instance.transfer(RECEIVER, qTokenInstance.address, amountToBorrow * 2);
            await revertDefaultSigner();
            await qTokenInstance.borrow(RECEIVER, amountToBorrow);
            await qTokenInstance.borrow(LIQUIDATOR, amountToBorrow);
            await XTZ_Instance.approve(qTokenInstance.address, 1e+5);
        });
        it("should liquidate borrow", async () => {
            assert.equal(amountToBorrow, (await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount);
            await qTokenInstance.liquidate(LIQUIDATOR, RECEIVER, amountToBorrow);
            //coz liquidation incentive is 105%
            assert.equal(5, (await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount);
            assert.equal(amountToBorrow,
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
        it("should get exception, borrower is liquidator", async () => {
            await truffleAssert.fails(qTokenInstance.liquidate(LIQUIDATOR, LIQUIDATOR, amountToBorrow),
                truffleAssert.INVALID_OPCODE, "BorrowerCannotBeLiquidator");
        });
        it("should pass zero and expect same result in case pass amount to borrow", async () => {
            assert.equal(amountToBorrow, (await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount);
            await qTokenInstance.liquidate(LIQUIDATOR, RECEIVER, 0);
            //coz liquidation incentive is 105%
            assert.equal(5, (await (await qTokenInstance.storage()).accountBorrows.get(RECEIVER)).amount);
            assert.equal(amountToBorrow,
                        (await (await XTZ_Instance.storage()).ledger.get(qTokenInstance.address)).balance);
        });
    });
});