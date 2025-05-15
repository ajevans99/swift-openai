.PHONY: format lint

SWIFT_FORMAT_CONFIG = .swift-format.json

format:
	@swift-format --in-place Sources/ --recursive --parallel --configuration $(SWIFT_FORMAT_CONFIG)
	@echo "✅ Swift files formatted."

lint:
	@swift-format lint Sources/ --recursive --parallel --configuration $(SWIFT_FORMAT_CONFIG)
	@echo "✅ Swift files linted."
