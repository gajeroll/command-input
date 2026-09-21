# Copy to config/release.mk (gitignored) and fill in local values.
# The .p8 itself stays outside the repository.

APPLE_TEAM_ID := H9DPAP9M7B

ASC_KEY_ID := YOUR_KEY_ID
ASC_ISSUER_ID := YOUR_ISSUER_ID
ASC_KEY_PATH := $(HOME)/.appstoreconnect/private_keys/AuthKey_$(ASC_KEY_ID).p8
