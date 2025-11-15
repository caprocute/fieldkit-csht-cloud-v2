#!/bin/bash

set -xe

while true; do
	if curl $1 -m 5 -v; then
		break
	fi
	sleep 1
done
