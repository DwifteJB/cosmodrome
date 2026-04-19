# Cosmodrome

[![Build Linux and Android](https://github.com/DwifteJB/cosmodrome/actions/workflows/build-linux-android.yml/badge.svg)](https://github.com/DwifteJB/cosmodrome/actions/workflows/build-linux-android.yml)
[![Build Web](https://github.com/DwifteJB/cosmodrome/actions/workflows/build-web.yml/badge.svg)](https://github.com/DwifteJB/cosmodrome/actions/workflows/build-web.yml)

A cross-platform subsonic (specifically navidrome) music client built within Flutter.

You can test with the web app at [https://cosmodrome.rmfosho.me/](https://cosmodrome.rmfosho.me/home)

This project is under the [GPL-2.0 License](https://github.com/DwifteJB/cosmodrome/blob/main/LICENSE). Feel free to fork & add changes, just check out the [Contributions](https://github.com/DwifteJB/cosmodrome/blob/main/README.md#contributions) sections below.

| iOS | Mac |
| --- | --- |
|<img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/ios-album.png" style="width:300px;height:auto" /> | <img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/mac-album.png" style="width:600px;height:auto" /> |

<hr />


## Downloads

You can get android and linux builds in the artifacts sections. 

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

 - [X] Linux
 - [X] MacOS 
 - [X] iOS
 - [ ] Apple Carplay 
 - [X] Android
 - [ ] Android Auto
 - [ ] Windows (unknown, probably yes lol)
 - [X] Web


## Whats the plans for when this releases?

When/If this releases, the iOS & Android app will be listed on the appstore for £2/$2. The subscription cost of the iOS developer account is quite a lot, so this will be my way of trying to get the costs back for development & my time.

The app will be free & open source, free to compile and run as long as you can install an APK or an IPA file.

The desktop apps I am not too sure about, they will most likely also just be free with no paywall.

## TODO list
- [X] create installers for windows & linux
- [X] discord rich presence via golang sub-process using ipcs
- [X] ability to refresh subsonic songs
- [X] playlists yes
- [X] library view
- [ ] searching
- [ ] bookmarks
- [X] shuffling
- [X] repeating
- [X] starring
- [X] downloads
- [ ] settings page

## Contributions
To contribute, create a fork and create a pull request whenever ready for it to be reviewed!

### AI disclaimer
If you are contributing, do not make whole pull requests with just ai generated code. Go through and actually understand what it does, and ensure it does not break anything else.
