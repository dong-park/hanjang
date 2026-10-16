# 한장! 서버 배포 (이 맥 + 임시 터널)

이 맥이 서버(D2=C)이고 주소는 trycloudflare 임시 주소(D3=C)다. 사용자 LaunchAgent만 쓰며 sudo는 필요 없다.

## 사용

```
relay/deploy/hanjang.sh print      # plist 미리 보기 (아무것도 바꾸지 않음)
relay/deploy/hanjang.sh install    # 서비스 2개 설치·시작, 주소 출력 (재실행해도 같은 결과)
relay/deploy/hanjang.sh url        # 현재 주소: https://xxxx.trycloudflare.com, wss://xxxx.trycloudflare.com/ws/<방코드>
relay/deploy/hanjang.sh status     # launchctl list에 com.hanjang.relay / com.hanjang.tunnel
relay/deploy/hanjang.sh restart    # 관리 서비스만 재시작
relay/deploy/hanjang.sh uninstall
```

- com.hanjang.relay: python3 relay/manager.py 8070. KeepAlive라 죽으면 3초 뒤 다시 뜬다. 로그인하면 자동 시작(RunAtLoad).
- com.hanjang.tunnel: cloudflared tunnel --config /dev/null --url http://127.0.0.1:8070. 터널은 이 한 포트만 연다.
- 로그: ~/Library/Logs/hanjang/{relay,tunnel}.log
- 방 링크는 접속한 Host 기준으로 만들어지므로 주소가 바뀌어도 설정은 필요 없다. 고정하려면 HANJANG_PUBLIC_BASE를 plist에 넣는다.

## 주의

- 임시 주소는 터널이 다시 뜰 때마다 바뀐다(맥 재부팅, 터널 재시작). 바뀌면 `url`로 새 주소를 확인한다. 이름 있는 터널과 도메인은 나중 결정이다.
- 잠자기: plist가 서비스 실행을 caffeinate -i로 감싸 유휴 잠자기를 막는다. 덮개를 닫거나 전원 버튼으로 재우면 서버가 선다. 서버로 쓸 때는 전원 연결 + 시스템 설정 > 배터리/에너지에서 「디스플레이가 꺼져도 잠자지 않기」를 켠다.
- 재시작(T15): 서비스가 재시작되면 방 프로세스도 같이 내려가 방이 사라지고, 접속은 끊긴다. launchd가 3초 안에 다시 띄워 새 방을 받는다. 「서버가 다시 시작했어요」 문구는 클라이언트(game/, n6)가 예상 밖 끊김 뒤 보여 주는 쪽이며 이 배포 파일에는 없다.
- T18의 systemd는 launchd로 읽는다. 재부팅 뒤 자동 시작은 로그인(자동 로그인 설정)이 필요하다.
