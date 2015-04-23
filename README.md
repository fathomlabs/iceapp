# ![Ice icon](https://raw.githubusercontent.com/fathomlabs/IceApp/master/Ice.iconset/icon_32x32%402x.png) IceApp

IceApp is an OSX standalone app for running an ICE server (JBEI [Inventory of Composable Elements](https://github.com/JBEI/ice)). It packages up PostreSQL, JBOSS WildFly Server, and the ICE app itself to make installation and running of a server an easy, user-friendly experience on OSX.

## Installation

Before you get started, make sure you have Java v7 or above installed:

```bash
java -version
```

You should see 'java version "1.7.0_67"' or similar. If the number is at least `1.7`, continue with the numbered instructions below. If not, download the latest version of java [here](https://www.java.com/en/download/mac_download.jsp) before continuing.

1. Download the latest version from the [releases page](https://github.com/fathomlabs/IceApp/releases)
2. Double-click the downloaded `.dmg` file
3. Drag the `Ice.app` icon into the `/Applications` icon
4. Open your `Applications` directory and run `Ice.app`

The app will do the following:

1. Set up a postgres database server, create the necessary users and databases, and run the server
2. Set up a JBOSS Wildfly application server and create the necessary systems (e.g. https)
3. Set up and deploy the ICE app onto the application server

To view your running ICE installation, go to http://localhost:8080.

## Screenshot

![Screenshot](https://raw.githubusercontent.com/fathomlabs/IceApp/master/artwork/screenshot.png)

## Building the app from scratch

The app is setup to be able to be rebuilt with new versions of postgres, wildfly and ICE easily. Just follow the following steps to build from scratch:

Prerequisites:

- XCode
- homebrew
- `brew install autoconf automake`
- Node.js
- Ruby/rubygems

Download the code:

```bash
git clone https://github.com/fathomlabs/IceApp.git
```

Download the internal dependencies:

```bash
gem install cocoapods
cd IceApp
pod install
```

Download and ompile the external dependencies:

```bash
cd src
make
```

Once this is done, you can just open `Ice.xcworkspace` in Xcode, select the "Ice" scheme, and click "Build".

To export your build as an `.app`, use the "Archive" command and then use the "Distribute" command in Organizer.

To package the exported app in a pretty `.dmg`, save the archived app to the base directory of the source code, then:

```bash
nom install --gloal appdmg
appdmg dmg.json IceApp.dmg
```
