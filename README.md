# qobuz-get

Tool to download FLACs from qobuz.com.

## Setup

Statically linked 64-bit Linux and Windows binaries are available in the (Releases)[https://git.fuwafuwa.moe/albino/qobuz-get/releases] tab. On Linux, you should install sox, ffmpeg and mktorrent with your package manager, and insert the paths to the binaries (found using `which sox`, `which ffmpeg`, etc...) into magic.json.

There are three other values which must be inserted into magic.json. `app_id` and `app_secret` are listed on [this page](http://shell.cyberia.is/~albino/qobuz-creds.html). `user_auth_token` is specific to your qobuz account. See the bottom of this README for instructions on finding it. These values could change from time to time, so if qobuz-get stops working suddenly, you probably need to get new ones.

On Windows, run the `InitEnvironment.bat` script to set things up. On Linux, just call the binary from your shell.

### But what about FreeBSD, macOS, ARM....?

It should be easy to build qobuz-get on any platform supported by a D compiler. Just install libcurl, libphobos, dub and a D compiler (such as DMD), then run `dub build -b release`.

## Troubleshooting

### FFmpeg fails!

On Linux, try using the statically linked ffmpeg binary provided here.

### Sox fails!

Sox might not be compiled with the right features. Try compiling it yourself, using `./configure --with-flac`. Also, if you try and link sox statically, it might not work. Try with dynamic linking.

### It's still not working!

Check that the values in magic.json are correct, then ask for help on IRC. Connect to `irc.rizon.net` and then join the channel `#qobuz-get`. If you want my attention, just highlight me (say "albino"). I'll try and respond quickly but please be patient.

## Finding `user_auth_token`

 * Open http://play.qobuz.com in your browser and log in with your credentials.
 * Open the 'Network' tab of your browser's developer tools. (In Firefox, right click on page -> inspect element -> select the 'Network' tab)
 * Type any letter into the "Search" box at the top right of the page.
 * In the Network window, you should see a `GET` request beginning with `search`. Select it.
 * You should see a list of headers on the right hand side (in Chrome, you need to click the "Headers" tab). Scroll down to the one which says `x-user-auth-token`. Select the content, and copy and paste it into magic.json. Done!
