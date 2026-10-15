extends RefCounted
## 연출 길이(초) 상수 한 곳. 스토리보드가 길이를 정하지 않아 구현하며 정한 값이라 사람이 보고 고친다.

const DEAL_STEP := 0.07        # 나눠 주기: 카드 한 장과 다음 장 사이
const DEAL_FLY := 0.30         # 나눠 주기: 카드 한 장이 날아가는 시간
const DEAL_FLIP := 0.22        # 나눠 주기 끝: 첫 카드 뒤집기
const DRAW_STEP := 0.12        # 공격으로 받는 카드 사이
const DRAW_FLY := 0.35         # 공격으로 받는 카드 한 장이 날아오는 시간
const STAMP_POP := 0.20        # 큰 글자가 찍히는 시간
const STAMP_HOLD := 0.90       # 큰 글자가 머무는 시간
const BANNER_HOLD := 1.30      # 안내 문구가 머무는 시간
const SHAKE := 0.55            # 맞은 아바타가 빨갛게 흔들리는 시간
const SKIP_HOLD := 1.20        # 금지 도장이 머무는 시간
const REVERSE_HOLD := 0.60     # 방향 고리가 노랗게 머무는 시간
const REVERSE_BACK := 0.40     # 노랑에서 원래 색으로 돌아오는 시간
const HANJANG_WINDOW := 3.0    # 한장! 창이 열려 있는 시간. 세션 스냅샷의 turn_time이 있으면 그 값을 쓴다
const CALL_HOLD := 1.40        # "1장 남음!" 문구가 머무는 시간
const CATCH_HOLD := 1.60       # "잡았다!" 문구가 머무는 시간
