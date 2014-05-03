//
//  ElevationGrid.h
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "ElevationRequest.h"

typedef void (^ElevationGridBlock)(NSMutableArray*);

@interface ElevationGrid : NSObject
{
    @protected ElevationGridBlock delegateBlock;
}
@property (retain, nonatomic) NSMutableArray* grid; // an array of arrays of ElevationPoints
@property (retain, nonatomic) NSMutableArray* requests; // an array of arrays of ElevationRequest
@property CLLocationCoordinate2D centerCoordinate;
@property float width;

-(id) initWithCenterCoordinate:(CLLocationCoordinate2D) centerCoordinate withWidth:(float) width;
-(void) runUsingBlock:(ElevationGridBlock) delegate;

@end
