
for tst in $(ls $(dirname $0)/test_* | grep -v $(basename $0))
do
    $tst
done
