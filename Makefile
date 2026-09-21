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

VERSION        ?= $(shell /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null)

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
# public distribution. Notarization reads App Store Connect API settings from
# the gitignored config/release.mk (see config/release.example.mk).
ifneq ($(filter notarize dist,$(MAKECMDGOALS)),)
include config/release.mk
endif

DEVID_IDENTITY := Developer ID Application: Gajeroll LLC (H9DPAP9M7B)
APPLE_TEAM_ID  ?= H9DPAP9M7B
DIST_ZIP       := $(DIST_DIR)/$(EXEC_NAME)-$(VERSION).zip

BUNDLE_VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print CFBundleVersion" Info.plist 2>/dev/null)

.PHONY: all compile compile-universal build release notarize dist run install uninstall clean test verify-release

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

verify-release:
	@test -n "$(VERSION)" || { echo "CFBundleShortVersionString is missing"; exit 1; }
	@echo "$(BUNDLE_VERSION)" | grep -Eq '^[0-9]+$$' || { echo "CFBundleVersion must be an integer"; exit 1; }
	@grep -q "## \[$(VERSION)\]" CHANGELOG.md || { echo "CHANGELOG.md has no ## [$(VERSION)] heading"; exit 1; }
	@echo "Release $(VERSION) (build $(BUNDLE_VERSION)) looks ready."

# Release build: Developer ID, Hardened Runtime, and secure timestamp
release: verify-release compile-universal
	@security find-identity -v -p codesigning | grep -qF "$(DEVID_IDENTITY)" \
	  || { echo "No signing identity matching \"$(DEVID_IDENTITY)\""; exit 1; }
	@codesign --force --options runtime --timestamp \
	  --sign "$(DEVID_IDENTITY)" "$(APP_DIR)"
	@echo "Release-signed \"$(APP_DIR)\" (identity: $(DEVID_IDENTITY))"

define require-notarize-config
	@test -n "$(ASC_KEY_ID)" || { echo "ASC_KEY_ID is not set. Copy config/release.example.mk to config/release.mk"; exit 1; }
	@test -n "$(ASC_ISSUER_ID)" || { echo "ASC_ISSUER_ID is not set"; exit 1; }
	@test -n "$(ASC_KEY_PATH)" || { echo "ASC_KEY_PATH is not set"; exit 1; }
	@test -f "$(ASC_KEY_PATH)" || { echo "ASC API key not found at the configured path"; exit 1; }
endef

# Notarize, staple the app, and create a distributable zip
notarize: release
	$(require-notarize-config)
	@mkdir -p "$(DIST_DIR)"
	/usr/bin/ditto -c -k --keepParent "$(APP_DIR)" "$(DIST_DIR)/submit.zip"
	@set -e; \
	out=$$(xcrun notarytool submit "$(DIST_DIR)/submit.zip" \
	  --key "$(ASC_KEY_PATH)" --key-id "$(ASC_KEY_ID)" --issuer "$(ASC_ISSUER_ID)" --wait); \
	echo "$$out"; \
	echo "$$out" | grep -q "status: Accepted" || { \
	  id=$$(echo "$$out" | awk '/id:/{print $$2; exit}'); \
	  if [ -n "$$id" ]; then \
	    xcrun notarytool log "$$id" --key "$(ASC_KEY_PATH)" --key-id "$(ASC_KEY_ID)" --issuer "$(ASC_ISSUER_ID)"; \
	  fi; \
	  exit 1; \
	}
	xcrun stapler staple "$(APP_DIR)"
	xcrun stapler validate "$(APP_DIR)"
	/usr/sbin/spctl --assess --type execute --verbose "$(APP_DIR)"
	codesign --verify --deep --strict "$(APP_DIR)"
	@codesign -dvv "$(APP_DIR)" 2>&1 | grep -q "TeamIdentifier=$(APPLE_TEAM_ID)" \
	  || { echo "TeamIdentifier is not $(APPLE_TEAM_ID)"; exit 1; }
	@archs=$$(lipo -archs "$(EXEC)"); \
	  echo "$$archs" | grep -q arm64 || { echo "missing arm64 ($$archs)"; exit 1; }; \
	  echo "$$archs" | grep -q x86_64 || { echo "missing x86_64 ($$archs)"; exit 1; }
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
