from unittest import TestCase

from helpers import *
import copy

from pprint import pprint

from pytezos import ContractInterface, pytezos, MichelsonRuntimeError
from pytezos.context.mixin import ExecutionContext
from initial_storage import use_lambdas

token_a_address = "KT18amZmM5W7qDWVt2pH6uj7sCEd3kbzLrHT"
token_b_address = "KT1AxaBxkFLCUi3f8rdDAAxBKHfzY8LfKDRA"
token_c_address = "KT1XXAavg3tTj12W1ADvd3EEnm1pu6XTmiEF"
token_d_address = "KT1W41EKsq8ryThtC6rZN1H2YfZMqSkpbVjG"
token_a = {"fA12" : token_a_address}
token_b = {"fA12" : token_b_address}
token_c = {"fA12" : token_c_address}
token_d = {"fA2" : (token_d_address, 0)}

interest_model = "KT1LzyPS8rN375tC31WPAVHaQ4HyBvTSLwBu"
price_feed = "KT1Qf46j2x37sAN4t2MKRQRVt9gc4FZ5duMs"

one_percent_per_second = int(0.01 * PRECISION) #  interest rate

class DexTest(TestCase):

    @classmethod
    def setUpClass(cls):
        cls.maxDiff = None

        code = open("./integration_tests/compiled/yToken.tz", 'r').read()
        cls.ct = ContractInterface.from_michelson(code)

        storage = cls.ct.storage.dummy()
        storage["useLambdas"] = use_lambdas
        storage["storage"]["admin"] = admin
        storage["storage"]["admin_candidate"] = admin
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
                "reserve_liquidation_rate": 0.05,
            }
        res = chain.execute(self.ct.addMarket(
                interestRateModel = interest_model,
                asset = token,
                collateralFactorF = int(config["collateral_factor"] * PRECISION),
                reserveFactorF = int(config["reserve_factor"]  * PRECISION),
                maxBorrowRate = 1_000_000*PRECISION,
                token_metadata = {"": ""},
                threshold = int(config["threshold"] * PRECISION),
                liquidReserveRateF = int(config["reserve_liquidation_rate"] * PRECISION)
            ), sender=admin)

        token_num = res.storage["storage"]["lastTokenId"] - 1

        chain.execute(self.ct.priceCallback(token_num, config["price"]), sender=price_feed)

        liquidity = config["liquidity"]
        if liquidity == 0: return

        chain.execute(self.ct.mint(token_num, liquidity, 1), sender=admin)

    def create_chain_with_ab_markets(self, config_a = None, config_b = None):
        chain = LocalChain(storage=self.storage)

        self.add_token(chain, token_a, config_a)
        self.add_token(chain, token_b, config_b)

        return chain
    
    def create_chain_with_all_markets_and_limit(self, limit = 3, tokens = [ token_a, token_b, token_c, token_d ]):
        init_store = self.storage
        init_store["storage"]["maxMarkets"] = limit
        chain = LocalChain(storage=init_store)
        for token in tokens:
            self.add_token(chain, token, None)
        return chain

    def update_price_and_interest(self, chain, token_id, price, interest_rate):
        res = chain.execute(self.ct.updateInterest(token_id))
        is_awaiting_for_interest_callback = res.storage["storage"]["tokens"][token_id]["isInterestUpdating"]
        if is_awaiting_for_interest_callback:
            chain.execute(self.ct.accrueInterest(token_id, interest_rate), sender=interest_model)
        chain.execute(self.ct.priceCallback(token_id, price), sender=price_feed)

    def test_simple_borrow_repay(self):
        chain = self.create_chain_with_ab_markets()

        res = chain.execute(self.ct.mint(0, 128, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["source"], me)
        self.assertEqual(transfers[0]["amount"], 128)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

        res = chain.execute(self.ct.enterMarket(0))

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(0, 65, chain.now + 2))
        
        res = chain.execute(self.ct.borrow(0, 10, chain.now + 2))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 10)
        self.assertEqual(transfers[0]["token_address"], token_a_address)
        
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.repay(0, 11, chain.now + 2))

        res = chain.execute(self.ct.repay(0, 10, chain.now + 2))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["source"], me)
        self.assertEqual(transfers[0]["amount"], 10)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.repay(0, 1, chain.now + 2))

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(0, 129, 1))

        res = chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.redeem(0, 128, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 128)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

    def test_can_simply_redeem(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.exitMarket(0))
        
        res = chain.execute(self.ct.redeem(0, 100, 1))

        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 100)
        self.assertEqual(transfers[0]["token_address"], token_a_address)
        
    def test_enter_max_markets(self):
        limit = 3
        chain = self.create_chain_with_all_markets_and_limit(limit)
        for i in range(limit):
            chain.execute(self.ct.mint(i, 100, 1))
            chain.execute(self.ct.enterMarket(i))
        overflowed_market_id = limit

        # could mint but not enter
        chain.execute(self.ct.mint(overflowed_market_id, 100, 1))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.enterMarket(overflowed_market_id))

        for i in range(limit):
            chain.execute(self.ct.exitMarket(i))
            res = chain.execute(self.ct.redeem(i, 100, 1))
            transfers = parse_transfers(res)
            self.assertEqual(transfers[0]["destination"], me)
            self.assertEqual(transfers[0]["source"], contract_self_address)
            self.assertEqual(transfers[0]["amount"], 100)

    def test_cant_redeem_too_much_when_on_market(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100, 1), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        
        chain.execute(self.ct.borrow(1, 25, chain.now +2), sender=alice)
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 51, 1), sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, me, 1, 1, chain.now + 2), sender=bob)

        chain.execute(self.ct.redeem(0, 50, 1), sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 1, 1), sender=alice)
        

    def test_cant_redeem_when_borrowed(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        
        res = chain.execute(self.ct.borrow(1, 50, chain.now + 2))
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(0))

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 10, 1))

        print(calc_utilization_rate(res.storage["storage"], 0))
        print(calc_utilization_rate(res.storage["storage"], 1))

    def test_can_redeem_when_liquidated(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50, 1))

        self.update_price_and_interest(chain, 0, 50, 0)
        self.update_price_and_interest(chain, 1, 100, 0)

        # check that can't liquidate without price udpdate even tho liquidation is achieved
        chain.advance_blocks(1)
        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.liquidate(1, 0, me, 25, 1, chain.now + 2), sender=bob)
        self.assertIn("UPDATE", error.exception.args[-1])

        self.update_price_and_interest(chain, 0, 50, 0)
        self.update_price_and_interest(chain, 1, 100, 0)

        initial_reserves = get_reserves(chain, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(chain.storage['storage']['tokens'], 1, 0, 25)

        res = chain.execute(self.ct.liquidate(1, 0, me, 25, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)

        transfers = parse_transfers(res)
        self.assertEqual(len(transfers), 1)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 25)
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        chain.execute(self.ct.repay(1, 25, chain.now + 2))
        chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.redeem(0, 1, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 1)
        self.assertEqual(transfers[0]["token_address"], token_a_address)

    def test_mint_redeem(self):
        chain = self.create_chain_with_ab_markets()

        res = chain.execute(self.ct.mint(0, 1, 1))
        res = chain.execute(self.ct.mint(1, 100_000, 1))

        # can't redeem more
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(0, 2, 1))
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(1, 100_001, 1))

        # fully redeem token a
        res = chain.execute(self.ct.redeem(0, 1, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 1)
        self.assertEqual(transfers[0]["token_address"], token_a_address)
        
        # partially redeem token_b
        res = chain.execute(self.ct.redeem(1, 50_000, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 50_000)
        self.assertEqual(transfers[0]["token_address"], token_b_address)
        
        # cant redeem more than left
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(1, 50_001, 1))

        # redeem the rest
        res = chain.execute(self.ct.redeem(1, 50_000, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["destination"], me)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 50_000)
        self.assertEqual(transfers[0]["token_address"], token_b_address)
        
        # cant redeem anymore
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.redeem(1, 1, 1))


    def test_borrow_too_much(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        res = chain.execute(self.ct.mint(0, 100, 1), sender=alice)
        res = chain.execute(self.ct.enterMarket(0), sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(1, 51, chain.now + 2), sender=alice)

        res = chain.execute(self.ct.borrow(1, 50, chain.now + 2), sender=alice)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], contract_self_address)
        self.assertEqual(transfers[0]["destination"], alice)
        self.assertEqual(transfers[0]["amount"], 50) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)

        # can't borrow anymore due to collateral factor
        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(1, 1, 1), sender=alice)
            
    def test_borrow_max_markets(self):
        limit = 2
        chain = self.create_chain_with_all_markets_and_limit(limit)
        chain.execute(self.ct.mint(0, 10000, 1))
        chain.execute(self.ct.enterMarket(0))
        for i in range(limit):
            chain.execute(self.ct.borrow(i, 100, chain.now + 2))
        overflowed_market_id = limit
        # could mint but not borrow
        res = chain.execute(self.ct.mint(overflowed_market_id, 100, 1))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(overflowed_market_id, 100, chain.now + 2))

        for i in range(limit):
            res = chain.execute(self.ct.repay(i, 0, chain.now + 2))
            transfers = parse_transfers(res)
            self.assertEqual(transfers[0]["destination"], contract_self_address)
            self.assertEqual(transfers[0]["source"], me)
            self.assertEqual(transfers[0]["amount"], 100)

    def test_liquidate_collateral_price_down(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        res = chain.execute(self.ct.mint(0, 100_000, 1), sender=alice)
        res = chain.execute(self.ct.enterMarket(0), sender=alice)
        res = chain.execute(self.ct.borrow(1, 50_000, chain.now + 2), sender=alice)

        # collateral price goes down
        res = chain.execute(self.ct.priceCallback(0, 30), sender=price_feed)

        # pprint_aux(res.storage["storage"]["tokens"])
        # return

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, alice, 25_001, 1, chain.now + 2), sender=bob)
            
            
        initial_reserves = get_reserves(res, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(res.storage['storage']['tokens'], 1, 0, 10_000)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 10_000, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)
        

        # pprint_aux(res.storage["storage"]["tokens"])
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 10_000)
        self.assertEqual(transfers[0]["token_address"], token_b_address)


        initial_reserves = get_reserves(res, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(res.storage['storage']['tokens'], 1, 0, 15_000)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 15_000, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)

        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 15_000)
        self.assertEqual(transfers[0]["token_address"], token_b_address)
        

    def test_liquidate_borrow_price_up(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 100_000, 1), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.borrow(1, 50_000, chain.now + 2), sender=alice)

        # collateral price goes down
        res = chain.execute(self.ct.priceCallback(1, 300), sender=price_feed)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, alice, 50_001, 1, chain.now + 2), sender=bob)
            
            
        initial_reserves = get_reserves(res, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(res.storage['storage']['tokens'], 1, 0, 25_000)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 25_000, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)
        
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["source"], bob)
        self.assertEqual(transfers[0]["destination"], contract_self_address)
        self.assertEqual(transfers[0]["amount"], 25_000) 
        self.assertEqual(transfers[0]["token_address"], token_b_address)


    def test_basic_ops_after_liquidation(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        
        chain.execute(self.ct.mint(0, 100_000, 1), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.borrow(1, 50_000, chain.now + 2), sender=alice)

        # collateral price goes down
        res = chain.execute(self.ct.priceCallback(1, 300), sender=price_feed)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, alice, 50_001, 1, chain.now + 2), sender=bob)
            
        
        initial_reserves = get_reserves(res, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(res.storage['storage']['tokens'], 1, 0, 25_000)

        res = chain.execute(self.ct.liquidate(1, 0, alice, 25_000, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)
        
        chain.execute(self.ct.repay(1,0, chain.now + 2), sender=alice)

        # check that admin is able to withdraw all of his initially povided funds
        # do not perform an actual withdrawal.
        res = chain.interpret(self.ct.redeem(1, 0, 1), sender=admin)
        txs = parse_transfers(res)
        self.assertEqual(len(txs), 1)
        self.assertEqual(txs[0]["amount"], 100_000)

        # another person just does usual stuff after another one is liquidated
        chain.execute(self.ct.mint(0, 70_000, 1), sender=carol)
        chain.execute(self.ct.enterMarket(0), sender=carol)
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2), sender=carol)

        chain.advance_blocks(1)
        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        res = chain.execute(self.ct.repay(1, 0, chain.now + 2), sender=carol)
        txs = parse_transfers(res)
        self.assertEqual(len(txs), 1)
        self.assertEqual(txs[0]["amount"], 13_000)


    def test_multicollateral_cant_exit(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        self.add_token(chain, token_c)

        chain.execute(self.ct.mint(0, 100_000, 1))
        chain.execute(self.ct.mint(1, 100_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(2, 100_001, chain.now + 2))
        
        chain.execute(self.ct.borrow(2, 100_000, chain.now + 2))

        # none of collaterals can leave
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(0))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(1))

        # after returning the half one collateral can fully leave
        chain.execute(self.ct.repay(2, 50_000, chain.now + 2))
        chain.execute(self.ct.exitMarket(0))

    def test_multicollateral_can_switch_collateral(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        self.add_token(chain, token_c)

        chain.execute(self.ct.mint(0, 100_000, 1))
        chain.execute(self.ct.mint(1, 100_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
            
        chain.execute(self.ct.borrow(2, 50_000, chain.now + 2))

        # second collateral is basically unused
        chain.interpret(self.ct.exitMarket(1))

        chain.execute(self.ct.priceCallback(0, 0), sender=price_feed)

        # even though the price has changed, nothing to liquidate
        # second collateral fully covers the debt
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(2, 0, me, 1, 1, chain.now + 2), sender=bob)

        chain.execute(self.ct.repay(2, 50_000, chain.now + 2))

        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
                
    def test_liquidate_due_to_interest_rate(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 10, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 5, chain.now + 2))

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
            chain.interpret(self.ct.repay(1, 21, chain.now + 2))
        chain.interpret(self.ct.repay(1, 20, chain.now + 2))



        # can liquidate at least 9 tokens which is 0.5 * 20 - 1
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, me, 11, 1, chain.now + 2), sender=bob)
            
        initial_reserves = get_reserves(chain, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(chain.storage['storage']['tokens'], 1, 0, 9)

        res = chain.execute(self.ct.liquidate(1, 0, me, 9, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)
        
    def test_interest_rate_accrual(self):
        chain = self.create_chain_with_ab_markets()
        
        token_b_config = {
            "collateral_factor": 0.5,
            "reserve_factor": 0.5,
            "price": 100,
            "liquidity": 0,
            "threshold": 0.8,
            "reserve_liquidation_rate": 0.05,
        }

        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a) # token a provided by admin
        self.add_token(chain, token_b, token_b_config) # token b will be provided by alice

        chain.execute(self.ct.mint(1, 100_000, 1), sender=alice)
        # chain.execute(self.ct.redeem(1, 100_010), sender=alice)

        chain.execute(self.ct.mint(0, 20_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))
        
        chain.advance_blocks(1)

        chain.execute(self.ct.updateInterest(0))
        # chain.execute(self.ct.accrueInterest(0, 0), sender=interest_model)
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)

        # at this rate one second accues 1 token of interest
        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.accrueInterest(1, 100_000_000_000_000), sender=interest_model)
        chain.execute(self.ct.priceCallback(1, 100), sender=price_feed)
                  
        chain.execute(self.ct.repay(1, 10_030, chain.now + 2))
        chain.execute(self.ct.exitMarket(0))

        # pprint_aux(res.storage["storage"])
        # return

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(1, 100_016, 1), sender=alice)

        chain.execute(self.ct.redeem(1, 100_015, 1), sender=alice)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.withdrawReserve(1, 16), sender=admin)

        res = chain.execute(self.ct.withdrawReserve(1, 15), sender=admin)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 15)
        

    def test_whale_redeems_its_collateral(self):
        chain = self.create_chain_with_ab_markets()
        
        chain.execute(self.ct.mint(0, 100_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50_000, chain.now + 2))

        # since admin is our main whale he can take funds
        chain.execute(self.ct.redeem(1, 50_000, 1), sender=admin)
        
        with self.assertRaises(MichelsonRuntimeError):        
            chain.execute(self.ct.redeem(1, 1, 1), sender=admin)


    def test_collateral_interest_avoids_liquidation(self):
        chain = self.create_chain_with_ab_markets()
        
        chain.execute(self.ct.mint(0, 10, 1), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.borrow(1, 5, chain.now + 2), sender=alice)

        chain.execute(self.ct.mint(1, 10, 1), sender=bob)
        chain.execute(self.ct.enterMarket(1), sender=bob)
        chain.execute(self.ct.borrow(0, 5, chain.now + 2), sender=bob)

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
        
        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(0, 50, chain.now + 2))

        with self.assertRaises(MichelsonRuntimeError):
            res = chain.execute(self.ct.borrow(0, 1, chain.now + 2))
            
    def test_deadline(self):
        chain = self.create_chain_with_ab_markets()
        
        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(0, 50, chain.now - 1))
        chain.execute(self.ct.borrow(0, 50, chain.now + 2))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.repay(0, 50, chain.now - 1))
        chain.execute(self.ct.repay(0, 50, chain.now + 2))
    
    def test_min_received(self):
        chain = self.create_chain_with_ab_markets()
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.mint(0, 100, 101))
        chain.execute(self.ct.mint(0, 100, 99))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 50, 51))
        chain.execute(self.ct.redeem(0, 50, 49))
    
    def test_liquidate_min_seized_and_deadline(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 100_000, 1), sender=alice)
        chain.execute(self.ct.enterMarket(0), sender=alice)
        chain.execute(self.ct.borrow(1, 50_000, chain.now + 2), sender=alice)

        # collateral price goes down
        res = chain.execute(self.ct.priceCallback(1, 300), sender=price_feed)

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.liquidate(1, 0, alice, 50_001, 1, chain.now + 2), sender=bob)
        with self.assertRaises(MichelsonRuntimeError): # minSeized check (should seize 78750)
            res = chain.execute(self.ct.liquidate(1, 0, alice, 25_000, 80_000, chain.now + 2), sender=bob)
        with self.assertRaises(MichelsonRuntimeError): # deadline check
            chain.execute(self.ct.liquidate(1, 0, alice, 25_000, 1, chain.now - 1), sender=bob)
        res = chain.execute(self.ct.liquidate(1, 0, alice, 25_000, 1, chain.now + 2), sender=bob)


    def test_should_verify_token_updates(self):
        chain = self.create_chain_with_ab_markets()

        chain.advance_blocks(1)

        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.mint(0, 100, 1))
        self.assertIn("UPDATE", error.exception.args[-1])

        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.borrow(0, 100, chain.now + 2))
        self.assertIn("UPDATE", error.exception.args[-1])

    def test_threshold(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50, chain.now + 2))
        
        # cannot yet liquidate since 0.5 // 0.63 < 0.8
        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.priceCallback(0, 63), sender=price_feed)
            chain.execute(self.ct.liquidate(1, 0, me, 25, 1, chain.now + 2), sender=bob)
            
        res = chain.execute(self.ct.priceCallback(0, 62), sender=price_feed)
        
        initial_reserves = get_reserves(res, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(res.storage['storage']['tokens'], 1, 0, 25)

        res = chain.execute(self.ct.liquidate(1, 0, me, 25, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)


    def test_zeroes(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.mint(0, 0, 1))

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        
        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.borrow(1, 0, chain.now + 2))

        res = chain.interpret(self.ct.repay(0, 0, chain.now + 2))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 0)

        chain.execute(self.ct.borrow(1, 33, chain.now + 2))
        res = chain.execute(self.ct.repay(1, 0, chain.now + 2))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 33)

        chain.execute(self.ct.exitMarket(0))

        res = chain.execute(self.ct.redeem(0, 0, 1))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 100)

        res = chain.execute(self.ct.redeem(0, 0, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 0)

        chain.advance_blocks(1)
        chain.execute(self.ct.updateInterest(0))
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)

        res = chain.execute(self.ct.redeem(0, 0, 0))
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 0)
        
    def test_supply_drain(self):
        token_b_config = {
            "collateral_factor": 0.5,
            "reserve_factor": 0.5,
            "price": 100,
            "liquidity": 0,
            "threshold": 0.8,
            "reserve_liquidation_rate": 0.05,
        }

        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a) # token a provided by admin
        self.add_token(chain, token_b, token_b_config) # token b will be provided by alice

        res = chain.execute(self.ct.mint(1, 50, 1), sender=bob)

        old_storage = res.storage["storage"]

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 50, chain.now + 2))
        chain.execute(self.ct.repay(1, 50, 1))
        chain.execute(self.ct.exitMarket(0))
        res = chain.execute(self.ct.redeem(0, 100, 1))

        # do the same as above after ten blocks after supply was drained
        # check that everything stays the same
        chain.advance_blocks(10)
        chain.execute(self.ct.updateInterest(0))
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)
        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.priceCallback(1, 100), sender=price_feed)

        chain.execute(self.ct.mint(0, 100, 1))
        chain.execute(self.ct.enterMarket(0))
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(1, 51, chain.now + 2))

        chain.execute(self.ct.borrow(1, 50, chain.now + 2))
        chain.execute(self.ct.repay(1, 50, chain.now + 2))
        chain.execute(self.ct.exitMarket(0))

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.borrow(1, 101, chain.now + 2))

        chain.execute(self.ct.redeem(0, 100, 1))

    def test_two_borrows_interest_rate(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        self.add_token(chain, token_c)

        chain.execute(self.ct.mint(0, 40_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))
        chain.execute(self.ct.borrow(2, 10_000, chain.now + 2))
        
        chain.advance_blocks(1)

        chain.execute(self.ct.updateInterest(0))
        # chain.execute(self.ct.accrueInterest(0, 0), sender=interest_model)
        chain.execute(self.ct.priceCallback(0, 100), sender=price_feed)

        # at this rate one second accues 1 token of interest
        chain.execute(self.ct.updateInterest(1))
        chain.execute(self.ct.accrueInterest(1, 100_000_000_000_000), sender=interest_model)
        chain.execute(self.ct.priceCallback(1, 100), sender=price_feed)

        # same interest rate for the second borrow
        chain.execute(self.ct.updateInterest(2))
        chain.execute(self.ct.accrueInterest(2, 100_000_000_000_000), sender=interest_model)
        chain.execute(self.ct.priceCallback(2, 100), sender=price_feed)
                  
        chain.execute(self.ct.repay(1, 10_030, chain.now + 2))

        # borrow and immediately repay to invoke applyInterestToBorrows
        res = chain.execute(self.ct.borrow(1, 1, chain.now + 2))
        chain.execute(self.ct.repay(1, 1, chain.now + 2))

        res = chain.execute(self.ct.repay(2, 10_030, chain.now + 2))
        chain.execute(self.ct.exitMarket(0))


    def test_repay_and_delay_interest(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 40_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))
        
        chain.advance_blocks(1)
        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        chain.execute(self.ct.repay(1, 13_000, chain.now + 2))
        
        # nothing left to repay
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.repay(1, 1, chain.now + 2))

        # bob borrows in the meantime
        chain.execute(self.ct.mint(0, 40_000, 1), sender=bob)
        chain.execute(self.ct.enterMarket(0), sender=bob)
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2), sender=bob)
        
        chain.advance_blocks(1)
        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        chain.execute(self.ct.repay(1, 13_000, chain.now + 2), sender=bob)
        
        # alice repeats everything as the first time
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))
        
        chain.advance_blocks(1)

        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        # not meaningful, just to add some mess
        chain.execute(self.ct.redeem(0, 10_000, 1))

        # chain.execute(self.ct.repay(1, 10_030))
        res = chain.execute(self.ct.repay(1, 0, chain.now + 2))
        txs = parse_transfers(res)
        self.assertEqual(len(txs), 1)
        self.assertEqual(txs[0]["amount"], 13_000)      
        
    def test_withraw_admin_rewards(self):
        chain = LocalChain(storage=self.storage)

        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 40_000, 1))
        chain.execute(self.ct.enterMarket(0))
        
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))

        chain.advance_blocks(1)

        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        chain.execute(self.ct.repay(1, 13_000, chain.now + 2))
        # nothing left to repay
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.repay(1, 1, chain.now + 2))
        
        res = chain.execute(self.ct.withdrawReserve(1, 1_500), sender=admin)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 1_500)

        # nothing left to withdraw
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.withdrawReserve(1, 1), sender=admin)

        # bob borrows [0] in the meantime
        chain.execute(self.ct.mint(1, 40_000, 1), sender=bob)
        chain.execute(self.ct.enterMarket(1), sender=bob)
        chain.execute(self.ct.borrow(0, 10_000, chain.now + 2), sender=bob)

        chain.advance_blocks(1)

        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        chain.execute(self.ct.repay(0, 13_000, chain.now + 2), sender=bob)
        # nothing left to repay
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.repay(1, 1, chain.now + 2))
        # receive rewards after bob borrow
        res = chain.execute(self.ct.withdrawReserve(0, 1_500), sender=admin)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 1_500)
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.withdrawReserve(0, 1), sender=admin)

        # `me` repeats everything as the first time
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))

        chain.advance_blocks(1)

        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)

        # not meaningful, just to add some mess
        chain.execute(self.ct.redeem(0, 10_000, 1))
        res = chain.execute(self.ct.repay(1, 0, chain.now + 2))
        txs = parse_transfers(res)
        self.assertEqual(len(txs), 1)
        self.assertEqual(txs[0]["amount"], 13_000)
        # nothing left to repay
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.repay(1, 1, chain.now + 2))
        # receive rewards after alice borrow
        res = chain.execute(self.ct.withdrawReserve(1, 1_500), sender=admin)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 1_500)
        # nothing left to repay and withdraw
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.withdrawReserve(1, 1), sender=admin)

    def test_real_world_liquidation(self):
        price_a = 5244313
        price_b = 56307584485

        config_a = {
            "collateral_factor": 0.65,
            "reserve_factor": 0.20,
            "price": price_a,
            "liquidity": 100_000,
            "threshold": 0.55,
            "reserve_liquidation_rate": 0.05,
        }

        config_b = {
            "collateral_factor": 0.75,
            "reserve_factor": 0.15,
            "price": price_b,
            "liquidity": 100_000,
            "threshold": 0.55,
            "reserve_liquidation_rate": 0.05,
        }

        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a, config_a)
        self.add_token(chain, token_b, config_b)

        chain.execute(self.ct.mint(0, 200_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 12, chain.now + 2))

        chain.advance_blocks((2 * 60 * 60) // 30) # 2 hours

        chain.execute(self.ct.priceCallback(0, 5016646), sender=price_feed)
        chain.execute(self.ct.updateInterest(0))
        # chain.execute(self.ct.accrueInterest(0, 0), sender=interest_model) # no borrows

        chain.execute(self.ct.priceCallback(1, 54986875588), sender=price_feed)
        chain.execute(self.ct.updateInterest(1))
        res = chain.execute(self.ct.accrueInterest(1, 635296632), sender=interest_model)

        initial_reserves = get_reserves(res, 0)

        expected_reserves_bonus = calculate_reserves_bonus_by_liqidation(res.storage['storage']['tokens'], 1, 0, 1)

        res = chain.execute(self.ct.liquidate(1, 0, me, 1, 1, chain.now + 2), sender=bob)

        actual_reserves = get_reserves(res, 0)
        actual_reserves_bonus = (actual_reserves - initial_reserves)
        self.assertAlmostEqual(actual_reserves_bonus, expected_reserves_bonus)

    def test_exit_market_with_present_borrow(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)
        self.add_token(chain, token_c)

        chain.execute(self.ct.mint(0, 15_000, 1))
        chain.execute(self.ct.mint(1, 5_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.enterMarket(1))
        chain.execute(self.ct.borrow(2, 10_000, chain.now + 2))
        chain.execute(self.ct.repay(2, 2_500, chain.now + 2))
        
        # can't exit fi
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.exitMarket(0))
    
        chain.execute(self.ct.exitMarket(1))

    def test_sequential_mints_exchange_rate(self):
        chain = LocalChain(storage=self.storage)
        self.add_token(chain, token_a)
        self.add_token(chain, token_b)

        chain.execute(self.ct.mint(0, 15_000, 1), sender=alice)

        chain.execute(self.ct.mint(1, 75_000, 1), sender=bob)
        chain.execute(self.ct.enterMarket(1), sender=bob)
        chain.execute(self.ct.borrow(0, 10_000, chain.now + 2), sender=bob)

        chain.advance_blocks(100)
        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)
        
        # repay everything
        res = chain.execute(self.ct.repay(0, 0, chain.now + 2), sender=bob)

        res = chain.execute(self.ct.mint(0, 10_000, 1), sender=carol)
        transfers = parse_transfers(res)
        self.assertEqual(transfers[0]["amount"], 10_000)
        
        res = chain.execute(self.ct.redeem(0, 0, 1), sender=carol)
        transfers = parse_transfers(res)
        self.assertAlmostEqual(transfers[0]["amount"], 10_000, delta=1)


    def test_redeem_same_borrowed_token(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 100_000_000, 1), sender=bob)
        
        chain.execute(self.ct.mint(0, 100_000_000, 1))
        chain.execute(self.ct.enterMarket(0))
        
        res = chain.execute(self.ct.borrow(0, 2_000_000, chain.now + 2))
        
        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 0, 1)) # 0 is 100_000_000 in this case

        with self.assertRaises(MichelsonRuntimeError):
            chain.execute(self.ct.redeem(0, 96_000_001, 1)) # 0 is 100_000_000 in this case
        
        chain.execute(self.ct.redeem(0, 96_000_000, 1))
        

    def test_not_updated_price_when_redeem(self):
        chain = self.create_chain_with_ab_markets()

        chain.execute(self.ct.mint(0, 40_000, 1))
        chain.execute(self.ct.enterMarket(0))
        chain.execute(self.ct.borrow(1, 10_000, chain.now + 2))
        
        chain.advance_blocks(1)
        self.update_price_and_interest(chain, 0, 100, one_percent_per_second)
        
        # not updated price of borrowed token
        with self.assertRaises(MichelsonRuntimeError) as error:
            chain.execute(self.ct.redeem(0, 0, 1))
        self.assertIn("NEED_UPDATE", error.exception.args[-1])
        
        self.update_price_and_interest(chain, 1, 100, one_percent_per_second)
        chain.execute(self.ct.repay(1, 0, chain.now + 2))
        chain.execute(self.ct.redeem(0, 0, 1))