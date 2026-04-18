# Cosmodrome
A cross-platform subsonic (specifically navidrome) music client built within Flutter.

This project is under the [GPL-2.0 License](https://github.com/DwifteJB/cosmodrome/blob/main/LICENSE). Feel free to fork & add changes, just check out the [Contributions](https://github.com/DwifteJB/cosmodrome/blob/main/README.md#contributions) sections below.

| iOS | Mac |
| --- | --- |
|<img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/ios-album.png" style="width:300px;height:auto" /> | <img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/mac-album.png" style="width:600px;height:auto" /> |

<hr />

## Features

### Multi-server & Multi accounts

The app includes support for multiple subsonic servers, as well as multiple accounts for each server, so you wont need to keep logging in & out, you can just save the credentials and swap at a single buttons press.

### Albums

You can fully play through & search for whatever albums you have on your subsonic server. You can also star these to keep them on the main page or on the sidebar (desktop).

### Playlists

You can fully play, browse, create & edit playlists in the app.

### Artist View

TBD

### Discord Rich Presence

<img src="https://raw.githubusercontent.com/DwifteJB/cosmodrome/refs/heads/main/.github/images/discord-rich.png" />

Discord rich presences work, they do require an external server for images that are deemed as "invalid" (e.g are on a local network, a DNS only network like tailscale). These are saved anonymously with no tracking (other than HTTP queries) & you can see the source code for that [here](https://github.com/DwifteJB/cosmodrome-backend). Obviously this is only supported on desktop platforms, but if the API is opened up & we can connect discord accounts through the app, like how PreMiD works, then this is definitely a possibility in the future.

## Downloads

You can get android and linux builds in the artifacts sections. Testflight will be coming soon & MacOS builds will be periodically added.

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

## TODO list
- [X] create installers for windows & linux
- [X] discord rich presence via golang sub-process using ipcs
- [X] ability to refresh subsonic songs
- [X] playlists yes
- [X] library view
- [ ] searching
- [ ] bookmarks
- [X] starring
- [ ] support for jellyfin
- [ ] support for flexx

## Contributions
To contribute, create a fork and create a pull request whenever ready for it to be reviewed!

### AI disclaimer
If you are contributing, do not make whole pull requests with just ai generated code. Go through and actually understand what it does, and ensure it does not break anything else.
