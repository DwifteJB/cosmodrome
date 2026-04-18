linux-and-android:
	docker build --target export --output ./output .

linux-local:
	rm -rf ./output
	mkdir -p ./output
	flutter precache --linux
	flutter pub get
	flutter build linux --release
	cd ./discord-rpc && go build -o rpc main.go
	mv ./discord-rpc/rpc ./build/linux/x64/release/bundle/cosmodrome-rpc
	cd ./build/linux/x64/release/bundle/ && zip -r ../../../../../app.zip .
	cp ./app.zip ./installer/app.zip
	cd ./installer && fyne package -os linux -icon ./assets/logo.png 
	cd ./installer && tar -xf cosmodrome_installer.tar.xz -C .. --strip-components=1
	mv ./local/bin/cosmodrome_installer ./output/cosmodrome_installer

# cleanup
	rm -rf ./local
	rm -rf ./installer/app.zip
	rm -rf ./installer/cosmodrome_installer.tar.xz

	mv ./app.zip ./output/app.zip