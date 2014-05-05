//
//  ElevationRoads.m
//  MapsElevation
//
//  Created by michael russell on 2014-05-04.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "ElevationRoads.h"

@interface ElevationRoads ()
@property (nonatomic, copy) ElevationRoadsBlock delegateBlock; // Attention: Copy the block and not retain it
@end

@implementation ElevationRoads
@synthesize delegateBlock;
@synthesize requests=_requests;
@synthesize bbox=_bbox;
@synthesize overpass=_overpass;

-(id) initWithBoundingBox:(BoundingBox) bbox
{
    if (self=[super init])
    {
        _requests=[[NSMutableArray alloc] initWithCapacity:0];
        _overpass=[[OpenStreetMapsOverpass alloc] initWithBoundingBox:bbox];
        _bbox=bbox;
        
        return self;
    }
    return nil;

}
-(void) runUsingBlock:(ElevationRoadsBlock) delegate
{
    self.delegateBlock = delegate;
 
    [_overpass runUsingBlock:^(NSMutableArray* points)
     {
         // returns points without elevation
         // we need to build a elevation request and fill in the elevation
         for (ElevationPoint* p in points)
         {
             
         }
         delegateBlock(points);
         
     }];

}

@end
