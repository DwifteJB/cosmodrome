# macos development identity
-include .env
export

APP_PATH=./build/macos/Build/Products/Release/cosmodrome.app
RPC_ENTITLEMENTS=./macos/cosmodrome-rpc.entitlements
MACOS_PROFILE=./secrets/macbook_cosmodrome_profile.provisionprofile
IOS_APP_PATH=./build/ios/iphoneos/Runner.app
IOS_IPA_DIR=./build/ios/ipa
IOS_RUNNER_BIN=$(IOS_APP_PATH)/Runner
IOS_TROLLSTORE_ENTITLEMENTS?=./ios/Runner/Runner.entitlements

linux-and-android:
	DOCKER_BUILDKIT=1 docker build --target export --output ./output .

macos-local:
	rm -rf ./output
	flutter pub get
	flutter build macos --release

	find "$(APP_PATH)" \( -name "._*" -o -name "*.cstemp" \) -delete

	# build universal cosmodrome-rpc binary
	cd ./discord-rpc && GOARCH=amd64 GOOS=darwin go build -o cosmodrome-rpc-amd64 main.go
	cd ./discord-rpc && GOARCH=arm64 GOOS=darwin go build -o cosmodrome-rpc-arm64 main.go
	lipo -create -output ./discord-rpc/cosmodrome-rpc \
		./discord-rpc/cosmodrome-rpc-amd64 \
		./discord-rpc/cosmodrome-rpc-arm64
	rm ./discord-rpc/cosmodrome-rpc-amd64 ./discord-rpc/cosmodrome-rpc-arm64

	# place binary inside app bundle
	cp ./discord-rpc/cosmodrome-rpc \
		"$(APP_PATH)/Contents/Resources/cosmodrome-rpc"

	rm ./discord-rpc/cosmodrome-rpc

	# embed provisioning profile required for restricted entitlements (keychain-access-groups)
	cp "$(MACOS_PROFILE)" "$(APP_PATH)/Contents/embedded.provisionprofile"

	# re-sign all frameworks with Developer ID + secure timestamp
	# flutter build signs them with "Apple Development" which notarization rejects
	find "$(APP_PATH)/Contents/Frameworks" -maxdepth 1 \
		\( -name "*.framework" -o -name "*.dylib" \) | \
		while read f; do \
			find "$$f" \( -name "._*" -o -name "*.cstemp" \) -delete; \
			codesign --sign "$(IDENTITY)" \
				--options runtime --timestamp --force "$$f"; \
		done

	# sign the rpc helper with inherit entitlement so sandbox allows it
	codesign --sign "$(IDENTITY)" \
		--entitlements "$(RPC_ENTITLEMENTS)" \
		--options runtime --timestamp --force \
		"$(APP_PATH)/Contents/Resources/cosmodrome-rpc"

	# re-sign the main executable (flutter signs it with Apple Development; must match outer identity)
	codesign --sign "$(IDENTITY)" \
		--entitlements ./macos/Runner/Release.entitlements \
		--options runtime --timestamp --force \
		"$(APP_PATH)/Contents/MacOS/cosmodrome"

	# re-sign the app bundle to update its CodeResources manifest (no --deep)
	codesign --sign "$(IDENTITY)" \
		--entitlements ./macos/Runner/Release.entitlements \
		--options runtime --timestamp --force \
		"$(APP_PATH)"

	# fail early if the seal is broken
	codesign --verify --deep --strict --verbose=2 "$(APP_PATH)"

	# output to app-unnotarized.zip for testing without notarization step
	mkdir -p ./output
	ditto -c -k --keepParent --norsrc --noextattr --noqtn "$(APP_PATH)" ./output/app-unnotarized.zip

	@echo "Build complete: $(APP_PATH)"#


macos-notarize:
	# zip the app for submission (ditto preserves xattrs/symlinks better than zip)
	ditto -c -k --keepParent "$(APP_PATH)" ./cosmodrome-notarize.zip

	# submit to Apple notarization and wait for result
	xcrun notarytool submit ./cosmodrome-notarize.zip \
		--apple-id "$(APPLE_EMAIL)" \
		--password "$(APPLE_PASSWORD)" \
		--team-id "$(TEAM_ID)" \
		--wait 2>&1 | tee /tmp/notarytool-submit.log; \
	SUBMISSION_ID=$$(grep -o 'id: [a-f0-9-]*' /tmp/notarytool-submit.log | head -1 | cut -d' ' -f2); \
	STATUS=$$(grep 'status:' /tmp/notarytool-submit.log | tail -1); \
	echo "$$STATUS"; \
	if echo "$$STATUS" | grep -q "Invalid\|Rejected"; then \
		echo "Notarization rejected — fetching log for submission $$SUBMISSION_ID:"; \
		xcrun notarytool log "$$SUBMISSION_ID" \
			--apple-id "$(APPLE_EMAIL)" \
			--password "$(APPLE_PASSWORD)" \
			--team-id "$(TEAM_ID)"; \
		exit 1; \
	fi

	# staple the notarization ticket onto the app so it works offline
	xcrun stapler staple "$(APP_PATH)"

	rm ./cosmodrome-notarize.zip
	@echo "Notarization complete: $(APP_PATH)"

	# create output & ditto zip the app for distribution
	# strip xattrs/resource-forks/quarantine so the bundle can't gain ._* files
	mkdir -p ./output
	ditto -c -k --keepParent --norsrc --noextattr --noqtn "$(APP_PATH)" ./output/cosmodrome-macos.zip
	@echo "Packaged app: ./output/cosmodrome-macos.zip"

linux-local:
	mkdir -p ./output
	flutter precache --linux
	flutter pub get
	flutter build linux --release
	cd ./discord-rpc && go build -o rpc main.go
	mv ./discord-rpc/rpc ./build/linux/x64/release/bundle/cosmodrome-rpc
	cd ./build/linux/x64/release/bundle/ && zip -r ../../../../../app.zip .
	cp ./app.zip ./installer/app.zip
	cd ./installer && CGO_CFLAGS="-U_FORTIFY_SOURCE" fyne package -os linux -icon ./assets/logo.png
	cd ./installer && tar -xf cosmodrome_installer.tar.xz
	mv "$$(find ./installer -type f -name cosmodrome_installer | head -1)" ./output/cosmodrome_installer
	chmod +x ./output/cosmodrome_installer

# cleanup
	rm -rf ./installer/usr
	rm -rf ./installer/app.zip
	rm -rf ./installer/cosmodrome_installer.tar.xz

	mv ./app.zip ./output/cosmodrome-linux.zip


ipa:
	mkdir -p ./output/
	flutter build ios --release --no-codesign
	@if command -v ldid >/dev/null 2>&1; then \
		echo "Applying TrollStore entitlements with ldid..."; \
		ldid -S"$(IOS_TROLLSTORE_ENTITLEMENTS)" "$(IOS_RUNNER_BIN)"; \
	else \
		echo "ldid not found; skipping entitlements patch (install ldid for TrollStore-ready IPA)"; \
	fi
	mkdir -p ./output/ios/Payload
	cp -R "$(IOS_APP_PATH)" ./output/ios/Payload/
	cd ./output/ios && zip -qry ../cosmodrome.ipa Payload
	rm -rf ./output/ios/Payload
	@echo "IPA created: ./output/cosmodrome.ipa"

