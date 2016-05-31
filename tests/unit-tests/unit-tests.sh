#!/bin/bash
tests_succeded=true
for tst in $(ls $(dirname $0)/test* | grep -v $(basename $0))
do
    $tst || tests_succeded=false
done

$tests_succeded
