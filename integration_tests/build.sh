#!/bin/sh

mkdir -p integration_tests/compiled
docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-contract $PWD/contracts/main/yToken.ligo main > integration_tests/compiled/yToken.tz

mkdir -p integration_tests/compiled/lambdas

DIR=integration_tests/compiled/lambdas/ytoken
mkdir -p $DIR
for i in 0,mint \
        1,redeem \
        2,borrow \
        3,repay \
        4,liquidate \
        5,enterMarket \
        6,exitMarket \
        7,setAdmin \
        8,withdrawReserve \
        9,addMarket \
        10,updateMetadata \
        11,setTokenFactors \
        12,setGlobalFactors \
        13,setBorrowPause \
         ; do 

    IDX=${i%,*};
    FUNC=${i#*,};
    echo $IDX-$FUNC;

    docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-expression pascaligo --michelson-format=json --init-file $PWD/contracts/main/yToken.ligo "SetUseAction(record index = ${IDX}n; func = Bytes.pack(${FUNC}); end)" > $PWD/$DIR/${IDX}-${FUNC}.json
done
