#!/bin/sh


docker login
docker build --rm -t thienpow/pgpool:4.2.3 .
docker push thienpow/pgpool:4.2.3