# CloudyKit

![Test workflow](https://github.com/camdenfullmer/CloudyKit/workflows/Test/badge.svg)
[![Twitter](https://img.shields.io/badge/Twitter-@camdenfullmer-blue.svg?style=flat)](https://twitter.com/camdenfullmer)

CloudyKit is a drop in replacement for Apple's [CloudKit](https://developer.apple.com/icloud/cloudkit/) on Linux. It uses [CloudKit Web Services](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/index.html) behind the scenes and has the same [API](https://developer.apple.com/documentation/cloudkit) that is used on iOS and macOS.

- [CloudyKit](#cloudykit)
  - [Installation](#installation)
    - [Swift Package Manager](#swift-package-manager)
  - [Configuration](#configuration)
    - [Server-to-Server Key](#server-to-server-key)
    - [Environment](#environment)
  - [Supported Features](#supported-features)
  - [API Differences](#api-differences)
    - [`NSSortDescriptor`](#nssortdescriptor)
    - [`NSPredicate`](#nspredicate)
  - [Questions](#questions)

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
CloudyKitConfig.serverPrivateKey = try CKPrivateKey(path: "eckey.pem")
```

### Environment

CloudyKit allows you to switch between your development and production environments by doing the following:

```swift
CloudyKitConfig.environment = .development // Use `.production` for production.
```

## Supported Features

Below is the list of supported and upcoming features for CloudyKit.

- [x] Creating Records
- [x] Saving Records
- [x] Fetching Records
- [x] Querying Records
- [x] Deleting Records
- [x] Uploading Assets
- [ ] All Types (missing Locations, Lists)
- [ ] Private and Shared Databases
- [ ] Operations
- [ ] Errors
- [ ] Fetching Record Changes

## API Differences

### `NSSortDescriptor`

`NSSortDescriptor` on Linux [does not offer](https://github.com/apple/swift-corelibs-foundation/blob/main/Docs/ReleaseNotes_Swift5.md#nssortdescriptor-changes) an initializer with a key `String` value. Instead, use the `typealias` `SortDescriptor` that offers the same API.

```swift
let sortDescriptor = SortDescriptor(key: "KEY", ascending: true) // instead of NSSortDescriptor(key: "KEY", ascending: true)
```

### `NSPredicate`

`NSPredicate` on Linux [does not support](https://github.com/apple/swift-corelibs-foundation/blob/main/Docs/Status.md#entities) an initializer with a predicate format. Instead, use the `typealias` `Predicate` that offers the same API.

```swift
let predicate = Predicate(format: "ANY favoriteColors = 'red'") // instead of NSPredicate(format: "ANY favoriteColors = 'red'")
```

## Questions

Please open up an issue or reach out to me on [Twitter](https://twitter.com/camdenfullmer) if you have any questions or need help using the library!
