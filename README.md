# CloudyKit

![Test workflow](https://github.com/camdenfullmer/CloudyKit/workflows/Test/badge.svg)

CloudyKit is a drop-in replacement for Apple's [CloudKit](https://developer.apple.com/icloud/cloudkit/) on Linux. It uses [CloudKit Web Services](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/index.html) behind the scenes and has the same [API](https://developer.apple.com/documentation/cloudkit) that is used on iOS and macOS.

- [CloudyKit](#cloudykit)
  - [Installation](#installation)
    - [Swift Package Manager](#swift-package-manager)
  - [Configuration](#configuration)
    - [Server-to-Server Key](#server-to-server-key)
    - [Environment](#environment)
  - [Support](#support)

## Installation

### Swift Package Manager

CloudyKit is available through [Swift Package Manager](https://swift.org/package-manager/). To install it, add the dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/camdenfullmer/CloudyKit.git", from: "0.1.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["CloudyKit"]),
]
```

## Configuration

Before you get started using CloudyKit there a few things that need to be set up first.

### Server-to-Server Key

First, you must create a [Server-to-Server Key](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/SettingUpWebServices.html#//apple_ref/doc/uid/TP40015240-CH24-SW6) that CloudyKit can use to authenticate its requests.

```swift
CloudyKitConfig.serverKeyID = "YOUR SERVER KEY ID"
CloudyKitConfig.serverPrivateKey = "YOUR SERVER PRIVATE KEY"
```

### Environment

CloudyKit allows you to switch between your development and production environments by doing the following:

```swift
CloudyKitConfig.environment = .development | .production
```

## Support

Below is the list of supported and upcoming features for CloudyKit.

- [x] Creating Records
- [ ] Saving Records
- [ ] Fetching Records
- [ ] Querying Records
- [ ] Deleting Records
- [ ] All Types (References, Assets, Locations, Dates, Bytes, Doubles, Lists)
