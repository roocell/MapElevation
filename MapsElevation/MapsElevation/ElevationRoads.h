//
//  ElevationRoads.h
//  MapsElevation
//
//  Created by michael russell on 2014-05-04.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ElevationRequest.h"
#import "OpenStreetMapsOverpass.h"


typedef void (^ElevationRoadsBlock)(NSMutableArray*);

@interface ElevationRoads : NSObject
{
    @protected ElevationRoadsBlock delegateBlock;
}
@property (retain, nonatomic) NSMutableArray* requests; // an array of arrays of ElevationRequest
@property (retain, nonatomic) OpenStreetMapsOverpass* overpass;
@property BoundingBox bbox;

-(id) initWithBoundingBox:(BoundingBox) bbox;
-(void) runUsingBlock:(ElevationRoadsBlock) delegate;

@end
