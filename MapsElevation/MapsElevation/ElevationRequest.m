//
//  ElevationRequest.m
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "ElevationRequest.h"

#define GOOGLE_API_KEY @"AIzaSyA7KcdzIJ5avApvg3l8AT_vamtDCpYL9gI"
#define GOOGLE_ELEVATION_URL_LOCATIONS @"https://maps.googleapis.com/maps/api/elevation/json?locations=%@&sensor=true&key=%@"
#define GOOGLE_ELEVATION_URL_PATH @"https://maps.googleapis.com/maps/api/elevation/json?path=%@&sensor=true&key=%@"
#define GOOGLE_ELEVATION_API_MAX_POINTS 512  // can query elevation for 512 points in one request.
#define GOOGLE_ELEVATION_API_MAX_URLSTR 2000
#define GOOGLE_DELIMITER @"|"


#define MAPQUEST_KEY @"Fmjtd|luur2q68nq,2l=o5-9a2sqw"
#define MAPQUEST_ELEVATION_URL @"http://open.mapquestapi.com/elevation/v1/profile?key=%@&shapeFormat=raw&outFormat=json&latLngCollection=%@"
#define MAPQUEST_API_MAX_POINTS_PER_REQUEST 32
#define MAPQUEST_STATUS_SOME_ELEVATIONS_NOT_FOUND 602
#define MAPQUEST_DELIMITER @","

@interface ElevationRequest ()
    @property (nonatomic, copy) ElevationRequestBlock delegateBlock; // Attention: Copy the block and not retain it
@end

@implementation ElevationRequest
@synthesize delegateBlock;
@synthesize numberOfRequests=_numberOfRequests;
@synthesize numberOfRequestsLeftToProcess=_numberOfRequestsLeftToProcess;
@synthesize results=_results;
@synthesize manager=_manager;

-(id) initWithQueryArray:(NSMutableArray*) points usingBlock:(ElevationRequestBlock)delegate
{
    if (self=[super init])
    {
        self.delegateBlock = delegate;
        _results=[[NSMutableArray alloc] initWithCapacity:0];
        [self QueryElevations:points];
        return self;
    }
    return nil;
}

-(id) initWithQueryPath:(CLLocationCoordinate2D) start withEnd:(CLLocationCoordinate2D) end andSamples:(int) samples usingBlock:(ElevationRequestBlock)delegate
{
    self=[super init];
    _results=[[NSMutableArray alloc] initWithCapacity:0];
    //[self QueryElevations:points];
    return self;
}

// points == array of ElevationPoints
// can be any size (this function will break it up into multiple requests)
-(void) QueryElevations:(NSMutableArray*) points
{
    int i;
    _numberOfRequests=[points count]/MAPQUEST_API_MAX_POINTS_PER_REQUEST;
    if ([points count]%MAPQUEST_API_MAX_POINTS_PER_REQUEST!=0) _numberOfRequests++;
    _numberOfRequestsLeftToProcess=_numberOfRequests;
    
    //TGLog(@"%lu requests required", _numberOfRequests);
    
    // build requests based on API limits.
    NSMutableArray* reqarr=[[NSMutableArray alloc] initWithCapacity:0];
    for (int r=0; r<_numberOfRequests; r++)
    {
        for (i=0; i<MAPQUEST_API_MAX_POINTS_PER_REQUEST; i++)
        {
            ElevationPoint* p=[points objectAtIndex:i+r*MAPQUEST_API_MAX_POINTS_PER_REQUEST];
            [reqarr addObject:p];
        }
        [self queryMapquestLocations:[self ArrayToString:reqarr withDelimiter:MAPQUEST_DELIMITER]];
    }
}


-(NSString*) ArrayToString:(NSMutableArray*) arr withDelimiter:(NSString*) delimiter
{
    NSString* str=[NSString stringWithFormat:@""];
    for (ElevationPoint* p in arr)
    {
        str=[str stringByAppendingString:[NSString stringWithFormat:@"%f,%f",p.coordinate.latitude, p.coordinate.longitude]];
        
        if (p!=[arr lastObject])
        {
            str=[str stringByAppendingString:delimiter]; // '|' for google, ',' for mapquest
        }
        
    }
    if ([str length]>GOOGLE_ELEVATION_API_MAX_URLSTR)
    {
        TGLog(@"ERR %ld strlen %ld", [arr count], [str length]);
    }
    return str;
}



#pragma mark GOOGLE
// google has 2 APIs
//    1. a collection of points
//    2. a path with a given number of points.
// http://maps.googleapis.com/maps/api/elevation/json?locations=39.7391536,-104.9847034|36.455556,-116.866667&sensor=true_or_false&key=API_KEY
// http://maps.googleapis.com/maps/api/elevation/json?path=36.578581,-118.291994|36.23998,-116.83171&samples=3&sensor=true_or_false&key=API_KEY
-(void) queryGoogleLocations:(NSString*)locationsString
{
    
    NSString* urlStr=[NSString stringWithFormat:GOOGLE_ELEVATION_URL_PATH, locationsString, GOOGLE_API_KEY];
#if 1
    NSString * escapedUrlString =[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
#else
    NSString * escapedUrlString =
    (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                 NULL,
                                                                 (CFStringRef)urlStr,
                                                                 NULL,
                                                                 (CFStringRef)@"!*'();@&=+$,/?%#[]",
                                                                 kCFStringEncodingUTF8 );
#endif
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:escapedUrlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        TGLog(@"JSON: %@", responseObject);
        
        
        NSError * error = nil;
        NSData *data = [responseObject  dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if(dictionary==nil)
        {
            TGLog(@"%@", error);
            return;
        }
        
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        TGLog(@"Error: %@", error);
    }];
    
}

#pragma mark MAPQEUST
// mapquest only has one API - a collection of points.
-(void) MapquestResponse:(NSDictionary*) dict
{
    TGLog(@"processing %lu/%lu", _numberOfRequestsLeftToProcess, _numberOfRequests);
    
    //TGLog(@"%@", dict);
    NSDictionary *info = [dict valueForKey:@"info"];
    //TGLog(@"%@", info);
    //TGLog(@"statuscode %@", [info valueForKey:@"statuscode"]);
    int status=[[info valueForKey:@"statuscode"] intValue];
    if(status!=0 && status!=MAPQUEST_STATUS_SOME_ELEVATIONS_NOT_FOUND)
    {
        TGLog(@"ERR - mapquest data returned failure. %@", dict);
        return;
    }
    if (status==MAPQUEST_STATUS_SOME_ELEVATIONS_NOT_FOUND)
    {
        TGLog(@"INFO - mapquest some data points missing");
    }
    
    // add the data to the grid
    NSArray *elevationProfile = [dict valueForKey:@"elevationProfile"];
    NSArray *shapePoints = [dict valueForKey:@"shapePoints"];
    
    int idx;
    NSDictionary* eitem;
    for (idx=0; idx<[elevationProfile count]; idx++)
    {
        eitem=[elevationProfile objectAtIndex:idx];
        NSNumber* height=[eitem valueForKey:@"height"];
        //NSString* distance=[eitem valueForKey:@"distance"];
        
        NSString* lat=[shapePoints objectAtIndex:idx*2];
        NSString* lng=[shapePoints objectAtIndex:idx*2+1];
        
        //TGLog(@"%@ %@ %@ %@", height, distance, lat, lng);
        
        ElevationPoint* p=[[ElevationPoint alloc] init];
        p.coordinate=CLLocationCoordinate2DMake([lat floatValue], [lng floatValue]);
        if ([height intValue]==MAPQUEST_STATUS_ELEVATION_NOT_FOUND)
        {
            p.elevation=MAPQUEST_STATUS_ELEVATION_NOT_FOUND;
        } else {
            p.elevation=[height floatValue];
        }
        
        [_results addObject:p];
        
        //NSDictionary* elevDict=[NSDictionary dictionaryWithObjectsAndKeys:lat, @"latitude", lng, @"longitude", height, @"elevation", nil];
        //[_grid addObject:elevDict];
        
        //CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([lat floatValue], [lng floatValue]);
        //[self addPin:coordinate withTitle:nil];
        
    }
    _numberOfRequestsLeftToProcess--;
    if (_numberOfRequestsLeftToProcess==0)
    {
        delegateBlock(_results);
    }
    
}


//http://open.mapquestapi.com/elevation/v1/profile?key=YOUR_KEY_HERE&callback=handleHelloWorldResponse&shapeFormat=raw&latLngCollection=39.74012,-104.9849,39.7995,-105.7237,39.6404,-106.3736
-(void) queryMapquestLocations:(NSString*)locationsString
{
    
    NSString* urlStr=[NSString stringWithFormat:MAPQUEST_ELEVATION_URL, MAPQUEST_KEY, locationsString];
#if 1
    NSString * escapedUrlString =[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
#else
    NSString * escapedUrlString =
    (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                 NULL,
                                                                 (CFStringRef)urlStr,
                                                                 NULL,
                                                                 (CFStringRef)@"!*'();@&=+$,/?%#[]",
                                                                 kCFStringEncodingUTF8 );
#endif
    
    //TGLog(@"%@", escapedUrlString);
    
    _manager = [AFHTTPRequestOperationManager manager];
    
    [_manager GET:escapedUrlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        //TGLog(@"JSON: %@", responseObject);
#if 0
        NSError * error = nil;
        NSData *data = [responseObject  dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if(dictionary==nil)
        {
            TGLog(@"%@", error);
            return;
        }
#endif
        [self MapquestResponse:responseObject];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        TGLog(@"Error: %@", error);
    }];

}

-(void) cancel
{
    TGLog(@"cancelling");
    [_manager.operationQueue cancelAllOperations];

}

@end
