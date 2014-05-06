//
//  ElevationPoint.h
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

// C version of this struct
typedef struct {
    CLLocationCoordinate2D coordinate;
    float elevation;
    float   maxima;
} ElevationPoint_c;

@interface ElevationPoint : NSObject
@property CLLocationCoordinate2D coordinate;
@property float elevation;
@property float   maxima;
@property int     row;
@property int     col;
@property int color;
@property NSUInteger idx;
@property (retain, nonatomic) NSString* title;
@end
