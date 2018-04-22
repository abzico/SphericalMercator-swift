[![donate button](https://img.shields.io/badge/$-donate-ff69b4.svg?maxAge=2592000&amp;style=flat)](https://github.com/abzico/donate)

# SphericalMercator-swift
SphericalMercator in Swift implementation from original JS implementation at [sphericalmercator.js](https://github.com/mapbox/sphericalmercator/blob/master/sphericalmercator.js)

# What's for?

Working with Mapbox for iOS SDK. If you need to implement chunk/grid system that has equal size all across the map, then using Spherical Mercator Coordinate will help achieve that.

Initially Mapbox uses WGS84 coordinate system, and with the fact that you can just define fixed distance values of latitude/longitude to define your tile to achive the sqaured grid visually on Mapbox. Spherical Mercator Coordinate system will help.

You can read [here](https://github.com/mapbox/mapbox-gl-native/issues/11621) for more context for our problem on trying to achieve such goal.

After applying with Spherical Mercator, top-left most is original with tile index of 0,0 and grows towards bottom-right.

# How to Use?

* Creating an instance of SphericalMercator with default tile size of 256 * 256

```swift
let sphericalMercator = SphericalMercator()
```

* Creating an instance of SphericalMercator with set tile size

```swift
let sphericalMercator = SphericalMercator(size: 128)
```

> To my test, tilesize seems not to get into effect. Only zoom level is the factor. This is one point to look at.

* Converting longitude/latitude location to tile index

```swift
let bounds = sphericalMercator.xyz(bbox: [location.longitude, location.latitude, location.longitude, location.latitude], zoom: 22)
let tileIndex = (x: Int(floor(bounds["minX"]!)), y: Int(floor(bounds["maxY"]!)))
```

`location` is `CLLocationCoordinate2D` and is your known information. **Remember** to input with longitude first before latitude. Zoom level is a set value you intend to use across the app. If such value changes, it will split the map into various number of tiles across the map. Mapbox supports maximum of zoom level of 22, thus it will generate the largest total number of tiles with this number (4194303 (width) * 4194303 (height) =~ 17 MM tiles).

or you can do this

```swift
let bounds = sphericalMercator.xyz(bbox: [location.longitude, location.latitude, 0.0, 0.0], zoom: 22)
let tileIndex = (x: Int(floor(bounds["minX"]!)), y: Int(floor(bounds["maxY"]!)))
```

it will give you the same tile index.

* Converting from tile index to bounding box of longitude/latitude

```swift
let bbox = sphericalMercator.bbox(x: Double(x), y: Double(y), zoom: 22)
```

`bbox` is in array of Double in form `[west, south, east, north]`. You can further use this bounding box to render grid line on top of Mapbox by creating `MGLPolygonLine` from this information.

# License

MIT, abzi.co
