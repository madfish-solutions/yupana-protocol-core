from unittest import TestCase

from helpers import *

from pprint import pprint

from pytezos import ContractInterface, pytezos, MichelsonRuntimeError
from pytezos.context.mixin import ExecutionContext
from initial_storage import use_lambdas

token_a_address = "KT18amZmM5W7qDWVt2pH6uj7sCEd3kbzLrHT"
token_b_address = "KT1AxaBxkFLCUi3f8rdDAAxBKHfzY8LfKDRA"
token_c_address = "KT1XXAavg3tTj12W1ADvd3EEnm1pu6XTmiEF"
token_a = {"fA12": token_a_address}
token_b = {"fA12" : token_b_address}
token_c = {"fA12" : token_c_address}

token_a_interest_model = "KT1LzyPS8rN375tC31WPAVHaQ4HyBvTSLwBu"
token_b_interest_model = "KT1ND1bkLahTzVUt93zbDtGugpWcL23gyqgQ"
price_feed = "KT1Qf46j2x37sAN4t2MKRQRVt9gc4FZ5duMs"

interest_model = token_a_interest_model

class DexTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.maxDiff = None

        code = open("./integration_tests/compiled/yToken.tz", 'r').read()
        cls.ct = ContractInterface.from_michelson(code)

        storage = cls.ct.storage.dummy()
        storage["useLambdas"] = use_lambdas
        storage["storage"]["admin"] = admin
        storage["storage"]["priceFeedProxy"] = price_feed
        storage["storage"]["maxMarkets"] = 100
        storage["storage"]["closeFactorFloat"] = int(1 * PRECISION)
        storage["storage"]["liqIncentiveFloat"] = int(1.05 * PRECISION)
        cls.storage = storage

    def add_token(self, chain, token, config=None):
        if not config:
            config = {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000,
            }
        res = chain.execute(self.ct.addMarket(
                interestRateModel = interest_model,
                assetAddress = token,
                collateralFactorFloat = int(config["collateral_factor"] * PRECISION),
                reserveFactorFloat = int(config["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1*PRECISION,
                tokenMetadata = {"": ""}
            ), sender=admin)

        token_num = res.storage["storage"]["lastTokenId"] - 1

        chain.execute(self.ct.returnPrice(token_num, config["price"]), sender=price_feed)

        chain.execute(self.ct.mint(token_num, config["liquidity"]), sender=admin)


    def create_chain_with_ab_markets(self, config_a = None, config_b = None):
        if not config_a:
            config_a = {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000
            }
        if not config_b:
            config_b = {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000
            }

        chain = LocalChain(storage=self.storage)
        res = chain.execute(self.ct.addMarket(
                interestRateModel = token_a_interest_model,
                assetAddress = token_a,
                collateralFactorFloat = int(config_a["collateral_factor"] * PRECISION),
                reserveFactorFloat = int(config_a["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1*PRECISION,
                tokenMetadata = {"": ""}
            ), sender=admin)

        res = chain.execute(self.ct.addMarket(
                interestRateModel = token_b_interest_model,
                assetAddress = token_b,
                collateralFactorFloat = int(config_b["collateral_factor"] * PRECISION),
                reserveFactorFloat = int(config_b["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1*PRECISION,
                tokenMetadata = {"": ""}
            ), sender=admin)

        chain.execute(self.ct.returnPrice(0, config_a["price"]), sender=price_feed)
        chain.execute(self.ct.returnPrice(1, config_b["price"]), sender=price_feed)

        res = chain.execute(self.ct.mint(0, config_a["liquidity"]), sender=admin)
        res = chain.execute(self.ct.mint(1, config_b["liquidity"]), sender=admin)

        return chain

    def test_simple_borrow_repay(self):
        chain = self.create_chain_with_ab_markets()

        res = chain.execute(self.ct.mint(0, 77))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["source"], me)
        self.assertEqual(transfers[0]["amount"], 77)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

        res = chain.execute(self.ct.mint(1, 128))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["source"], me)
        self.assertEqual(transfers[0]["amount"], 128)
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(0, 78))
        
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(0, 129))

        res = chain.execute(self.ct.borrow(0, 10))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 10)
        self.assertEqual(transfers[0]["token_address"], token_a_address)
        
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.repay(0, 11))

        res = chain.execute(self.ct.repay(0, 10))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["source"], me)
        self.assertEqual(transfers[0]["amount"], 10)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.repay(0, 1))

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(0, 78))
        
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(0, 129))

        res = chain.execute(self.ct.redeem(0, 77))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 77)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

        res = chain.execute(self.ct.redeem(1, 128))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 128)
        self.assertEqual(transfers[0]["token_address"], token_b_address)

    def test_can_redeem(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.exitMarket(0), sender=alice)
        chain.execute(self.ct.redeem(0, 100), sender=alice)

    def test_cant_redeem_when_on_market(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 10), sender=alice)

    def test_cant_redeem_when_borrowed(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        
        chain.execute(self.ct.borrow(1, 50))
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(0))

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 10))

    def test_can_redeem_when_liquidated(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50))

        res = chain.execute(self.ct.returnPrice(0, 50), sender=price_feed)

        res = chain.execute(self.ct.liquidate(1, 0, me, 47), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(len(transfers), 1)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 47)
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        # TODO why do we have to repay and redeem after position has been liquidated?
        chain.execute(self.ct.repay(1, 3))
        chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.redeem(0, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 1)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

    def test_mint_redeem(self):
        chain = self.create_chain_with_ab_markets()

        res = chain.execute(self.ct.mint(0, 1))
        res = chain.execute(self.ct.mint(1, 100_000))

        # can't redeem more
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(0, 2))
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(1, 100_001))

        # fully redeem token a
        res = chain.execute(self.ct.redeem(0, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 1)
        self.assertEqual(transfers[0]["token_address"], token_a_address)
        
        # partially redeem token_b
        res = chain.execute(self.ct.redeem(1, 50_000))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 50_000)
        self.assertEqual(transfers[0]["token_address"], token_b_address)
        
        # cant redeem more than left
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(1, 50_001))

        # redeem the rest
        res = chain.execute(self.ct.redeem(1, 50_000))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 50_000)
        self.assertEqual(transfers[0]["token_address"], token_b_address)
        
        # cant redeem anymore
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(1, 1))


    def test_borrow_too_much(self):
        chain = self.create_chain_with_ab_markets(
            {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 1,
                "liquidity": 100_000
            },
            {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 1,
                "liquidity": 100_000
            }
        )

        res = chain.execute(self.ct.mint(0, 100), sender=alice)
        res = chain.execute(self.ct.enterMarket(0), sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(1, 51), sender=alice)

        res = chain.execute(self.ct.borrow(1, 50), sender=alice)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["destination"], alice)
        self.assertEqual(transfers[0]["amount"], 50) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        # can't borrow anymore due to collateral factor
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(1, 1), sender=alice)

    def test_liquidate_collateral_price_down(self):
        chain = self.create_chain_with_ab_markets(
            {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000
            },
            {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000
            }
        )

        res = chain.execute(self.ct.mint(0, 100_000), sender=alice)
        res = chain.execute(self.ct.enterMarket(0), sender=alice)
        res = chain.execute(self.ct.borrow(1, 50_000), sender=alice)

        # collateral price goes down
        res = chain.execute(self.ct.returnPrice(0, 50), sender=price_feed)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.liquidate(1, 0, alice, 50_001), sender=bob)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 10_000), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 10_000) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 40_000), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 40_000) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        # alice no longer can repay her funds
        res = chain.execute(self.ct.redeem(0, 10_000), sender=alice)
        transfers = parse_transfers(res)
        pprint(transfers)
        

    def test_liquidate_borrow_price_up(self):
        chain = self.create_chain_with_ab_markets(
            {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000
            },
            {
                "collateral_factor": 0.5,
                "reserve_factor": 0.5,
                "price": 100,
                "liquidity": 100_000
            }
        )

        chain.execute(self.ct.mint(0, 100_000), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.borrow(1, 50_000), sender=alice)

        # collateral price goes down
        chain.execute(self.ct.returnPrice(1, 300), sender=price_feed)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, alice, 50_001), sender=bob)
            
        res = chain.execute(self.ct.liquidate(1, 0, alice, 50_000), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 50_000) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)

    def test_multicollateral_cant_exit(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        self.add_token(chain, token_c)

        chain.execute(self.ct.mint(0, 100_000))
        chain.execute(self.ct.mint(1, 100_000))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(2, 100_001))
        
        chain.execute(self.ct.borrow(2, 100_000))

        # none of collaterals can leave
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(0))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(1))

        # after returning the half one collateral can fully leave
        chain.execute(self.ct.repay(2, 50_000))
        chain.execute(self.ct.exitMarket(0))

    def test_multicollateral_can_switch_collateral(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        self.add_token(chain, token_c)

        chain.execute(self.ct.mint(0, 100_000))
        chain.execute(self.ct.mint(1, 100_000))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
            
        chain.execute(self.ct.borrow(2, 50_000))

        # second collateral is basically unused
        chain.interpret(self.ct.exitMarket(1))

        chain.execute(self.ct.returnPrice(0, 0), sender=price_feed)

        # even though the price has changed, nothing to liquidate
        # second collateral fully covers the debt
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(2, 0, me, 1), sender=bob)

        chain.execute(self.ct.repay(2, 50_000))

        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
                
        

    def test_interest_rate(self):
        chain = self.create_chain_with_ab_markets()

        res = chain.execute(self.ct.mint(0, 100_000))
        res = chain.execute(self.ct.enterMarket(0))
        res = chain.execute(self.ct.borrow(1, 10_000))
        
        chain.advance_blocks(1)
        res = chain.execute(self.ct.accrueInterest(0, 0), sender=token_a_interest_model)
        res = chain.execute(self.ct.returnPrice(0, 100_000), sender=price_feed)

        # at this rate one second accues 1 token of interest
        res = chain.execute(self.ct.accrueInterest(1, 100_000_000_000_000), sender=token_b_interest_model)
        res = chain.execute(self.ct.returnPrice(1, 100_000), sender=price_feed)
                  
        # res = chain.execute(self.ct.redeem(0, 101_000))
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.repay(1, 10_029))
            res = chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.repay(1, 10_030))
        res = chain.execute(self.ct.exitMarket(0))

        # self.assertEqual(old_storage, res.storage["storage"])

