# HamCore

The amateur-radio domain layer behind SOTA Log: models, the GRDB logbook and
reference database with its migrations, ADIF encoding and decoding, the band
plan, callsign and Maidenhead utilities, and clients for the SOTA, POTA and QRZ
APIs. No UI and no radio control; apps build those on top.

A Swift package for iOS 17 and macOS 14 with one dependency, GRDB. It lives
inside the SOTA Log repository and the iOS app consumes it by relative path,
but it is laid out as a self-contained package so it can move to a repository
of its own without changes.

```sh
swift build
swift test
```
