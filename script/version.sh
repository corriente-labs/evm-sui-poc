#!/bin/bash

movefile=`cat ./script/movefile`
echo "${movefile//REVISION/"$SUI_COMMIT_HASH"}" > Move.toml
echo Sui version is $SUI_COMMIT_HASH