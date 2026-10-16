#!/bin/sh
# 신원 시험 (n4): 방 비밀값, 재접속 토큰, 이름 규칙, 서버 로그에 닉네임이 없음.
# 판 1: 방 비밀값이 틀리면 거절. 같은 닉네임을 다른 브라우저(토큰 다름)가 쓰면 거절되고, 원래 브라우저는 자리로 돌아간다.
# 판 2: 아직 안 끊긴 옛 접속이 있어도 같은 토큰의 새 접속이 자리를 넘겨받는다(FIN 없는 끊김 대비).
# 판 3: 로비에서 빈 이름·이모지·금지어·9자 닉네임이 이유 문구와 함께 거절된다.
# 포트: 첫 인자 또는 NET_TEST_PORT (기본 7820). 헤드리스 Godot는 /tmp/hanjang-headless.lock 을 잡고 하나씩 돌린다.
cd "$(dirname "$0")/../.." || exit 1
if [ -z "$HJ_LOCKED" ]; then HJ_LOCKED=1 exec python3 game/tests/headless_lock.py ${HJ_LIMIT:-240} sh "game/tests/test_trust.sh" "$@"; fi
GODOT=engine/Godot.app/Contents/MacOS/Godot
P0=${1:-${NET_TEST_PORT:-7820}}
P=$P0
L=$(mktemp -d)
fail=0
run() { n=$1; shift; $GODOT --headless --path game -- --port=$P --seed=7 --turn-time=2 --hj-time=0.6 --quit-after=${QUIT:-25} --token-file=$L/tok_$n "$@" > "$L/$n.log" 2>&1 & }
chk() { if ! grep -q -- "$2" "$L/$1.log"; then echo "FAIL: $1 에 '$2' 없음"; fail=1; fi; }
waitlog() { i=0; while ! grep -q -- "$2" "$L/$1.log" 2>/dev/null; do i=$((i+1)); [ $i -gt 75 ] && { echo "FAIL: $1 에 '$2' 가 15초 안에 안 나옴"; fail=1; return 1; }; sleep 0.2; done; }

echo "== 판 1: 비밀값, 닉네임 도용 거절, 원래 브라우저 복귀 =="
run srv --dedicated --code=ABCD --secret=S3CRET --public=0
waitlog srv "^HOST_READY dedicated"
run a --join=127.0.0.1 --name=하늘 --secret=S3CRET --autoplay --try-start=3
waitlog srv "^SEATED 1"
run b --join=127.0.0.1 --name=구름 --secret=S3CRET --autoplay
waitlog srv "^SEATED 2"
run c --join=127.0.0.1 --name=민트 --secret=S3CRET --autoplay --leave-after=4.5
waitlog srv "^SEATED 3"
run bad --join=127.0.0.1 --name=낯선이 --secret=WRONG
waitlog bad "JOIN_FAILED"
waitlog srv "^PEER_LEFT_IN_GAME"
run thief --join=127.0.0.1 --name=민트 --secret=S3CRET
waitlog thief "JOIN_FAILED"
run c2 --join=127.0.0.1 --name=민트 --secret=S3CRET --autoplay --token-file=$L/tok_c
waitlog c2 "^REJOINED_OK"
wait
chk bad "JOIN_FAILED 방을 못 찾았어요"
chk thief "JOIN_FAILED 이미 쓰는 이름이에요"
chk c2 "^REJOINED_OK"
chk srv "^REJOINED .* seat=2"
S1=$(grep "^MYHAND" "$L/c.log" | head -1 | awk '{print $2}'); S2=$(grep "^MYHAND" "$L/c2.log" | head -1 | awk '{print $2}')
[ -n "$S1" ] && [ "$S1" = "$S2" ] || { echo "FAIL: 복귀 자리가 다름($S1 / $S2)"; fail=1; }
if grep -E "하늘|구름|민트|낯선이" "$L/srv.log" | grep -q .; then echo "FAIL: 방 프로세스 로그에 닉네임"; grep -E "하늘|구름|민트|낯선이" "$L/srv.log" | head -3; fail=1; fi
chk srv "^SEATED 1"

echo "== 판 2: 안 끊긴 옛 접속이 있어도 같은 토큰이 자리를 넘겨받는다 =="
P=$((P0+1))
run s2 --dedicated --code=EFGH
waitlog s2 "^HOST_READY dedicated"
run p --join=127.0.0.1 --name=하늘 --autoplay --try-start=3
waitlog s2 "^SEATED 1"
run q --join=127.0.0.1 --name=구름 --autoplay
waitlog s2 "^SEATED 2"
run r --join=127.0.0.1 --name=민트 --autoplay
waitlog s2 "^SEATED 3"
waitlog s2 "^START_OK"
run r2 --join=127.0.0.1 --name=민트 --autoplay --token-file=$L/tok_r
waitlog r2 "^REJOINED_OK"
wait
chk s2 "^REJOINED .* seat=2"
chk r "^LEFT_TO_TITLE"
chk r2 "^MYHAND seat=2"

echo "== 판 3: 이름 규칙 =="
P=$((P0+2))
run s3 --dedicated --code=IJKL
waitlog s3 "^HOST_READY dedicated"
i=0
for spec in "emoji:🙂곰:이모지는 쓸 수 없어요" "bad:시발이:쓸 수 없는 말이 들어 있어요" "long:아홉글자닉네임입니다:8자까지 쓸 수 있어요" "ok:여덟글자닉네임:"; do
  n=n$i; i=$((i+1))
  nick=$(echo "$spec" | cut -d: -f2); want=$(echo "$spec" | cut -d: -f3)
  run $n --join=127.0.0.1 --name="$nick" --skip-name-check --quit-after=6
  if [ -n "$want" ]; then waitlog $n "JOIN_FAILED"; chk $n "JOIN_FAILED $want"; else waitlog $n "^JOINED"; fi
done
wait
if grep -q "곰\|시발이\|아홉글자\|여덟글자" "$L/s3.log"; then echo "FAIL: 서버 로그에 입력한 이름"; fail=1; fi

[ $fail = 0 ] && echo "NET_TRUST_TEST_PASS" && exit 0
echo "NET_TRUST_TEST_FAIL (logs: $L)"; exit 1
