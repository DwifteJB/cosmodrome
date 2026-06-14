# syntax=docker/dockerfile:1
# build linux & android app
FROM ubuntu:22.04 AS builder

# prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# env
ENV GO_VERSION=1.26.1
ENV GOOS=linux
ENV GOARCH=amd64

# install dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
    file \
    curl \
    unzip \
    bash \
    zip \
    git \
    tar \
    wget \
    xz-utils \
    # linux
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-12-dev \
    libsecret-1-dev \
    libayatana-appindicator3-dev \
    libxxf86vm-dev \
    lld \
    # egl
    mesa-utils \
    # android
    openjdk-17-jdk

# flutter
RUN git clone https://github.com/flutter/flutter.git -b stable /usr/local/flutter

# golang
RUN wget https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz

# android sdk command line tools
RUN mkdir -p /usr/local/android-sdk/cmdline-tools && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip && \
    unzip cmdline-tools.zip -d /usr/local/android-sdk/cmdline-tools && \
    mv /usr/local/android-sdk/cmdline-tools/cmdline-tools /usr/local/android-sdk/cmdline-tools/latest && \
    rm cmdline-tools.zip

# env variables for flutter, go, and android sdk
ENV ANDROID_SDK_ROOT=/usr/local/android-sdk
ENV ANDROID_HOME=/usr/local/android-sdk
ENV GOPATH=/root/go
# explicit cache homes so the cache mounts below have a stable target
ENV PUB_CACHE=/root/.pub-cache
ENV GRADLE_USER_HOME=/root/.gradle

ENV PATH="/usr/local/go/bin:${GOPATH}/bin:/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:/usr/local/android-sdk/cmdline-tools/latest/bin:/usr/local/android-sdk/platform-tools:${PATH}"

# accept android sdk licenses and install required sdk components
RUN yes | sdkmanager --licenses && \
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# precache flutter artifacts for linux and android
RUN flutter precache --linux
RUN flutter precache --android

RUN --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go install fyne.io/tools/cmd/fyne@latest

# set working directory
WORKDIR /app

# install flutter dependencies (cache the pub package downloads)
COPY pubspec.yaml pubspec.lock ./
RUN --mount=type=cache,target=/root/.pub-cache flutter pub get

# copy the rest of the app source code
COPY . .

RUN flutter clean

# build the flutter linux app
RUN --mount=type=cache,target=/root/.pub-cache flutter build linux --release

# build the flutter android app (cache pub + the gradle dependency/build caches)
RUN --mount=type=cache,target=/root/.pub-cache \
    --mount=type=cache,target=/root/.gradle \
    flutter build apk --release

# build discord RDP server
WORKDIR /app/discord-rpc
RUN --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o rpc main.go

RUN mv /app/discord-rpc/rpc /app/build/linux/x64/release/bundle/cosmodrome-rpc

# zip up the built app and rpc
WORKDIR /app/build/linux/x64/release/bundle
RUN zip -r /app/app.zip .
RUN cp /app/app.zip /app/installer/app.zip

# build the installer
WORKDIR /app/installer
# bash does not work with bash build_linux.sh :(
RUN --mount=type=cache,target=/root/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_CFLAGS="-U_FORTIFY_SOURCE" fyne package -os linux -icon ./assets/logo.png

RUN tar -xf cosmodrome_installer.tar.xz
RUN BINARY=$(find . -type f -name cosmodrome_installer | head -1) && \
    mv "$BINARY" /app/cosmodrome_installer
RUN chmod +x /app/cosmodrome_installer

# zip up the built android apk
WORKDIR /app/build/app/outputs/flutter-apk
RUN zip -r /app/app-android.zip app-release.apk

# export stage - extracts just the zip files
FROM scratch AS export

COPY --from=builder /app/cosmodrome_installer /
COPY --from=builder /app/app.zip /
COPY --from=builder /app/app-android.zip /