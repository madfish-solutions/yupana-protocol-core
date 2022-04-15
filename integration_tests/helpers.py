from os import urandom
from pytezos import pytezos
from pytezos.crypto.encoding import base58_encode
from pytezos.michelson.micheline import micheline_value_to_python_object

from pprint import pprint

PRECISION = pow(10, 18)
SECONDS_PER_BLOCK = 30
INITIAL_LIQUIDITY = 100_000

EOT = int(1e10) # end of times i.e. very big deadline

TOKEN_ADDRESS = "KT1VHd7ysjnvxEzwtjBAmYAmasvVCfPpSkiG"

alice = "tz1iA1iceA1iceA1iceA1iceA1ice9ydjsaW"
bob = "tz1iBobBobBobBobBobBobBobBobBodTWLCX"
carol = "tz1iCaro1Caro1Caro1Caro1Caro1CbMUKN1"
dave = "tz1iDaveDaveDaveDaveDaveDaveDatFC4So"
admin = "tz1iAdminAdminAdminAdminAdminAh4qKqu"

julian = "tz1iJu1ianJu1ianJu1ianJu1ianJtvTftP8"

candidate = "tz1XXPVLyQqsMVaQKnPWvD4q6nVwgwXUG4Fp"

# the same as Pytezos' `contract.context.get_self_address()`
contract_self_address = 'KT1BEqzn5Wx8uJrZNvuS9DVHmLvG9td3fDLi'

# the same as Pytezos' `contract.context.get_sender()`. The default Tezos.sender
me = "tz1Ke2h7sDdakHJQh8WX4Z372du1KChsksyU"

referral_system = "KT1AxaBxkFLCUi3f8rdDAAxBKHfzY8LfKDRA"

burn_address = "tz1ZZZZZZZZZZZZZZZZZZZZZZZZZZZZNkiRg"

def get_balance(res, address):
    return res.storage["ledger"][address]["balance"] 

def get_balance_by_token_id(res, address, token_id): # yToken storage variant
    return res.storage["storage"]["ledger"][(address, token_id)]

def get_frozen_balance(res, address):
    return res.storage["ledger"][address]["frozenBalance"] 

def parse_mints(res):
    mints = []
    for op in res.operations:
        if op["kind"] == "transaction":
            if op["parameters"]["entrypoint"] == "mint_tokens":
                mint = parse_mint_list(op)
                mints += mint
    return mints

def parse_tez_transfer(op):
    dest = op["destination"]
    amount = int(op["amount"])
    source = op["source"]
    return {"type": "tez", "destination": dest, "amount": amount, "source": source}

def parse_as_fa12(value):
    args = value["args"]

    return {
        "type": "token",
        "amount": int(args[2]["int"]),
        "destination": args[1]["string"],
        "source": args[0]["string"]
    }

def parse_as_fa2(values):
    result = []
    value = values[0]
    transfers = value["args"][1]
    for transfer in transfers:
        args = transfer["args"]

        amount = args[-1]["int"]
        amount = int(amount)

        token_id = args[1]["int"]
        token_id = int(token_id)

        dest = args[0]["string"]

        result.append({
            "type": "token",
            "token_id": token_id,
            "destination": dest,
            "amount": amount,
        })

    return result

def parse_transfers(res):
    token_transfers = []
    for op in res.operations:
        if op["kind"] == "transaction":
            entrypoint = op["parameters"]["entrypoint"]
            if entrypoint == "transfer":
                txs = parse_transfer(op)
                token_transfers += txs
    return token_transfers

def parse_transfer(op):
    transfers = []
    value = op["parameters"]["value"]
    if not isinstance(value, list):
        transfer = parse_as_fa12(value)
        transfers.append(transfer)
    else:
        transfers += parse_as_fa2(value)

    for transfer in transfers:
        transfer["token_address"] = op["destination"]

    return transfers

def parse_mint_list(op):
    list = []
    values = op["parameters"]["value"]
    for value in values:
        args = value["args"]
        dest = args[0]["string"]
        amount = int(args[1]["int"])
        list.append({
            "type": "mint",
            "amount": amount,
            "destination": dest,
            "token_address": "fa12_dummy",
        })
    return list

# be warned it can't handle two of the same entrypoints
def parse_calls(res):
    calls = {}
    for op in res.operations:
        transfer = op["parameters"]
        name = transfer["entrypoint"]
        args = micheline_value_to_python_object(transfer["value"])
        calls[name] = args
    return calls

def parse_delegations(res):
    delegates = []
    for op in res.operations:
        if op["kind"] == "delegation":
            delegates.append(op["delegate"])
    return delegates

def parse_votes(res):
    result = []

    for op in res.operations:
        if op["kind"] == "transaction":
            entrypoint = op["parameters"]["entrypoint"]
            if entrypoint == "use":
                tx = parse_vote(op)
                result.append(tx)

    return result

def parse_vote(op):
    args = op["parameters"]["value"]["args"]
    while "args" in args[0]:
        args = args[0]["args"]

    res = {
        "type": "vote",
        "delegate": args[0]["string"],
        "amount": int(args[1]["int"])
    }
    
    return res

def parse_ops(res):
    result = []

    for op in res.operations:
        if op["kind"] == "transaction":
            entrypoint = op["parameters"]["entrypoint"]
            if entrypoint == "default":
                tx = parse_tez_transfer(op)
                result.append(tx)
            elif entrypoint == "mint":
                continue
                mint = parse_mint_list(op)
                result += mint
            elif entrypoint == "transfer":
                tx = parse_transfer(op)
                result += tx
            elif entrypoint == "use":
                tx = parse_vote(op)
                result.append(tx)

    return result

def format_numbers(d):
    res = {}
    for key,val in d.items():        
        if isinstance(val, dict):
            res[key] = format_numbers(val)
        if isinstance(val, list): # TODO can here be just strings?
            new_list = []
            for i in val:
                if isinstance(i, dict):
                    new_val = format_numbers(i)
                    new_list.append(new_val)
            res[key] = new_list
        elif isinstance(val, int):
            # res[key] = f"{val:_}"
            res[key] = val / 1e18
    return res


# converts numbers 
def pprint_aux(d):
    print("\n")
    res = format_numbers(d)
    pprint(res)

# accepts internal res.storage["storage"]
def calc_max_colateral(storage, user):
    markets = storage["markets"]
    if user not in markets:
        return 0
        
    acc = 0
    for market in markets[user]:
        token_id = market
        token = storage["tokenInfo"][token_id]
        balance = storage["ledger"][(user,token_id)]
        acc += ((int(balance) * token["lastPrice"]
            * token["collateralFactorF"]) * (abs(token["totalLiquidF"]
            + token["totalBorrowsF"] - token["totalReservesF"])
            / token["totalSupplyF"]) / PRECISION);
    
    return acc

def calc_outstanding_borrow(storage, user):
    borrows = storage["borrows"]
    if user not in borrows:
        return 0
        
    acc = 0
    for token_id in borrows.items():
        token_info = storage["tokenInfo"][token_id]
        balance = storage["ledger"].get((user,token_id), 0)
        account = storage["accountInfo"][(user,token_id)]
        if balance > 0 or account["borrow"] > 0:
            acc += (account["borrow"] * token_info["lastPrice"])

    return acc

def calc_utilization_rate(storage, token_id):
    token = storage["tokens"][token_id]
    denominator = token["totalLiquidF"] + token["totalBorrowsF"]  - token["totalReservesF"]
    return PRECISION * token["totalBorrowsF"] // denominator

# def calc_borrow_rate(storage, token_id):
#     util = calc_utilization_rate(storage, token_id);
#     kink = storage["kinkRateF"]
#     if util <= kink:
#         return util * mutliplierF / PRECISION + baseRateF
#     else:
#         normalRate = kink * mutliplierF / PRECISION  + baseRateF;
#         excessUtil = util - kink;
#         return excessUtil * jumpMultiplierPerBlock / 1e18 + normalRate


# calculates shares balance
def calc_total_balance(res, address):
    ledger = res.storage["storage"]["ledger"][address]
    return ledger["balance"] + ledger["frozen_balance"]


def generate_random_address() -> str:
    return base58_encode(urandom(20), b"KT1").decode()

def wrap_fa2_token(address, id):
    return {
        "fa2": {
            "address": address,
            "token_id": id
        }
    }

def wrap_fa12_token(address, id):
    return {
        "fa12": {
            "address": address,
        }
    }

def calc_out_per_hundred(chain, dex):
    res = chain.interpret(
        dex.tokenToTezPayment(amount=100, min_out=1, receiver=alice), amount=0
    )
    ops = parse_ops(res)
    tez_out = ops[0]["amount"]

    res = chain.interpret(dex.tezToTokenPayment(min_out=1, receiver=alice), amount=100)
    ops = parse_ops(res)
    token_out = ops[0]["amount"]

    return (tez_out, token_out)


def get_percentage_diff(previous, current):
    try:
        percentage = abs(previous - current) / max(previous, current) * 100
    except ZeroDivisionError:
        percentage = float("inf")
    return percentage


def operator_add(owner, operator, token_id=0):
    return {
        "add_operator": {"owner": owner, "operator": operator, "token_id": token_id}
    }

def get_map_without_none(map):
    return {key: value for key,value in map.items() if value != None}

def none_sets_to_lists(full_storage):
    if "storage" in full_storage:
        internal = full_storage["storage"]
        internal["markets"] = get_map_without_none(internal["markets"])
        internal["borrows"] = get_map_without_none(internal["borrows"])

    return full_storage

class LocalChain:
    def __init__(self, storage=None):
        self.storage = storage

        self.balance = 0
        self.now = 0
        self.payouts = {}
        self.contract_balances = {}

    """ execute the entrypoint and save the resulting state and balance updates """
    def execute(self, call, amount=0, sender=None, source=None):
        new_balance = self.balance + amount
        res = call.interpret(
            amount=amount,
            storage=self.storage,
            balance=new_balance,
            now=self.now,
            sender=sender,
            source=source,
        )
        self.balance = new_balance
        self.storage = none_sets_to_lists(res.storage)

        # calculate total xtz payouts from contract
        ops = parse_ops(res)
        for op in ops:
            if op["type"] == "tez":
                dest = op["destination"]
                amount = op["amount"]
                self.payouts[dest] = self.payouts.get(dest, 0) + amount

                # reduce contract balance in case it has sent something
                if op["source"] == contract_self_address:
                    self.balance -= op["amount"]
                    
            elif op["type"] == "token":
                dest = op["destination"]
                amount = op["amount"]
                address = op["token_address"]
                if address not in self.contract_balances:
                    self.contract_balances[address] = {}
                contract_balance = self.contract_balances[address]
                if dest not in contract_balance:
                    contract_balance[dest] = 0
                contract_balance[dest] += amount
                # TODO source funds removal

        return res

    """ just interpret, don't store anything """
    def interpret(self, call, amount=0, sender=None, source=None):
        res = call.interpret(
            amount=amount,
            storage=self.storage,
            balance=self.balance,
            now=self.now,
            sender=sender,
            source=source
        )
        return res

    def advance_blocks(self, count=1):
        self.now += count * SECONDS_PER_BLOCK

