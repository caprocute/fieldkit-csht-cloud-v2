#!/bin/bash

set -xe

pushd ../../tools/strfirm
cargo run -- --path ~/fk/firmware/fk
cp *.c *.h *.json ../../firmware/fk/l10n
popd

