//
//  SphericalMercator.swift
//  Ported to Swift here from JS source at https://github.com/mapbox/sphericalmercator/blob/master/sphericalmercator.js
//
//  Created by Wasin Thonkaew on 4/17/18.
//  Copyright © 2018 Wasin Thonkaew. All rights reserved.
//
import Foundation
import CoreLocation

enum MapProjection : String {
    case wgs84="wgs84"
    case webMercator="900913"
}

class SphericalMercator {
    /**
        One cache for all instance of SphericalMercator.
        It's dictionary with Int as key, and dictionary with key of String, and array of Double as value.
    */
    private static var cache: [Double:[String:[Double]]] = [:]
    
    private static let EPSLN: Double = 1.0e-10
    private static let D2R: Double = Double.pi / 180.0
    private static let R2D: Double = 180.0 / Double.pi
    // 900913 properties
    private static let A: Double = 6378137.0
    private static let MAXEXTENT: Double = 20037508.342789244
    
    /**
     Total of tiles for world map. It will be size * size total tiles for world map.
    */
    private var size: Double
    
    private var Bc: [Double] = []
    private var Cc: [Double] = []
    private var zc: [Double] = []
    private var Ac: [Double] = []
    
    /**
     Create SphericalMercator with default tile size.
     */
    convenience init() {
        self.init(size: 256)
    }
    
    /**
     Create SphericalMercator with input number of tiles in world map.

     - Parameter size: Squared tilesize. 
    */
    init(size: Double) {
        self.size = size
        
        // get cache reference
        var cache = SphericalMercator.cache
        // if there's no cache yet, then create
        if cache[size] == nil {
            var _size = size
            
            var c: [String:[Double]] = [:]
            
            c["Bc"] = []
            c["Cc"] = []
            c["zc"] = []
            c["Ac"] = []
            for _ in 0..<30 {
                c["Bc"]!.append(_size / 360.0)
                c["Cc"]!.append(_size / (2.0 * Double.pi))
                c["zc"]!.append(_size / 2.0)
                c["Ac"]!.append(_size)
                _size = _size * 2
            }
            
            // dictionary and array are value type, thus we need to set it here into dictionary
            cache[size] = c
        }
        self.Bc = cache[size]!["Bc"]!
        self.Cc = cache[size]!["Cc"]!
        self.zc = cache[size]!["zc"]!
        self.Ac = cache[size]!["Ac"]!
    }
    
    /**
     Convert longitude/latitude to screen pixel value
     
     - Parameter ll: Array of [longitude, latitude] of geographic coordinate
     - Parameter zoom: Zoom level
     
     - Return: Screen pixel value in [x, y]
    */
    func px(ll: [Double], zoom: Int) -> [Double] {
        let d = self.zc[zoom]
        let f = min(max(sin(SphericalMercator.D2R * ll[1]), -0.9999), 0.9999)
        var x = round(d + ll[0] * self.Bc[zoom])
        var y = round(d + 0.5 * log((1+f) / (1-f)) * (-self.Cc[zoom]))
        if x > self.Ac[zoom] {
           x = self.Ac[zoom]
        }
        if y > self.Ac[zoom] {
            y = self.Ac[zoom]
        }
        return [x,y]
    }
    
    /**
     Convert screen pixel value to longitude/latitude
     
     - Parameter px: Screen pixel [x,y] of geographic coordinate
     - Parameter zoom: Zoom level
     
     - Return: Geographic coordinate [longitude, latitude]
    */
    func ll(px: [Double], zoom: Int) -> [Double] {
        let g = (px[1] - self.zc[zoom]) / (-self.Cc[zoom])
        let lon = (px[0] - self.zc[zoom]) / self.Bc[zoom]
        let lat = SphericalMercator.R2D * (2 * atan(exp(g)) - 0.5 * Double.pi)
        return [lon, lat]
    }
    
    /**
     Convert tile x/y and zoom level to bounding box.
     
     - Parameter x: X (along longitude line) number
     - Parameter y: Y (along latitude line) number
     - Parameter zoom: Zoom level
     - Parameter tmsStyle: Whether to compute using tms-style. Default is false
     - Parameter srs: Projection result for bounding box. Default is .wgs84.
     
     - Return: Array of bounding box in form [w,s, e, n]
    */
    func bbox(x:Double, y:Double, zoom: Int, tmsStyle: Bool=false, srs: MapProjection = .wgs84) -> [Double] {
        var _y: Double = y
        
        // convert xyz into bbox with srs WGS84
        if tmsStyle {
            _y = (pow(2, Double(zoom)) - 1.0) - y
        }
        // use +y to make it's a number to avoid inadvertent concatenation
        // note: make sure x/y is longitude/latitude
        let ll = [x * self.size, (+_y+1) * self.size]  // lower left
        // use +x to make sure it's a number to avoid inadvertent concatenation
        let ur = [(+x+1) * self.size, _y * self.size]   // upper right
        var bbox = self.ll(px: ll, zoom: zoom)
        bbox.append(contentsOf: self.ll(px: ur, zoom: zoom))
        
        // if web mercator requested reproject to 900913
        if srs == .webMercator {
            return self.convert(bbox: bbox, to: .webMercator)
        }
        else {
            return bbox
        }
    }
    
    /**
     Convert bounding box to xyz bounds in form [minX, maxX, minY, maxY].
     
     - Parameter bbox: Bounding box in form [w, s, e, n]
     - Parameter zoom: Zoom level
     - Parameter tmsStyle: Whether to compute using tms-style. Default is false.
     - Parameter srs: Map projection. Default is .wgs84.
     
     - Return: XYZ bounds containg minX, maxX, minY and maxY.
    */
    func xyz(bbox: [Double], zoom: Int, tmsStyle: Bool=false, srs: MapProjection = .wgs84) -> [String: Double] {
        var _bbox: [Double] = bbox
        
        // if web mercator provided reproject to wgs84
        if srs == .webMercator {
            _bbox = self.convert(bbox: bbox, to: .wgs84)
        }
        
        let ll = [_bbox[0], _bbox[1]]   // lower left
        let ur = [_bbox[2], _bbox[3]]   // upper right
        let px_ll = self.px(ll: ll, zoom: zoom)
        let px_ur = self.px(ll: ur, zoom: zoom)
        // y = 0 for XYZ is the top hence minY uses px_ur[1]
        let x = [floor(px_ll[0] / self.size), floor((px_ur[0] - 1) / self.size)]
        let y = [floor(px_ur[1] / self.size), floor((px_ll[1] - 1) / self.size)]
        var bounds = [
            "minX": min(x[0], x[1]) < 0 ? 0 : min(x[0], x[1]),
            "minY": min(y[0], y[1]) < 0 ? 0 : min(y[0], y[1]),
            "maxX": max(x[0], x[1]),
            "maxY": max(y[0], y[1]) < 0 ? 0 : max(y[0], y[1])
        ]
        if tmsStyle {
            var tms = [
                "minY": (pow(2.0, Double(zoom)) - 1.0) - bounds["maxY"]!,
                "maxY": (pow(2.0, Double(zoom)) - 1.0) - bounds["minY"]!
            ]
            bounds["minY"] = tms["minY"]
            bounds["maxY"] = tms["maxY"]
        }
        return bounds
    }
    
    /**
     Convert projection of given box.
     
     - Parameter bbox: Bounding box in form [w, s, e, n]
     - Parameter to: Projection of output bounding box. Input bounding box assumed to be the "other" projection. Default is .wgs84.
     
     - Return: Bounding box with reprojected coordinates in form [w, s, e, n].
    */
    func convert(bbox: [Double], to: MapProjection = .wgs84) -> [Double] {
        if to == .webMercator {
            var retArr = self.forward(ll: Array(bbox[0..<2]))
            retArr.append(contentsOf: self.forward(ll: Array(bbox[2..<4])))
            return retArr
        }
        else {
            var retArr = self.inverse(xy: Array(bbox[0..<2]))
            retArr.append(contentsOf: self.inverse(xy: Array(bbox[2..<4])))
            return retArr
        }
    }
    
    /**
     Convert longitude/latitude values to 900913 x/y.
     
     - Parameter ll: Geographic coordinate in form [longitude, latitude]
     
     - Return: Converted geographic coordinate in form [longitude, latitude].
    */
    func forward(ll: [Double]) -> [Double] {
        var xy = [
            SphericalMercator.A * ll[0] * SphericalMercator.D2R,
            SphericalMercator.A * log(tan((Double.pi * 0.25) + (0.5 * ll[1] * SphericalMercator.D2R)))
        ]
        // if xy value is beyond maxextent (e.g. poles), return maxextent
        if xy[0] > SphericalMercator.MAXEXTENT { xy[0] = SphericalMercator.MAXEXTENT }
        if xy[0] < -SphericalMercator.MAXEXTENT { xy[0] = -SphericalMercator.MAXEXTENT }
        if xy[1] > SphericalMercator.MAXEXTENT { xy[1] = SphericalMercator.MAXEXTENT }
        if xy[1] < -SphericalMercator.MAXEXTENT { xy[1] = -SphericalMercator.MAXEXTENT }
        return xy
    }
    
    /**
     Convert 900913 x/y values to lon/lat.
     
     - Parameter xy: Geographic coordinate in form [x,y]
     
     - Return: Converted geographic coordinate in form [longitude, lattidue]
    */
    func inverse(xy: [Double]) -> [Double] {
        return [
            xy[0] * SphericalMercator.R2D / SphericalMercator.A,
            ((Double.pi * 0.5) - 2.0 * atan(exp(-xy[1] / SphericalMercator.A))) * SphericalMercator.R2D
        ]
    }
}