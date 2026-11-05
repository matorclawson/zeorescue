# zeo-rescue: the org's recovery path. Nothing here runs until someone asks. See RUNBOOK.md.
SHELL := /bin/bash
RESCUER ?= claude
ARGS ?=
STATE ?= $(HOME)/.local/state/zeo-rescue
STAMP := $(shell date +%Y%m%d-%H%M%S)

.PHONY: help plan rescue reseat-plan reseat check agent test teardown-log doctor test-rescuer records records-status records-service records-install test-records

help:
	@echo "make plan                  what would be resumed; starts nothing"
	@echo "make rescue                resume every dead seat on this host, each from its own record"
	@echo "make reseat-plan           which live seats were started the wrong way; starts nothing"
	@echo "make reseat                restart those seats the right way, and stop the shared Codex daemon"
	@echo "make check                 judge every seat: its own identity, not on the daemon"
	@echo "make teardown-log          write the system log around a crash to a file this seat can read"
	@echo "make agent RESCUER=codex|claude  start the chosen rescuer on its own socket"
	@echo "make test                  current offline acceptance suites"
	@echo "ARGS='...' limits any of them; see rescue.sh for the flags. Output of rescue and reseat is also kept in $(STATE)."
	@echo "make doctor                inspect capabilities; ARGS=--json gives structured output"
	@echo "make test-rescuer          offline dual-harness bootstrap tests"
	@echo "make records               capture exact recovery records without a harness"
	@echo "make records-status        inspect saved records and capture issues"
	@echo "make records-service       generate the automatic collector launchd job"
	@echo "make records-health        is the saved cache fresh enough to recover from; ARGS=SECONDS sets the limit"

records:
	@./records.sh capture

records-install:
	@./records.sh install

records-status:
	@./records.sh status

records-health:
	@./records.sh health $(ARGS)

records-service:
	@./records.sh service

test-records:
	@bash ./records-test.sh

plan:
	@./rescue.sh $(ARGS)

rescue:
	@mkdir -p "$(STATE)"; set -o pipefail; ./rescue.sh --apply $(ARGS) 2>&1 | tee "$(STATE)/rescue-$(STAMP).log"

reseat-plan:
	@./rescue.sh --reseat $(ARGS)

reseat:
	@mkdir -p "$(STATE)"; set -o pipefail; ./rescue.sh --reseat --apply $(ARGS) 2>&1 | tee "$(STATE)/reseat-$(STAMP).log"

check:
	@./rescue.sh --check $(ARGS)

teardown-log:
	@./teardown-log.sh $(ARGS)

agent:
	@./agent.sh --harness "$(RESCUER)" $(ARGS)

doctor:
	@./doctor.sh $(ARGS)

test-rescuer:
	@bash ./rescuer-test.sh

test:
	@bash ./rescuer-test.sh
	@bash ./records-test.sh
	@bash ./guard-test.sh
	@bash ./tmux-test.sh
