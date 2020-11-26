const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require('truffle-assertions');

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require( "./helpers/signerSeter");
const { setSigner } = require( "./helpers/signerSeter");

const qToken = artifacts.require("qToken");

contract("qToken", async () => {
    const DEFAULT = accounts[0];

    let storage;
    let qTokenInstance;

    beforeEach("setup", async () => {
        storage = {
            owner:          DEFAULT,
            admin:          DEFAULT,
            lastUpdateTime: "2000-01-01T10:10:10.000Z",
            totalBorrows:   0,
            totalLiquid:    0,
            totalSupply:    0,
            totalReserves:  0,
            borrowIndex:    0,
            accountBorrows: MichelsonMap.fromLiteral({
                            [DEFAULT]: 0,
            }),
            accountTokens:  MichelsonMap.fromLiteral({
                            [DEFAULT]: 0,
            }),
        };

        qTokenInstance = await qToken.new(storage);
        await revertDefaultSigner();
    });

    describe("deploy", async () => {
        it("should check storage after deploy", async () => {
            const qTokenStorage = await qTokenInstance.storage();
            assert.equal(DEFAULT, qTokenStorage.owner);
            assert.equal(DEFAULT, qTokenStorage.admin);
            assert.equal("2000-01-01T10:10:10.000Z", qTokenStorage.lastUpdateTime);
            assert.equal(0, qTokenStorage.totalBorrows);
            assert.equal(0, qTokenStorage.totalLiquid);
            assert.equal(0, qTokenStorage.totalSupply);
            assert.equal(0, qTokenStorage.totalReserves);
            assert.equal(0, qTokenStorage.borrowIndex);
            assert.equal(0, await qTokenStorage.accountBorrows.get(DEFAULT));
            assert.equal(0, await qTokenStorage.accountTokens.get(DEFAULT));
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

    describe("updateInterest", async () => {
        it("TODO", async () => {

        });
    });
});
