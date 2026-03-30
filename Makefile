APP_NAME = TapLauncher
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources

.PHONY: build bundle clean install run

build:
	swift build -c release

bundle: build
	@echo "Creating $(APP_BUNDLE)..."
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(MACOS)
	@mkdir -p $(RESOURCES)
	@cp $(BUILD_DIR)/$(APP_NAME) $(MACOS)/$(APP_NAME)
	@cp Info.plist $(CONTENTS)/Info.plist
	@cp -r Sources/TapLauncher/Resources/audio $(RESOURCES)/audio
	@echo "Built $(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)

install: bundle
	@echo "Installing to /Applications..."
	@sudo cp -r $(APP_BUNDLE) /Applications/$(APP_BUNDLE)
	@echo "Installed to /Applications/$(APP_BUNDLE)"

run: bundle
	sudo $(MACOS)/$(APP_NAME)
