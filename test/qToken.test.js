const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require('truffle-assertions');

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require( "./helpers/signerSeter");
const { setSigner } = require( "./helpers/signerSeter");

const qToken = artifacts.require("qToken");

contract("qToken", async () => {
    const DEFAULT = accounts[0];

    const lastUpdateTime = "2000-01-01T10:10:10.000Z";
    const totalBorrows = 1e+5;
    const totalLiquid = 1e+5;
    const totalSupply = 1e+5;
    const totalReserves = 1e+5;
    const borrowIndex = 1e+5;
    const accountBorrows = MichelsonMap.fromLiteral({
        [DEFAULT]: 1e+5,
    });
    const accountTokens = MichelsonMap.fromLiteral({
            [DEFAULT]: 1e+5,
        });

    let storage;
    let qTokenInstance;

    beforeEach("setup", async () => {
        storage = {
            owner:          DEFAULT,
            admin:          DEFAULT,
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
            assert.equal(lastUpdateTime, qTokenStorage.lastUpdateTime);
            assert.equal(totalBorrows, qTokenStorage.totalBorrows);
            assert.equal(totalLiquid, qTokenStorage.totalLiquid);
            assert.equal(totalSupply, qTokenStorage.totalSupply);
            assert.equal(totalReserves, qTokenStorage.totalReserves);
            assert.equal(borrowIndex, qTokenStorage.borrowIndex);
            assert.equal(1e+5, await qTokenStorage.accountBorrows.get(DEFAULT));
            assert.equal(1e+5, await qTokenStorage.accountTokens.get(DEFAULT));
        });
    });

    describe("setAdmin", async () => {
        it("should set new admin", async () => {
            const newAdmin = accounts[1];
            await qTokenInstance.setAdmin(newAdmin, {s: null});

            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(newAdmin, qTokenStorage.admin);
        });
        it("should get exception, call from not owner", async () => {
            const notOwner = accounts[1];
            const newAdmin = accounts[2];
            await setSigner(notOwner);

            await truffleAssert.fails(qTokenInstance.setAdmin(newAdmin, {s: null}),
                                      truffleAssert.INVALID_OPCODE, "NotOwner");
        });
    });

    describe("setOwner", async () => {
        it("should set new owner", async () => {
            const newOwner = accounts[1];
            await qTokenInstance.setOwner(newOwner, {s: null});

            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(newOwner, qTokenStorage.owner);
        });
        it("should get exception, call from not owner", async () => {
            const notOwner = accounts[1];
            const newOwner = accounts[2];
            await setSigner(notOwner);

            await truffleAssert.fails(qTokenInstance.setOwner(newOwner, {s: null}),
                                      truffleAssert.INVALID_OPCODE, "NotOwner");
        });
    });

    describe.only("updateInterest", async () => {
        it("should get expected value", async () => {
            await qTokenInstance.mint(DEFAULT, 100, {s: null});
            const qTokenStorage = await qTokenInstance.storage();
            console.log(qTokenStorage)
        });
    });
});
