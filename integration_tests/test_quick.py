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
        storage["storage"]["admin"] = admin
        storage["storage"]["priceFeedProxy"] = price_feed
        storage["storage"]["maxMarkets"] = 10
        storage["storage"]["closeFactorF"] = int(0.5 * PRECISION)
        storage["storage"]["liqIncentiveF"] = int(1.05 * PRECISION)
        storage["storage"]["threshold"] = int(0.8 * PRECISION)
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
                collateralFactorF = int(config["collateral_factor"] * PRECISION),
                reserveFactorF = int(config["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1_000_000*PRECISION,
                tokenMetadata = {"": ""}
            ), sender=admin)

        token_num = res.storage["storage"]["lastTokenId"] - 1

        chain.execute(self.ct.priceCallback(token_num, config["price"]), sender=price_feed)

        liquidity = config["liquidity"]
        if liquidity == 0: return

        chain.execute(self.ct.mint(token_num, liquidity), sender=admin)


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
                interestRateModel = interest_model,
                assetAddress = token_a,
                collateralFactorF = int(config_a["collateral_factor"] * PRECISION),
                reserveFactorF = int(config_a["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1_000_000*PRECISION,
                tokenMetadata = {"": ""}
            ), sender=admin)

        res = chain.execute(self.ct.addMarket(
                interestRateModel = interest_model,
                assetAddress = token_b,
                collateralFactorF = int(config_b["collateral_factor"] * PRECISION),
                reserveFactorF = int(config_b["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1_000_000*PRECISION,
                tokenMetadata = {"": ""}
            ), sender=admin)

        chain.execute(self.ct.priceCallback(0, config_a["price"]), sender=price_feed)
        chain.execute(self.ct.priceCallback(1, config_b["price"]), sender=price_feed)

        res = chain.execute(self.ct.mint(0, config_a["liquidity"]), sender=admin)
        res = chain.execute(self.ct.mint(1, config_b["liquidity"]), sender=admin)

        return chain

    def test_simple_borrow_repay(self):
        chain = self.create_chain_with_ab_markets()

        res = chain.execute(self.ct.mint(0, 128))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["source"], me)
        self.assertEqual(transfers[0]["amount"], 128)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

        res = chain.execute(self.ct.enterMarket(0))

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(0, 65))
        
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
            res = chain.execute(self.ct.redeem(0, 129))

        res = chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.redeem(0, 128))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 128)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

    def test_can_simply_redeem(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.exitMarket(0))
        
        res = chain.execute(self.ct.redeem(0, 100))

        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 100)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

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

        res = chain.execute(self.ct.priceCallback(0, 50), sender=price_feed)

        res = chain.execute(self.ct.liquidate(1, 0, me, 25), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(len(transfers), 1)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 25)
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        chain.execute(self.ct.repay(1, 25))
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
        res = chain.execute(self.ct.priceCallback(0, 30), sender=price_feed)

        # pprint_aux(res.storage["storage"])
        # return

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.liquidate(1, 0, alice, 25_001), sender=bob)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 10_000), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 10_000) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 15_000), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 15_000) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)
        

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
        chain.execute(self.ct.priceCallback(1, 300), sender=price_feed)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, alice, 50_001), sender=bob)
            
        res = chain.execute(self.ct.liquidate(1, 0, alice, 25_000), sender=bob)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 25_000) 
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

        chain.execute(self.ct.priceCallback(0, 0), sender=price_feed)

        # even though the price has changed, nothing to liquidate
        # second collateral fully covers the debt
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(2, 0, me, 1), sender=bob)

        chain.execute(self.ct.repay(2, 50_000))

        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
                
    def test_liquidate_due_to_interest_rate(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 10))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 5))

        chain.advance_blocks(1)
        chain.execute(self.ct.updateInterest(0))
        # chain.execute(self.ct.accrueInterest(0, 0), sender=interest_model)
        chain.execute(self.ct.priceCallback(0, 100_000), sender=price_feed)

        # at this rate one second accrues 1 token of interest
        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.accrueInterest(1, int(0.1 * 1e18)), sender=interest_model)
        chain.execute(self.ct.priceCallback(1, 100_000), sender=price_feed)
        
        # verify only 20 tokens could be repayed
        with self.assertRaises(MichelsonRuntimeError):
            chain.interpret(self.ct.repay(1, 21))
        chain.interpret(self.ct.repay(1, 20))



        # can liquidate at least 9 tokens which is 0.5 * 20 - 1
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, me, 11), sender=bob)
        chain.execute(self.ct.liquidate(1, 0, me, 9), sender=bob)
        
    def test_interest_rate_accrual(self):
        chain = self.create_chain_with_ab_markets()
        
        token_b_config = {
            "collateral_factor": 0.5,
            "reserve_factor": 0.5,
            "price": 100,
            "liquidity": 0,
        }

        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a) # token a provided by admin
        self.add_token(chain, token_b, token_b_config) # token b will be provided by alice

        chain.execute(self.ct.mint(1, 100_000), sender=alice)
        # chain.execute(self.ct.redeem(1, 100_010), sender=alice)

        chain.execute(self.ct.mint(0, 20_000))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 10_000))
        
        chain.advance_blocks(1)

        chain.execute(self.ct.updateInterest(0))
        # chain.execute(self.ct.accrueInterest(0, 0), sender=interest_model)
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)

        # at this rate one second accues 1 token of interest
        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.accrueInterest(1, 100_000_000_000_000), sender=interest_model)
        chain.execute(self.ct.priceCallback(1, 100), sender=price_feed)
                  
        chain.execute(self.ct.repay(1, 10_030))
        chain.execute(self.ct.exitMarket(0))

        # pprint_aux(res.storage["storage"])
        # return

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(1, 100_016), sender=alice)

        chain.execute(self.ct.redeem(1, 100_015), sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.withdrawReserve(1, 16), sender=admin)

        chain.execute(self.ct.withdrawReserve(1, 15), sender=admin)

    def test_whale_redeems_its_collateral(self):
        chain = self.create_chain_with_ab_markets()
        
        chain.execute(self.ct.mint(0, 100_000))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50_000))

        # since admin is our main whale he can take funds
        chain.execute(self.ct.redeem(1, 50_000), sender=admin)
        
        with self.assertRaises(MichelsonRuntimeError):        
            chain.execute(self.ct.redeem(1, 1), sender=admin)


    def test_collateral_interest_avoids_liquidation(self):
        chain = self.create_chain_with_ab_markets()
        
        chain.execute(self.ct.mint(0, 10), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.borrow(1, 5), sender=alice)

        chain.execute(self.ct.mint(1, 10), sender=bob)
        chain.execute(self.ct.enterMarket(1), sender=bob)
        chain.execute(self.ct.borrow(0, 5), sender=bob)

        chain.advance_blocks(1)
        
        chain.execute(self.ct.updateInterest(0))
        chain.execute(self.ct.accrueInterest(0, 100_000_000_000_000), sender=interest_model)
        chain.execute(self.ct.priceCallback(0, 100_000), sender=price_feed)

        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.accrueInterest(1, 100_000_000_000_000), sender=interest_model)
        chain.execute(self.ct.priceCallback(1, 100_000), sender=price_feed)

        # TODO


    def test_token_self_borrow(self):
        chain = self.create_chain_with_ab_markets()
        
        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        res = chain.execute(self.ct.borrow(0, 50))
        transfers = parse_transfers(res)
        pprint(transfers)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(0, 1))

    def test_should_verify_token_updates(self):
        chain = self.create_chain_with_ab_markets()

        chain.advance_blocks(1)

        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.mint(0, 100))
        self.assertIn("update", error.exception.args[-1])

        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.borrow(0, 100))
        self.assertIn("update", error.exception.args[-1])

        with self.assertRaises(MichelsonRuntimeError) as error:
            # chain.execute(self.ct.liquidate(0, 100))
            chain.execute(self.ct.liquidate(1, 0, me, 100), sender=bob)
        self.assertIn("update", error.exception.args[-1])
        # TODO verify liquiate updates all necessary tokens

    def test_threshold(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50))
        
        # cannot yet liquidate since 0.5 // 0.63 < 0.8
        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.priceCallback(0, 63), sender=price_feed)
            chain.execute(self.ct.liquidate(1, 0, me, 25), sender=bob)
            
        chain.execute(self.ct.priceCallback(0, 62), sender=price_feed)
        chain.execute(self.ct.liquidate(1, 0, me, 25), sender=bob)


    def test_zeroes(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.mint(0, 0))

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        
        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.borrow(1, 0))

        res = chain.interpret(self.ct.repay(0, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 0)

        chain.execute(self.ct.borrow(1, 33))
        res = chain.execute(self.ct.repay(1, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 33)

        chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.redeem(0, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 100)

        res = chain.execute(self.ct.redeem(0, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 0)

        chain.advance_blocks(1)
        chain.execute(self.ct.updateInterest(0))
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)

        res = chain.execute(self.ct.redeem(0, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 0)
        
    def test_supply_drain(self):
        token_b_config = {
            "collateral_factor": 0.5,
            "reserve_factor": 0.5,
            "price": 100,
            "liquidity": 0,
        }

        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a) # token a provided by admin
        self.add_token(chain, token_b, token_b_config) # token b will be provided by alice

        res = chain.execute(self.ct.mint(1, 50), sender=bob)

        old_storage = res.storage["storage"]

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50))
        chain.execute(self.ct.repay(1, 50))
        chain.execute(self.ct.exitMarket(0))
        res = chain.execute(self.ct.redeem(0, 100))

        # do the same as above after ten blocks after supply was drained
        # check that everything stays the same
        chain.advance_blocks(10)
        chain.execute(self.ct.updateInterest(0))
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)
        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.priceCallback(1, 100), sender=price_feed)

        chain.execute(self.ct.mint(0, 100))
        chain.execute(self.ct.enterMarket(0))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(1, 51))

        chain.execute(self.ct.borrow(1, 50))
        chain.execute(self.ct.repay(1, 50))
        chain.execute(self.ct.exitMarket(0))

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(1, 101))

        chain.execute(self.ct.redeem(0, 100))