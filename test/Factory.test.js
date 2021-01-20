const { MichelsonMap } = require("@taquito/michelson-encoder");
const truffleAssert = require('truffle-assertions');

const { accounts } = require("../scripts/sandbox/accounts");
const { revertDefaultSigner } = require( "./helpers/signerSeter");
const { setSigner } = require( "./helpers/signerSeter");

const Factory = artifacts.require("Factory");
const TestController = artifacts.require("TestController");

contract ("Factory", async () => {
    const DEFAULT = accounts[0];
    const RECEIVER = accounts[1];
    const LIQUIDATOR = accounts[3];

    let storage;
    let fInstance;
    let token_adress = "tz0";

    const tokenList = MichelsonMap.fromLiteral({
        [DEFAULT]: {
            token_list: "tz1"
        },
        [RECEIVER]: {
            token_list: "tz2"
        }
    });
    

    beforeEach("setup", async () => {
        storage = {
            token_list = []
        }
        fInstance = await Factory.new(storage);
        
        await revertDefaultSigner();
    })

    describe("launch_exchange", async () => {
        it("set a new qToken", async () => {
            const contractOwner = accounts[1];
            await FInstance.launch_exchange(contractOwner, token_adress);

            const fStorage = await fInstance.storage();
            assert.equal(contractOwner, fStorage.token_list[contractOwner]);
        });
    })
})
