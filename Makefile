PRODUCT        := Command Input
EXEC_NAME      := CommandInput
BUNDLE         := $(PRODUCT).app
BUILD_DIR      := build
DIST_DIR       := dist
APP_DIR        := $(BUILD_DIR)/$(BUNDLE)
CONTENTS_DIR   := $(APP_DIR)/Contents
MACOS_DIR      := $(CONTENTS_DIR)/MacOS
EXEC           := $(MACOS_DIR)/$(EXEC_NAME)
INSTALL_DIR    := /Applications

SOURCES        := $(wildcard Sources/*/*.swift)
DEPLOY_TARGET  := 14.0
HOST_ARCH      := $(shell uname -m)
SWIFTFLAGS     := -O -swift-version 6 -parse-as-library \
                  -framework Cocoa -framework ServiceManagement

VERSION        := $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null)

# --- Development signing ---------------------------------------------------
# Prefer an Apple Development identity so TCC and ServiceManagement see a stable
# Team ID across rebuilds. Ad-hoc signing remains a local-only fallback and cannot
# register a login item. The first match wins, so pass SIGN_IDENTITY explicitly
# when the keychain holds identities from more than one team. "build" reports the
# identity it used.
DEV_SIGNING_IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null \
                          | /usr/bin/awk -F '"' '/Apple Development:/{print $$2; exit}')
SIGN_IDENTITY        ?= $(if $(DEV_SIGNING_IDENTITY),$(DEV_SIGNING_IDENTITY),-)

# --- Release signing and notarization --------------------------------------
# Developer ID signing, Hardened Runtime, and notarization are required for
# public distribution. Create the notarytool keychain profile first.
DEVID_IDENTITY ?= Developer ID Application
NOTARY_PROFILE ?= CommandInputNotary
DIST_ZIP       := $(DIST_DIR)/$(EXEC_NAME)-$(VERSION).zip

.PHONY: all compile compile-universal build release notarize dist run install uninstall clean test

all: build

RESOURCES_DIR  := $(CONTENTS_DIR)/Resources

compile:
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	@cp Info.plist "$(CONTENTS_DIR)/Info.plist"
	@cp PrivacyInfo.xcprivacy "$(RESOURCES_DIR)/PrivacyInfo.xcprivacy"
	swiftc $(SWIFTFLAGS) -target $(HOST_ARCH)-apple-macos$(DEPLOY_TARGET) \
	  -o "$(EXEC)" $(SOURCES)

compile-universal:
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	@cp Info.plist "$(CONTENTS_DIR)/Info.plist"
	@cp PrivacyInfo.xcprivacy "$(RESOURCES_DIR)/PrivacyInfo.xcprivacy"
	swiftc $(SWIFTFLAGS) -target arm64-apple-macos$(DEPLOY_TARGET) \
	  -o "$(EXEC)-arm64" $(SOURCES)
	swiftc $(SWIFTFLAGS) -target x86_64-apple-macos$(DEPLOY_TARGET) \
	  -o "$(EXEC)-x86_64" $(SOURCES)
	lipo -create -output "$(EXEC)" "$(EXEC)-arm64" "$(EXEC)-x86_64"
	@rm -f "$(EXEC)-arm64" "$(EXEC)-x86_64"

# Default development build
build: compile
	@codesign --force --sign "$(SIGN_IDENTITY)" "$(APP_DIR)"
	@echo "Built \"$(APP_DIR)\" (signed: $(SIGN_IDENTITY))"

# Release build: Developer ID, Hardened Runtime, and secure timestamp
release: compile-universal
	@codesign --force --options runtime --timestamp \
	  --sign "$(DEVID_IDENTITY)" "$(APP_DIR)"
	@echo "Release-signed \"$(APP_DIR)\" (identity: $(DEVID_IDENTITY))"

# Notarize, staple the app, and create a distributable zip
notarize: release
	@mkdir -p "$(DIST_DIR)"
	/usr/bin/ditto -c -k --keepParent "$(APP_DIR)" "$(DIST_DIR)/submit.zip"
	xcrun notarytool submit "$(DIST_DIR)/submit.zip" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(APP_DIR)"
	@rm -f "$(DIST_DIR)/submit.zip"
	/usr/bin/ditto -c -k --keepParent "$(APP_DIR)" "$(DIST_ZIP)"
	@echo "Notarized + stapled. Distributable: \"$(DIST_ZIP)\""

# Alias for a notarized distribution artifact
dist: notarize

run: build
	@"$(EXEC)"

install: build
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE)"
	@cp -R "$(APP_DIR)" "$(INSTALL_DIR)/"
	@echo "Installed to \"$(INSTALL_DIR)/$(BUNDLE)\""

uninstall:
	@rm -rf "$(INSTALL_DIR)/$(BUNDLE)"
	@echo "Removed \"$(INSTALL_DIR)/$(BUNDLE)\""

test:
	swift test

clean:
	@rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
	@echo "Cleaned $(BUILD_DIR) $(DIST_DIR)"
