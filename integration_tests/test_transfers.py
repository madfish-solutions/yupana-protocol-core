from unittest import TestCase

from helpers import *

from pprint import pprint

from pytezos import ContractInterface, pytezos, MichelsonRuntimeError
from pytezos.context.mixin import ExecutionContext
from initial_storage import use_lambdas, token_lambdas

token_a_address = "KT18amZmM5W7qDWVt2pH6uj7sCEd3kbzLrHT"
token_b_address = "KT1AxaBxkFLCUi3f8rdDAAxBKHfzY8LfKDRA"
token_c_address = "KT1XXAavg3tTj12W1ADvd3EEnm1pu6XTmiEF"
token_a = {"fA12": token_a_address}
token_b = {"fA12" : token_b_address}
token_c = {"fA12" : token_c_address}

interest_model = "KT1LzyPS8rN375tC31WPAVHaQ4HyBvTSLwBu"
price_feed = "KT1Qf46j2x37sAN4t2MKRQRVt9gc4FZ5duMs"

class DexTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.maxDiff = None

        code = open("./integration_tests/compiled/yToken.tz", 'r').read()
        cls.ct = ContractInterface.from_michelson(code)

        storage = cls.ct.storage.dummy()
        storage["useLambdas"] = use_lambdas
        storage["tokenLambdas"] = token_lambdas
        storage["storage"]["admin"] = admin
        storage["storage"]["priceFeedProxy"] = price_feed
        storage["storage"]["maxMarkets"] = 10
        storage["storage"]["closeFactorF"] = int(0.5 * PRECISION)
        storage["storage"]["liqIncentiveF"] = int(1.05 * PRECISION)
        cls.storage = storage

    def add_token(self, chain, token, config=None):
        if not config:
            config = {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000,
                "threshold": 0.8,
                "reserve_liquidation_rate": 0.05
            }
        res = chain.execute(self.ct.addMarket(
                interestRateModel = interest_model,
                asset = token,
                collateralFactorF = int(config["collateral_factor"] * PRECISION),
                reserveFactorF = int(config["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1_000_000*PRECISION,
                token_metadata = {"": ""},
                thresholdF = int(config["threshold"] * PRECISION),
                liquidReserveRateF = int(config["reserve_liquidation_rate"] * PRECISION)
            ), sender=admin)

        token_num = res.storage["storage"]["lastTokenId"] - 1

        chain.execute(self.ct.priceCallback(token_num, config["price"]), sender=price_feed)

        liquidity = config["liquidity"]
        if liquidity == 0: return

        chain.execute(self.ct.mint(token_num, liquidity, 1), sender=admin)

    def test_simple_transfer(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 100_000, 1), sender=alice)

        chain.execute(self.ct.enterMarket(0), sender=bob)
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(0, 1, chain.now + 2), sender=bob)

        transfer = self.ct.transfer(
            [{ "from_" : alice,
                "txs" : [{
                    "amount": 10_000,
                    "to_": bob,
                    "token_id": 0
                }]
            }])
        
        res = chain.execute(transfer, sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(1, 5_001, chain.now + 2), sender=bob)
        chain.execute(self.ct.borrow(1, 5_000, chain.now + 2), sender=bob)

    def test_zero_transfer(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 10_000, 1), sender=alice)

        chain.execute(self.ct.enterMarket(0), sender=bob)
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(0, 1, chain.now + 2), sender=bob)

        transfer = self.ct.transfer(
            [{ "from_" : alice,
                "txs" : [
                    {
                        "amount": 0,
                        "to_": bob,
                        "token_id": 0
                    },
                    {
                        "amount": 6_000,
                        "to_": alice,
                        "token_id": 0
                    }
                ]
            }])
        
        res = chain.execute(transfer, sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 1, chain.now + 2), sender=bob)

        # alice cannot borrow more than 5000. e.g. her balance is unchanged
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 10_000 + 1, chain.now + 2), sender=alice)
        chain.execute(self.ct.redeem(0, 10_000, chain.now + 2), sender=alice)




