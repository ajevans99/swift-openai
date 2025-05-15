.PHONY: format lint fetch patches generate all clean check

GIT_ROOT := $(shell git rev-parse --show-toplevel)

# Paths
SPEC_DIR         := $(GIT_ROOT)/Sources/OpenAIModels
SPEC_FILE        := $(SPEC_DIR)/openapi.yaml
SPEC_COMMIT_FILE := $(SPEC_DIR)/openapi.commit
GENERATED_DIR    := $(SPEC_DIR)/Generated

# Scripts
FETCH_SCRIPT   := $(GIT_ROOT)/Scripts/fetch-openapi.sh
APPLY_SCRIPT   := $(GIT_ROOT)/Scripts/apply-patches.sh
GENERATE_SCRIPT:= $(GIT_ROOT)/Scripts/generate-models.sh
CHECK_SCRIPT   := $(GIT_ROOT)/Scripts/check-openapi-up-to-date.sh

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

generate:
	@echo "▶ generate-models"
	@bash $(GENERATE_SCRIPT)

all: fetch patches generate
	@echo "✅ All done."

clean:
	@rm -rf $(GENERATED_DIR)
	@rm -f $(SPEC_FILE)
	@rm -f $(SPEC_COMMIT_FILE)

format:
	@swift-format --in-place Sources/ --recursive --parallel --configuration $(SWIFT_FORMAT_CONFIG)
	@echo "✅ Swift files formatted."

lint:
	@swift-format lint Sources/ --recursive --parallel --configuration $(SWIFT_FORMAT_CONFIG)
	@echo "✅ Swift files linted."
