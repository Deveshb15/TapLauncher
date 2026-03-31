APP_NAME = TapLauncher
VERSION ?= 1.0.0
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources
DMG_NAME = $(APP_NAME)-$(VERSION).dmg
DMG_STAGING = .dmg-staging

.PHONY: build bundle clean install run dmg release

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

dmg: bundle
	@echo "Creating $(DMG_NAME)..."
	@rm -rf $(DMG_STAGING) $(DMG_NAME)
	@mkdir -p $(DMG_STAGING)
	@cp -r $(APP_BUNDLE) $(DMG_STAGING)/
	@ln -s /Applications $(DMG_STAGING)/Applications
	@hdiutil create -volname "$(APP_NAME)" -srcfolder $(DMG_STAGING) -ov -format UDZO $(DMG_NAME)
	@rm -rf $(DMG_STAGING)
	@echo "Created $(DMG_NAME)"

release: dmg
	gh release create "v$(VERSION)" --title "$(APP_NAME) v$(VERSION)" --generate-notes $(DMG_NAME)

clean:
	swift package clean
	rm -rf $(APP_BUNDLE) $(DMG_STAGING) *.dmg

install: bundle
	@echo "Installing to /Applications..."
	@sudo cp -r $(APP_BUNDLE) /Applications/$(APP_BUNDLE)
	@echo "Installed to /Applications/$(APP_BUNDLE)"

run: bundle
	sudo $(MACOS)/$(APP_NAME)
