# aitutor — single task-runner interface (see docs/execution-plan.md §2, §7)
SHELL := /bin/bash
TARGET ?= com.apple.TextEdit
SECONDS ?= 60
MENU ?= File>Export as PDF…
SAVE ?= /tmp/aitutor-spike-out
ACTION_SECONDS ?= 20
RUNS ?= 50

.PHONY: bootstrap check lint typecheck test shell-build shell-test shell-app shell-run \
        shell-smoke fakeshell core-dev demo spike-ax spike-ax-run spike-snapshot spike-snapshot-run \
        spike-verdict-test journal-dump cert reset-tcc clean

bootstrap: ## one-time setup: pnpm install + env file
	corepack enable
	pnpm install
	@test -f core/.env || cp core/.env.example core/.env
	@echo "bootstrap done — see 'make cert' before first 'make shell-run'"

check: lint typecheck test spike-verdict-test shell-build shell-test ## every quality gate

lint:
	pnpm exec biome check .

typecheck:
	pnpm -r typecheck

test:
	pnpm -r test

shell-build:
	swift build --package-path shell

shell-test:
	swift test --package-path shell

shell-app: shell-build ## assemble + sign build/Tutor.app
	bash shell/Scripts/make-app.sh

shell-run: shell-app ## launch the menu-bar app
	open shell/build/Tutor.app

shell-smoke: ## zero-dep smoke client against the running shell
	node shell/Scripts/smoke.mjs

fakeshell: ## terminal 1: ws server standing in for the Swift shell
	pnpm --filter @aitutor/core fakeshell

core-dev: ## terminal 2: agent-core connects, handshakes, draws, gets REFUSED
	pnpm --filter @aitutor/core dev

demo: ## one-shot in-process fake-shell round-trip (CI smoke)
	pnpm --filter @aitutor/core demo

spike-ax: ## AXObserver density probe: make spike-ax TARGET=com.apple.TextEdit SECONDS=60
	swift run --package-path shell axprobe --bundle-id $(TARGET) --seconds $(SECONDS)

spike-verdict-test: ## density-verdict classifier tests (no TCC, no target app — CI-safe)
	node --test 'shell/Scripts/*.test.mjs'

spike-ax-run: ## per-action density: TARGET=<bundle-id> + ACTIONS=<file> (interactive) or DRIVERS=<dir> (headless)
	shell/Scripts/ax-density-run.sh --bundle-id $(TARGET) $(if $(DRIVERS),--drivers $(DRIVERS),--actions $(ACTIONS)) --seconds $(ACTION_SECONDS)

spike-snapshot-run: ## ritual reliability loop: make spike-snapshot-run TARGET=<bundle-id> MENU="File>…" [RUNS=50]
	shell/Scripts/snapshot-ritual-run.sh --bundle-id $(TARGET) --menu "$(MENU)" --runs $(RUNS)

spike-snapshot: ## menu-drive export rehearsal: make spike-snapshot TARGET=... MENU="File>Export as PDF…"
	swift run --package-path shell snapshot-spike --bundle-id $(TARGET) --menu-path "$(MENU)" --save-to $(SAVE)

journal-dump: ## print hash-chained journal rows from the last core-dev session
	pnpm --filter @aitutor/core journal-dump

cert: ## print the one-time dev signing certificate recipe
	@echo "One-time dev signing setup (keeps TCC grants stable across rebuilds):"
	@echo "  1. Keychain Access → Certificate Assistant → Create a Certificate…"
	@echo "     Name: 'TutorShell Dev'   Identity Type: Self-Signed Root   Certificate Type: Code Signing"
	@echo "  2. In Keychain Access, set the new certificate to Always Trust (Get Info → Trust)."
	@echo "  3. Verify:  security find-identity -v -p codesigning   should list 'TutorShell Dev'"
	@echo "Ad-hoc fallback works but TCC grants will NOT survive rebuilds (make-app.sh warns loudly)."

reset-tcc: ## reset the shell's TCC grants when they wedge
	-tccutil reset Accessibility com.aitutor.shell
	-tccutil reset ScreenCapture com.aitutor.shell
	-tccutil reset ListenEvent com.aitutor.shell
	-tccutil reset Microphone com.aitutor.shell

clean:
	rm -rf shell/.build shell/build core/.data
	pnpm -r exec rm -rf node_modules 2>/dev/null || true
