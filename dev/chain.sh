#!/usr/bin/env bash
docker run --rm -it --network snapshot-keyper_default curl-multi http://chain:26657/$1
returnValue=$?
if [ $returnValue -eq 125 ]; # Image not yet downloaded
then
    docker pull ghcr.io/curl/curl-container/curl-multi:master
    docker tag ghcr.io/curl/curl-container/curl-multi:master curl-multi
    docker run --rm -it --network snapshot-keyper_default curl-multi http://chain:26657/$1
fi
