# 12주차: 깃허브 액션 (GitHub Actions)

## 1. 개요 및 학습 목표
- CI와 CD의 차이, CI가 해결하려는 문제 설명
- workflow, trigger, job, step, runner 구조 이해
- 푸시 시 린트 → 테스트 → 빌드 → ghcr.io 게시 워크플로 이해
- 브랜치 보호 규칙으로 깨진 코드가 main에 합쳐지지 않게 하는 방법 이해

---

## 2. 주요 학습 내용 정리

### 🔄 CI / CD
- **CI (지속적 통합)**: 코드를 합칠 때마다 자동으로 검사·빌드하여 오류를 일찍 발견
  - CI 자체가 머지를 차단하지는 않음 → **브랜치 보호 규칙**과 함께 써야 차단 가능
- **CD - Delivery**: 언제든 배포 가능한 상태를 유지 (운영 반영에 승인 단계 포함 가능)
- **CD - Deployment**: 검증을 통과한 변경을 운영 환경까지 자동 반영
- **파이프라인**: 소스 가져오기 → 검사·테스트 → 이미지 빌드 → ghcr.io 푸시 (CI) → 쿠버네티스 배포 (CD)
- 앞 단계가 실패하면 뒤 단계는 진행하지 않음

### ⚙️ 깃허브 액션 구조
| 개념 | 의미 |
|---|---|
| workflow | `.github/workflows/*.yml` 파일 하나 |
| trigger (`on`) | 언제 실행할지 (push, pull_request, schedule, workflow_dispatch) |
| job | 새 서버에서 시작하는 작업 단위. 기본은 병렬 실행, `needs`로 순서 지정 |
| step | job 안의 한 단계 (`uses` 또는 `run`) |
| runner (`runs-on`) | 실제 실행 서버 (`ubuntu-latest`, 깃허브가 빌려줌) |

- 워크플로는 **언제(on) → 어디서(runs-on) → 무엇을(steps)** 순서로 읽음
- public 저장소는 표준 GitHub-hosted runner 무료 사용 가능
- `uses`: 남이 만든 액션 재사용 (예: `actions/checkout@v7`, `@v7`은 주 버전)
- `run`: 직접 쓴 명령 실행
- `with`: 액션에 넘기는 설정 값
- 외부 액션은 내 저장소 권한으로 실행되므로 믿을 만한 것만 사용
- `defaults.run.working-directory`는 `run` 단계에만 적용 (`uses`에는 미적용)
- `paths`: 해당 경로가 바뀐 푸시에만 실행
- `branches:` (복수형)으로 써야 유효함 (`branch:`는 오류)

### ✅ 종료 코드 (Exit Code)
- 단계의 성패는 **종료 코드**로만 판단 (화면 출력은 무관)
- `0` → 성공 (초록 ✓), `0 이외` → 실패 (빨간 X), 해당 단계에서 중단
- ruff, unittest, `curl -f` 등은 실패 시 0이 아닌 값을 반환하므로 CI에 사용 가능

### 🔑 `${{ }}` 표현식
| 표현식 | 의미 |
|---|---|
| `github.actor` | 실행을 일으킨 사람/봇 |
| `github.repository_owner` | 저장소 주인 아이디 |
| `github.event_name` | 실행 원인 (push, pull_request ...) |
| `github.ref` | 브랜치 (main 푸시: `refs/heads/main`, PR: `refs/pull/번호/merge`) |
| `secrets.GITHUB_TOKEN` | 실행마다 자동 발급되는 임시 토큰 (끝나면 만료) |
| `env.REGISTRY` | 상단 `env:`에 정의한 값 |
| `steps.meta.outputs.tags` | `id: meta` 단계의 결과 (태그 목록) |

- 구분: compose `${VAR}` / k8s `$(VAR)` / Actions `${{ }}`

### 🔍 문법 검사 / 린트 / 테스트
| | 문법 검사 | 린트 (ruff) | 테스트 (unittest) |
|---|---|---|---|
| 질문 | 파이썬이 읽을 수 있나? | 읽히지만 버그 가능성은? | 의도대로 동작하나? |
| 코드 실행 | X | X | O |
| 예시 | `def broken(:` | `print(APP_TITL)` | `/healthz`가 500 |
| 속도 | 아주 빠름 | 빠름 | 조금 느림 |

- 린트 명령: `ruff check . --select=E9,F`
  - E9: 문법 오류 / F: 정의 안 된 변수, 안 쓰는 import, 오타 등
- 비용이 적고 빠른 검사를 먼저 배치 → 실패를 일찍 발견
- 테스트 통과 ≠ 버그 없음 (검증한 조건만 보장)
- 테스트 파일은 `test_`로 시작해야 인식됨, `setUp`은 각 테스트 전에 실행
- `assertEqual(실제값, 기대값)`: 다르면 실패 (종료 코드 1)
- `test_client()`: 서버 실행 없이 요청을 보내는 가상 브라우저
- 글 등록 후 `302`: 첫 화면으로 되돌리는 redirect 응답
- `test_app.py`는 **무엇을 검사하는가**, `build.yml`은 **언제·어디서·어떻게 검사하는가**

### 🐳 이미지 빌드 & 태깅
- **QEMU**: 다른 CPU 아키텍처 명령 에뮬레이션 / **Buildx**: 멀티플랫폼 이미지 빌드
- `latest`는 계속 덮어써져 이전 버전 추적·롤백이 어려움
- **커밋 해시(`fe9db50`)** 나 버전(`v1.2`)으로 태그 → "이 이미지는 이 커밋으로 만들어졌다" 추적 가능
- `rollout undo`가 되려면 옛 이미지가 레지스트리에 남아 있어야 함
- 태그 규칙: `type=sha,format=short` (7글자), `type=raw,value=latest,enable={{is_default_branch}}`
- **PR에서는 푸시하지 않음**: 아직 main에 합쳐지지 않은 코드이므로 빌드만 확인
  - 푸시 조건: `github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`

### 🔐 ghcr.io와 권한
- `GITHUB_TOKEN`이 자동 발급되므로 별도 시크릿 불필요 (도커 허브는 토큰을 직접 등록해야 함)
- `permissions`는 필요한 것만 부여: `contents: read`, `packages: write`
- **403 오류**: 패키지에 저장소 쓰기 권한 없음 → Package settings → Manage Actions access → Add Repository → Role: Write

### 🛡️ 브랜치 보호
- 오류 있는 코드가 main에 합쳐지는 것 자체를 막는 설정
- **CI 검사 실패**와 **머지 차단**은 서로 다른 기능
- 설정 방법
  - Ruleset: Require a pull request before merging + Require status checks to pass (`build`)
  - Classic: 위와 동일 + Do not allow bypassing (관리자에게도 적용)
- 효과
  - main 직접 푸시 거부 (`push declined due to repository rule violations`)
  - 검사 실패 시 머지 버튼 비활성화
- **CI의 진짜 가치는 빌드 자체보다 main 브랜치를 지키는 것**
- `build` 검사가 검색되지 않으면 워크플로가 한 번도 실행되지 않은 것 → PR을 올린 뒤 확인
- 머지 후 태그는 **main에** 달기 (스쿼시 머지는 새 커밋을 만들기 때문)

### 📜 로그 읽는 방법
- **맨 아래에서 위로** 올라가며 첫 번째 오류 줄 찾기
- 파일명:줄:칸 확인 (예: `app.py:95:11`)
- 3단계: 결과(exit code 1) → 어디서(파일:줄) → 원인(F821 Undefined name)

### 🧰 자주 쓰는 명령
| 명령 | 역할 |
|---|---|
| `gh run list --limit 5` | 최근 실행 5개 보기 |
| `gh run watch` | 진행 중인 실행 실시간 표시 |
| `gh run view --log-failed` | 실패한 단계의 로그만 출력 |
| `gh run rerun --failed` | 실패한 job만 재실행 |
| `gh workflow run build.yml --ref main` | `workflow_dispatch` 수동 실행 |
| `gh pr checks --watch` | PR 검사 상태 실시간 확인 |
