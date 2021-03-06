//
//  ElevationPoint.m
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "ElevationPoint.h"

@implementation ElevationPoint
@synthesize elevation=_elevation;
@synthesize coordinate=_coordinate;
@synthesize color=_color;
@synthesize title=_title;
@synthesize idx=idx;
-(id) init
{
    if (self=[super init])
    {
        _color=MKPinAnnotationColorPurple;
        return self;
    }
    return nil;
}
@end
