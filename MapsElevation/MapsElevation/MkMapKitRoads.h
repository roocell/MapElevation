//
//  MkMapKitRoads.h
//  MapsElevation
//
//  Created by michael russell on 2014-05-04.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//
// an local alternative to OpenStreetMapsOverpass
// we could extract a PNG from the mapView and scan it for pixel that much a road color.
// then map those pixels to a coordinate and then performa an elevation request on those points.


#import <Foundation/Foundation.h>

@interface MkMapKitRoads : NSObject

@end
