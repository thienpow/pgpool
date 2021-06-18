#!/bin/sh


docker login
docker build --rm -t thienpow/pgpool .
docker push thienpow/pgpool