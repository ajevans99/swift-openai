.PHONY: format lint fetch patches generated-patches generate build test test-live-snapshots record-snapshots all clean check

GIT_ROOT := $(shell git rev-parse --show-toplevel)

# Paths
SPEC_DIR         := $(GIT_ROOT)/Sources/OpenAIFoundation
SPEC_FILE        := $(SPEC_DIR)/openapi.yaml
SPEC_COMMIT_FILE := $(SPEC_DIR)/openapi.commit
GENERATED_DIR    := $(SPEC_DIR)/Generated

# Scripts
FETCH_SCRIPT   := $(GIT_ROOT)/Scripts/fetch-openapi.sh
APPLY_SCRIPT   := $(GIT_ROOT)/Scripts/apply-patches.sh
GENERATED_PATCH_SCRIPT := $(GIT_ROOT)/Scripts/apply-generated-patches.sh
GENERATE_SCRIPT:= $(GIT_ROOT)/Scripts/generate-models.sh
CHECK_SCRIPT   := $(GIT_ROOT)/Scripts/check-openapi-up-to-date.sh
RECORD_SNAPSHOTS_SCRIPT := $(GIT_ROOT)/Scripts/record-response-snapshots.sh

SWIFT_FORMAT_CONFIG = .swift-format.json

check:
	@echo "▶ check-openapi-up-to-date"
	@bash $(CHECK_SCRIPT)

fetch:
	@echo "▶ fetch-openapi"
	@bash $(FETCH_SCRIPT)

patches:
	@echo "▶ apply-patches"
	@bash $(APPLY_SCRIPT)

generated-patches:
	@echo "▶ apply-generated-patches"
	@bash $(GENERATED_PATCH_SCRIPT)

generate: patches
	@echo "▶ generate-models"
	@bash $(GENERATE_SCRIPT)

build:
	@echo "▶ swift-build"
	@swift build

test:
	@echo "▶ swift-test"
	@swift test

test-live-snapshots:
	@echo "▶ swift-test (live snapshot smoke)"
	@OPENAI_LIVE_SNAPSHOT=1 swift test

record-snapshots:
	@echo "▶ record-response-snapshots"
	@bash $(RECORD_SNAPSHOTS_SCRIPT)

all: fetch generate build
	@echo "✅ All done."

clean:
	@rm -rf $(GENERATED_DIR)
	@rm -f $(SPEC_FILE)
	@rm -f $(SPEC_COMMIT_FILE)

format:
	@swift-format --in-place Sources/ Tests/ Example/Sources/ --recursive --parallel --configuration $(SWIFT_FORMAT_CONFIG)
	@echo "✅ Swift files formatted."

lint:
	@swift-format lint Sources/ Tests/ Example/Sources/ --recursive --parallel --configuration $(SWIFT_FORMAT_CONFIG)
	@echo "✅ Swift files linted."
