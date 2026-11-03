APP_NAME = EdgeBar
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

.PHONY: all app run test clean build settings install

all: app

build:
	@echo "==> Building EdgeBar (Release mode)..."
	@swift build -c release

app: build
	@echo "==> Packaging macOS App Bundle at $(APP_BUNDLE)..."
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	@cp -f .build/release/$(APP_NAME) $(MACOS_DIR)/$(APP_NAME)
	@chmod +x $(MACOS_DIR)/$(APP_NAME)
	@cp -f Resources/Info.plist $(CONTENTS_DIR)/Info.plist
	@cp -f Resources/*.icns $(RESOURCES_DIR)/ 2>/dev/null || true
	@cp -f Resources/walkthrough.html $(RESOURCES_DIR)/walkthrough.html 2>/dev/null || true
	@xattr -cr $(APP_BUNDLE) 2>/dev/null || true
	@echo "==> Code-signing application bundle..."
	@codesign --force --deep --sign - --identifier "io.github.edgebar" -r='designated => identifier "io.github.edgebar"' $(APP_BUNDLE)
	@echo "==> App bundle successfully created at: $(APP_BUNDLE)"

run: app
	@echo "==> Launching $(APP_NAME)..."
	@open $(APP_BUNDLE)

settings: app
	@echo "==> Opening $(APP_NAME) Settings..."
	@open $(APP_BUNDLE) --args --settings

install: app
	@echo "==> Installing EdgeBar to /Applications/EdgeBar.app..."
	@rm -rf /Applications/EdgeBar.app
	@cp -R $(APP_BUNDLE) /Applications/EdgeBar.app
	@echo "==> EdgeBar installed! Available in Launchpad and Spotlight."

test:
	@echo "==> Running EdgeBar gesture state machine unit tests..."
	@swift test

clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf .build
