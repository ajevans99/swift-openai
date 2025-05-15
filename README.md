

`swift run swift-openapi-generator generate Sources/OpenAIModels/openapi.yaml --config Sources/OpenAIModels/openapi-generator-config.yaml`
`git diff Sources/OpenAIModels/openapi.yaml > Patches/01-fix-swift-integer-overflow.patch`
