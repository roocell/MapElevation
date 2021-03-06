//
//  ElevationRequest.h
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ElevationPoint.h"
#import <MapKit/MapKit.h>
#import "AFHTTPRequestOperationManager.h"

typedef void (^ElevationRequestBlock)(NSMutableArray*);

@interface ElevationRequest : NSObject
{
    @protected ElevationRequestBlock delegateBlock;
}
@property unsigned long numberOfRequests;
@property unsigned long numberOfRequestsLeftToProcess;
@property (nonatomic, retain) NSMutableArray* points;
@property (nonatomic, retain) NSMutableArray* results;
@property (nonatomic, retain) AFHTTPRequestOperationManager *manager;

-(id) initWithQueryArray:(NSMutableArray*) points usingBlock:(ElevationRequestBlock)delegate;
-(id) initWithQueryPath:(CLLocationCoordinate2D) start withEnd:(CLLocationCoordinate2D) end andSamples:(int) samples usingBlock:(ElevationRequestBlock)delegate;;
-(void) cancel;

#define MAPQUEST_STATUS_ELEVATION_NOT_FOUND (-32768)

@end
