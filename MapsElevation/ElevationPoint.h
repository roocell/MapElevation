//
//  ElevationPoint.h
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface ElevationPoint : NSObject
@property CLLocationCoordinate2D coordinate;
@property float elevation;

@end
