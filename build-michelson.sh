#!/bin/sh

mkdir -p build
docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-contract $PWD/contracts/main/yToken.ligo main > build/yToken.tz

docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-contract $PWD/contracts/main/priceFeed.ligo main > build/priceFeed.tz

docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-contract $PWD/contracts/main/interestRate.ligo main > build/interestRate.tz

mkdir -p build/lambdas

DIR=build/lambdas/use
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
        9,setTokenFactors \
        10,setGlobalFactors \
        11,setBorrowPause \
         ; do 

    IDX=${i%,*};
    FUNC=${i#*,};
    echo $IDX-$FUNC;

    docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-expression pascaligo --init-file $PWD/contracts/main/yToken.ligo "${FUNC}" > $PWD/$DIR/${IDX}-${FUNC}.tz
done

DIR=build/lambdas/token
mkdir -p $DIR
for i in 0,transfer \
        1,update_operators \
        2,getBalance \
        3,get_total_supply \
         ; do 

    IDX=${i%,*};
    FUNC=${i#*,};
    echo $IDX-$FUNC;

    docker run -v $PWD:$PWD --rm -i ligolang/ligo:0.24.0 compile-expression pascaligo --init-file $PWD/contracts/main/yToken.ligo "${FUNC}" > $PWD/$DIR/${IDX}-${FUNC}.tz
done



