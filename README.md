# Cosmodrome

[![Build Linux, Windows, iOS & Android.](https://github.com/DwifteJB/cosmodrome/actions/workflows/build.yml/badge.svg)](https://github.com/DwifteJB/cosmodrome/actions/workflows/build.yml)
[![Build Web](https://github.com/DwifteJB/cosmodrome/actions/workflows/build-web.yml/badge.svg)](https://github.com/DwifteJB/cosmodrome/actions/workflows/build-web.yml)

A cross-platform subsonic (specifically navidrome) music client built within Flutter.

You can test with the web app at [https://cosmodrome.rmfosho.me/](https://cosmodrome.rmfosho.me/home)

This project is under the [GPL-2.0 License](https://github.com/DwifteJB/cosmodrome/blob/main/LICENSE). Feel free to fork & add changes, just check out the [Contributions](https://github.com/DwifteJB/cosmodrome/blob/main/README.md#contributions) sections below.

| iOS | Mac |
| --- | --- |
|<img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/ios-album.png" style="width:300px;height:auto" /> | <img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/mac-album.png" style="width:600px;height:auto" /> |

<hr />


## Downloads

You can get android, linux, ios & windows builds in the [Actions Page](https://github.com/DwifteJB/cosmodrome/actions). 

The MacOS builds are regularly added to the [Releases Page](https://github.com/DwifteJB/cosmodrome/releases).

The iOS testflight can be accessed [here.](https://testflight.apple.com/join/uuX9qUxQ)

If you are on iOS 16 or below, you can download the IPA as it is made for iOS 13 and above.

## Features

### Multi-server & Multi accounts

The app includes support for multiple subsonic servers, as well as multiple accounts for each server, so you wont need to keep logging in & out, you can just save the credentials and swap at a single buttons press.

### Albums

You can fully play through & search for whatever albums you have on your subsonic server. You can also star these to keep them on the main page or on the sidebar (desktop).

### Playlists

You can fully play, browse, create & edit playlists in the app.

### Downloads

Data within the app is cached, so when you open it without access to the server, you'll be able to use any downloaded song.

### Artist View

TBD

### Discord Rich Presence

<img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/discord-rich.png" />

Discord rich presences work, they do require an external server for images that are deemed as "invalid" (e.g are on a local network, a DNS only network like tailscale). These are saved anonymously with no tracking (other than HTTP queries) & you can see the source code for that [here](https://github.com/DwifteJB/cosmodrome-backend). Obviously this is only supported on desktop platforms, but if the API is opened up & we can connect discord accounts through the app, like how PreMiD works, then this is definitely a possibility in the future.

If you would like to support me, currently you can contact me at [me@rmfosho.me](mailto:me@rmfosho.me)

## Platform Support
Current support for the client is as following (order of what is focused):

 - [X] iOS
 - [X] Android
 - [X] Linux
 - [X] MacOS 
 - [X] Windows
 - [ ] Apple Carplay 
 - [ ] Android Auto
 - [X] Web

Current support for known servers (subsonic-like servers) are as following:

* [Subsonic](https://www.subsonic.org/pages/index.jsp)
* [Open Subsonic](https://github.com/opensubsonic/open-subsonic-api) (including, [Navidrome](https://github.com/navidrome/navidrome))
* [Octo-fiesta](https://github.com/V1ck3s/octo-fiesta)

There is a project I do want to work on, that creates a subsonic server from apple music using something like [MusicKit](https://developer.apple.com/musickit/) and [GAMDL](https://github.com/glomatico/gamdl). So expect something like that at some point of time

## Whats the plans for when this releases?

When/If this releases, the iOS & Android app will be listed on the appstore for £2/$2. The subscription cost of the iOS developer account is quite a lot, so this will be my way of trying to get the costs back for the development & my overall time.

The app will be free & open source, free to compile and run as long as you can install an APK or an IPA file.

The desktop apps I am not too sure about, they will most likely also just be free with no paywall.

## Contributions
To contribute, create a fork and create a pull request whenever ready for it to be reviewed!

### AI disclaimer
If you are contributing, do not make whole pull requests with just ai generated code. Go through and actually understand what it does, and ensure it does not break anything else.
