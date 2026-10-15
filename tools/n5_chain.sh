#!/bin/sh
# n5 시험을 하나씩 차례로 돌린다 (각각 /tmp/hanjang-headless.lock 을 잡는다).
cd "$(dirname "$0")/.." || exit 1
E=spec/hanjang-web/evidence/n5
for m in ${MODES:-full-windowed drop-fin drop-nofin}; do
  python3 tools/n5_lock.py python3 tools/n5_scenarios.py $m > $E/$m.out 2>&1
done
python3 tools/n5_lock.py tools/n5_repeat.sh game/tests/test_rejoin.sh 6 $E/rejoin-repeat.log /tmp/n5_rj
python3 tools/n5_lock.py tools/n5_repeat.sh game/tests/test_wire.sh 6 $E/wire-repeat.log /tmp/n5_wire
echo CHAIN_DONE > $E/chain.done
