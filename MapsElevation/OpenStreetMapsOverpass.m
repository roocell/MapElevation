//
//  OpenStreetMapsOverpass.m
//  MapsElevation
//
//  Created by michael russell on 2014-05-04.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

// http://www.overpass-api.de/api/xapi?node[bbox=-0.489,51.28,0.236,51.686][highway=*]
// http://www.overpass-api.de/api/xapi?node%5Bbbox=-75.728,45.379,-75.724,45.375%5D%5Bhighway=*%5D

//http://www.overpass-api.de/api/xapi?node[bbox=45.359333,-75.727859,45.355202,-75.724426][highway=*]
//http://www.overpass-api.de/api/xapi?node%5Bbbox=51.508675,-0.040252,51.505016,-0.036819%5D%5Bhighway=*%5D

#import "OpenStreetMapsOverpass.h"
#import "ElevationPoint.h"
#import "ElevationRequest.h"

#import "elevationAppDelegate.h"
#import "elevationViewController.h"

//#define WAY_TAGS 1

@interface OpenStreetMapsOverpass ()
@property (nonatomic, copy) OpenStreetMapsOverpassBlock delegateBlock; // Attention: Copy the block and not retain it
@end

@implementation OpenStreetMapsOverpass

@synthesize delegateBlock;
@synthesize bbox=_bbox;
@synthesize manager=_manager;
@synthesize nodes=_nodes;
@synthesize currentNode=_currentNode;
@synthesize ways=_ways;
@synthesize currentWay=_currentWay;
@synthesize requests=_requests;

#define OSM_OVERPASS_URL @"http://www.overpass-api.de/api/xapi?way[bbox=%f,%f,%f,%f][highway=*]"

-(id) initWithBoundingBox:(BoundingBox) bbox
{
    if (self=[super init])
    {
        _bbox=bbox;
        _currentNode=nil;
        _currentWay=nil;
        _requests=[[NSMutableArray alloc] initWithCapacity:0];
        return self;
    }
    return nil;
    
}

#pragma mark NSXMLParser Delegate Methods
// http://www.raywenderlich.com/59255/afnetworking-2-0-tutorial
- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    _nodes = [NSMutableArray array];
    _ways = [NSMutableArray array];
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    //TGLog(@"%@ %@", qName, attributeDict);
    if ([qName isEqualToString:@"node"])
    {
        if (_currentNode) [_nodes addObject:_currentNode];
        _currentNode=[NSMutableDictionary dictionary];
        [_currentNode addEntriesFromDictionary:attributeDict];
    } else if ([qName isEqualToString:@"way"]) {
        if (_currentNode) [_nodes addObject:_currentNode]; // add the last node
        if (_currentWay) [_ways addObject:_currentWay];
        _currentWay=[NSMutableDictionary dictionary];
        [_currentWay setObject:[NSMutableArray array] forKey:@"points"];
    } else if ([qName isEqualToString:@"nd"]) {
        // find the node
        for (NSDictionary* n in _nodes)
        {
            if ([[n objectForKey:@"id"] isEqualToString:[attributeDict objectForKey:@"ref"]])
            {
                NSMutableArray* waynodes=[_currentWay objectForKey:@"points"];
                ElevationPoint* p=[[ElevationPoint alloc] init];
                p.coordinate=CLLocationCoordinate2DMake([[n objectForKey:@"lat"] floatValue], [[n objectForKey:@"lon"] floatValue]);
                p.idx=[waynodes count];
                //[waynodes setObject:p atIndexedSubscript:[waynodes count]]; // to force in order?
                [waynodes addObject:p];
            }
        }
    }
#ifdef WAY_TAGS
    else if ([qName isEqualToString:@"tag"]) {
        NSDictionary* d=[NSDictionary dictionaryWithObjectsAndKeys:[attributeDict objectForKey:@"v"],
                         [attributeDict objectForKey:@"k"], nil];
        [_currentWay addEntriesFromDictionary:d];
    }
#endif
   
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
}

- (void) parserDidEndDocument:(NSXMLParser *)parser
{
    if (_currentWay) [_ways addObject:_currentWay]; // add the last way
    TGLog(@"%lu ways", [_ways count]);
    
    if ([_ways count]>128)
    {
        UIAlertView* alert=[[UIAlertView alloc] initWithTitle:@"Zoom in" message:[NSString stringWithFormat:@"Too many paths (%lu) for this area. Please zoom in.",[_ways count]]
													 delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
		[alert show];
        return;
    }

    // cancel previous requests
    ElevationRequest* evr;
    TGLog(@"cancelling...%lu", [_requests count]);
    for (evr in _requests)
    {
        TGLog(@"cancelling...%@", evr);
        if (evr) [evr cancel];
    }
    [_requests removeAllObjects];

    _ways=[self AdjustWays:_ways];
    
    // spawn off some elevation requests
    // two ways to do this
    // 1. loops through ways and get elevations
    // 2. get elevations for all the nodes - then populate the ways
    __block int wcnt=0;
    for (__block NSDictionary* w in _ways)
    {
        NSMutableArray* waypoints=[w objectForKey:@"points"];
        
        TGLog(@"getting elevation for way %lu (%lu points)", [_ways indexOfObject:w], [waypoints count]);
        if ([waypoints count]<=0)
        {
            TGLog(@"not waypoints for way %lu (%lu points)", [_ways indexOfObject:w], [waypoints count]);
            continue;
        }
        
        evr=[[ElevationRequest alloc] initWithQueryArray:waypoints usingBlock:^(NSMutableArray* points)
        {
            wcnt++;
            // update our waypoints
            //TGLog(@"received points for way %lu", [_ways indexOfObject:w]);
            [w setValue:points forKeyPath:@"points"];
            
            // did we get the last request?
            if (wcnt>=[_ways count])
            {
                //TGLog(@"got last request");
                delegateBlock(_ways);
            }

            
        }];
        [_requests addObject:evr];


    }
    
}


-(void) runUsingBlock:(OpenStreetMapsOverpassBlock) delegate
{
    self.delegateBlock=delegate;
    
    NSString* urlStr=[NSString stringWithFormat:OSM_OVERPASS_URL, _bbox.bottom, _bbox.right, _bbox.top, _bbox.left];
    NSString * escapedUrlString =[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    TGLog(@"%@", escapedUrlString);
    _manager = [AFHTTPRequestOperationManager manager];
    _manager.responseSerializer = [AFXMLParserResponseSerializer serializer];
    _manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/osm3s+xml"];
    
    [_manager GET:escapedUrlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject)
    {
        // we have to do the XML parsing ourselves
        NSXMLParser* xmlparser=(NSXMLParser*)responseObject;
        [xmlparser setShouldProcessNamespaces:YES];
        xmlparser.delegate = self;
        [xmlparser parse];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        TGLog(@"Error: %@", error);
    }];

}

-(CLLocationCoordinate2D) getDestination:(CLLocationCoordinate2D) startCoord withDistance:(float)meters andBearing:(float) bearing
{
    float lat1 = deg2rad(startCoord.latitude);
    float lng1 = deg2rad(startCoord.longitude);
    
    meters = meters/EARTH_RADIUS_M;
    bearing = deg2rad(bearing);
    
    float lat2 = asin( sin(lat1)*cos(meters) +
                      cos(lat1)*sin(meters)*cos(bearing) );
    float lng2 = lng1+ atan2(sin(bearing)*sin(meters)*cos(lat1),
                             cos(meters)-sin(lat1)*sin(lat2));
    lng2 = fmod((lng2+3*PI),(2*PI)) - PI;
    
    return CLLocationCoordinate2DMake(rad2deg(lat2),rad2deg(lng2));
}


// This will find ways that exceed WAY_DISTANCE and replace them
// with smaller ways.
// We want to do this because sometimes a way coming back from overpass
// can be very long and taking the drop (slope) from that way and colouring it
// will produce undesired colouring.

#define WAY_DISTANCE 250.0 // meters
-(NSMutableArray*) AdjustWays:(NSMutableArray*) ways
{
    elevationAppDelegate* appdel = (elevationAppDelegate*)[[UIApplication sharedApplication] delegate];
    elevationViewController* vc=(elevationViewController*)appdel.window.rootViewController;
    
    NSMutableArray* n_ways=[NSMutableArray array];
    TGLog(@"%d ways", (int)[ways count]);
    int wcnt=0;
    for (NSDictionary* w in ways)
    {
        wcnt++;
        NSArray* points=[w objectForKey:@"points"];
        ElevationPoint* p1;
        ElevationPoint* p2;
        ElevationPoint* p3;
        
        p1=[points objectAtIndex:0];
        p2=[points objectAtIndex:[points count]-1];
        
        TGLog(@"WAY %d with %d points", wcnt, (int)[points count]);
        
        // sometimes the way can be very long - we need to break it down into smaller chunks.
        float dist=getDist(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
        if (dist>WAY_DISTANCE)
        {
            TGLog(@"way %d is too long %f - break it up. %d points", wcnt, dist, (int)[points count]);
            
            // go through the points and add in points every 50m for sections that are too long.
            NSMutableArray* n_points=[NSMutableArray array];
            [n_points addObject:[points objectAtIndex:0]];
            for (int wp=0; wp<[points count]-1; wp++)
            {
                p1=[points objectAtIndex:wp];
                p2=[points objectAtIndex:wp+1];
                
                dist=getDist(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
                if (dist>WAY_DISTANCE)
                {
                    TGLog(@"section %d needs to be broken up (%fm)", wp, dist);
                    TGLog(@"\t start pt %f,%f", p1.coordinate.latitude, p1.coordinate.longitude);
                    // the two points are too far away - need to break it up into 50m sections
                    int sections=dist/WAY_DISTANCE+1;
                    float bearing=getBearing(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
                    TGLog(@"\tbreaking way section %d into %d %5.0fm parts (bearing %f)", wp, sections, WAY_DISTANCE, bearing);
                    for (int s=0; s<sections; s++)
                    {
                        p3=[[ElevationPoint alloc] init];
                        p3.coordinate=[self getDestination:p1.coordinate withDistance:WAY_DISTANCE andBearing:bearing];
                        TGLog(@"\t new pt %f,%f", p3.coordinate.latitude, p3.coordinate.longitude);
                        [n_points addObject:p3];
                        //[vc addPin:p3.coordinate withTitle:[NSString stringWithFormat:@"W %d, s %d", wcnt, s] withSubtitle:nil];
                    }
                    // sections were up to before the last point - so we have to add it.
                    [n_points addObject:p2];
                } else {
                    //TGLog(@"section %d is short enough %f", wp, dist);
                    [n_points addObject:p2];
                }
            }
            // we only have to rebuild the way if the number of points has changed.
            if ([n_points count]!=[points count])
            {
                points=n_points;
                TGLog(@"WAY %d now has %d points", wcnt, (int)[points count]);
                
                // go through points and build new ways.
                // there will be some with multiple points
                //    - these were from the original way and are for things like tight curves
                // then there will be some with just 2 points
                //    - these are from the above loops where we create sections
                int last_wp2=0;
                for (int wp1=0; wp1<[points count]; wp1++)
                {
                    if (last_wp2) wp1=last_wp2; // restart wp1 loop at wp2
                    last_wp2=0;

                    NSMutableArray* wp_points=[NSMutableArray array];
                    p1=[points objectAtIndex:wp1];
                    [wp_points addObject:p1];
                    TGLog(@"building new way start %d", wp1);
                    for (int wp2=wp1+1; wp2<[points count]; wp2++)
                    {
                        p2=[points objectAtIndex:wp2];
                        [wp_points addObject:p2];
                        if (wp2<[points count]-1) p3=[points objectAtIndex:wp2+1]; // next point
                        else p3=p2; // if it's the last one - use this distance.
                        
                        // is the next point long enough or have we reached the end of the way?
                        dist=getDist(p1.coordinate.latitude, p1.coordinate.longitude, p3.coordinate.latitude, p3.coordinate.longitude);
                        if (dist>=WAY_DISTANCE || wp2>=[points count]-1)
                        {
                            // build way
                            TGLog(@"creating a new way [%d->%d] with %d points (dist %f)", wp1, wp2, (int)[wp_points count], dist);
                            NSMutableDictionary* way=[NSMutableDictionary dictionaryWithDictionary:w];
                            [way removeObjectForKey:@"points"];
                            [way setObject:wp_points forKey:@"points"];
                            [n_ways addObject:way];
                            
                            last_wp2=wp2;
                            wp2=(int)[points count]; // exit wp2 loop
                        }
                    }
                }
            } else {
                TGLog(@"WAY %d is ok - we can continue using the original way", wcnt);
                [n_ways addObject:w];
            }
        } else {
            // no need to break it down
            TGLog(@"Way is short enough to plot %f", dist);
            [n_ways addObject:w];
        }
    }
    TGLog(@"the number of ways has changed from %d -> %d", (int)[ways count], (int)[n_ways count]);
    
    return n_ways;
}

@end
