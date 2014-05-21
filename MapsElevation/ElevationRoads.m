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

-(float) WayDistance:(NSDictionary*) way
{
    NSArray* points=[way objectForKey:@"points"];
    float dist=0;
    for (int i=0; i<[points count]-1; i++)
    {
        ElevationPoint* p1=[points objectAtIndex:i];
        ElevationPoint* p2=[points objectAtIndex:i+1];
        dist+=getDist(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
    }
    return dist;
}



-(void) runUsingBlock:(ElevationRoadsBlock) delegate
{
    self.delegateBlock = delegate;
 
    [_overpass runUsingBlock:^(NSMutableArray* ways)
     {

         
         delegateBlock(ways);
         
     }];

}

@end
