.PHONY: ui-check

# AppleAppLabUI compila y pasa tests en macOS y compila para iOS (AAL-BUILD-001)
ui-check:
	cd Packages/AppleAppLabUI && swift build && swift test
	cd Packages/AppleAppLabUI && xcodebuild -scheme AppleAppLabUI -destination 'generic/platform=iOS Simulator' -quiet build
