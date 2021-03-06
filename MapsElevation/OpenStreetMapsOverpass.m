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
    TGLog(@"%lu ways", (unsigned long)[_ways count]);
    
    if (WAY_QUERY_LIMIT && [_ways count]>WAY_QUERY_LIMIT)
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

#if 1
    [self AdjustWaysBySlopeChange:_ways];
#else
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
        
        // TODO: we should group short ways together to decrease the number of elevation requests.
        
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
#endif
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
            
            // go through the points and add in points every WAY_DISTANCE for sections that are too long.
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
                    // the two points are too far away - need to break it up into WAY_DISTANCE sections
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
                TGLog(@"WAY %d now has %d points", wcnt, (int)[points count]);
            }
            int n_way_cnt=0;
            points=n_points;
        
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
                //TGLog(@"\tbuilding new way start %d", wp1);
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
                        TGLog(@"\tcreating a new way [%d->%d] with %d points (dist %f)", wp1, wp2, (int)[wp_points count], dist);
                        NSMutableDictionary* way=[NSMutableDictionary dictionaryWithDictionary:w];
                        [way removeObjectForKey:@"points"];
                        [way setObject:wp_points forKey:@"points"];
                        [n_ways addObject:way];
                        n_way_cnt++;
                        last_wp2=wp2;
                        wp2=(int)[points count]; // exit wp2 loop
                    }
                }
            }
            if (n_way_cnt) TGLog(@"WAY %d was broken up into %d ways", wcnt, n_way_cnt);
            else {
                TGLog(@"WAY %d ERR - didnt get broken up", wcnt);
                [n_ways addObject:w]; // add it anyways
            }
        } else {
            // no need to break it down
            TGLog(@"Way is short enough to plot %f", dist);
            [n_ways addObject:w];
        }
    }
    TGLog(@"the number of ways has changed from %d -> %d",(int)[ways count], (int)[n_ways count]);
    
    return n_ways;
}



-(UIColor*) getWayColor:(float) slope
{
    UIColor* color=[UIColor clearColor];
    
    if (slope>SLOPE_RED)            color=[UIColor redColor];
    else if (slope>SLOPE_ORANGE)    color=[UIColor orangeColor];
    else if (slope>SLOPE_YELLOW)    color=[UIColor yellowColor];
    else if (slope>SLOPE_GREEN)     color=[UIColor greenColor];
    else if (slope>SLOPE_BLUE)      color=[UIColor blueColor];
    
    return color;
}

-(void) dumpPoints:(NSArray*) points
{
    elevationAppDelegate* appdel = (elevationAppDelegate*)[[UIApplication sharedApplication] delegate];
    elevationViewController* vc=(elevationViewController*)appdel.window.rootViewController;
    for (ElevationPoint* p in points)
    {
        TGLog(@"%f,%f idx:%lu e:%f", p.coordinate.latitude, p.coordinate.longitude, p.idx, p.elevation);
        [vc addPin:p.coordinate withTitle:[NSString stringWithFormat:@"%lu e:%2.0f", p.idx, p.elevation] withSubtitle:nil];
    }
}

// go through the ways and break them up when the slope changes.
-(void) AdjustWaysBySlopeChange:(NSMutableArray*) ways
{
    elevationAppDelegate* appdel = (elevationAppDelegate*)[[UIApplication sharedApplication] delegate];
    elevationViewController* vc=(elevationViewController*)appdel.window.rootViewController;
    
    TGLog(@"%d ways", (int)[ways count]);
    int wcnt=0;
    for (NSMutableDictionary* w in ways)
    {
        wcnt++;
        NSMutableArray* points=[w objectForKey:@"points"];
        ElevationPoint* p1;
        ElevationPoint* p2;
        ElevationPoint* p3;
        
        p1=[points objectAtIndex:0];
        
        TGLog(@"WAY %d with %d points", wcnt, (int)[points count]);
        
        // for longer ways - we need to insert points for the frequency we want to evalutate the slope change
        // ie - how short of a distance we care to figure out if the slope has changed or not.
        
        // go through the points and add in points every 50m for sections that are too long.
        NSMutableArray* n_points=[NSMutableArray array];
        [n_points addObject:p1];
        for (int wp=0; wp<[points count]-1; wp++)
        {
            p1=[points objectAtIndex:wp];
            p2=[points objectAtIndex:wp+1];
            
            float dist=getDist(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
            if (dist>SLOPE_CHANGE_EVAL_DIST)
            {
                TGLog(@"section %d needs to be broken up (%fm)", wp, dist);
                TGLog(@"\t start pt %f,%f idx %lu", p1.coordinate.latitude, p1.coordinate.longitude, p1.idx);
                // the two points are too far away - need to break it up into WAY_DISTANCE sections
                int sections=dist/SLOPE_CHANGE_EVAL_DIST;
                float bearing=getBearing(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
                TGLog(@"\tbreaking way section %d into %d %5.0fm parts (bearing %f)", wp, sections, SLOPE_CHANGE_EVAL_DIST, bearing);
                for (int s=0; s<sections; s++)
                {
                    // reuse p1
                    if (s>0) p1=p3;
                    p3=[[ElevationPoint alloc] init];
                    p3.coordinate=[self getDestination:p1.coordinate withDistance:SLOPE_CHANGE_EVAL_DIST andBearing:bearing];
                    p3.idx=[n_points count]; // required to maintain order in elev req
                    TGLog(@"\t new pt idx %lu %f,%f", p3.idx, p3.coordinate.latitude, p3.coordinate.longitude);
                    [n_points addObject:p3];
                    //[vc addPin:p3.coordinate withTitle:[NSString stringWithFormat:@"W %d, %lu", wcnt, [n_points count]] withSubtitle:nil];
                }
                // sections were up to before the last point - so we have to add it.
                p2.idx=[n_points count]; // required to maintain order in elev req
                [n_points addObject:p2];
                //[vc addPin:p2.coordinate withTitle:[NSString stringWithFormat:@"W %d, %lu", wcnt, [n_points count]] withSubtitle:nil];
            } else {
                //TGLog(@"section %d is short enough %f", wp, dist);
                p2.idx=[n_points count]; // required to maintain order in elev req
                [n_points addObject:p2];
                //[vc addPin:p2.coordinate withTitle:[NSString stringWithFormat:@"W %d, %lu", wcnt, [n_points count]] withSubtitle:nil];
            }
        }
        
        if ([n_points count]!=[points count])
        {
            TGLog(@"WAY %d points %lu->%lu", wcnt, [points count], [n_points count]);
        }
        [w removeObjectForKey:@"points"];
        [w setObject:n_points forKey:@"points"];
        
        //[self dumpPoints:n_points];
    } // end of inserting points into ways

    TGLog(@"=========================");
    TGLog(@"====STARTING ELEV REQ====");
    TGLog(@"=========================");
    
    __block int e_wcnt=0;
    __block NSMutableArray* n_ways=[NSMutableArray array];
    for (__block NSMutableDictionary* ew in ways)
    {
        // get elevation data
        NSMutableArray* epoints=[ew objectForKey:@"points"];
        TGLog(@"getting elevation for way %lu (%lu points)", [_ways indexOfObject:ew]+1, [epoints count]);
        ElevationRequest* evr=[[ElevationRequest alloc] initWithQueryArray:epoints usingBlock:^(NSMutableArray* points)
         {
            int n_way_cnt=0;
             ElevationPoint* bp1;
             ElevationPoint* bp2;
             
             e_wcnt++;
             // update our waypoints
             TGLog(@"rx elev for way %d (%lu points)", e_wcnt, [points count]);
             

             // double check that it's the right way
             if ([points count]!=[[ew objectForKey:@"points"] count])
             {
                 TGLog(@"ERR %lu<>%lu", [points count], [[ew objectForKey:@"points"] count]);
                 return;
             }
             
             [ew setValue:points forKeyPath:@"points"];
             
             
             // go through points and build new ways where the slope changes levels
             // there will be some with multiple points
             //    - these were from the original way and are for things like tight curves
             // then there will be some with just 2 points
             //    - these are from the above loops where we create sections
             int last_wp2=0;
             UIColor* prev_color=[UIColor clearColor];
             for (int wp1=0; wp1<[points count]; wp1++)
             {
                 if (last_wp2) wp1=last_wp2; // restart wp1 loop at wp2
                 last_wp2=0;
                 
                 NSMutableArray* wp_points=[NSMutableArray array];
                 bp1=[points objectAtIndex:wp1];
                 [wp_points addObject:bp1];
                 //TGLog(@"\tbuilding new way start %d", wp1);
                 for (int wp2=wp1+1; wp2<[points count]; wp2++)
                 {
                     bp2=[points objectAtIndex:wp2];
                     [wp_points addObject:bp2];
                     
                     // have we reached the end of the way?
                     // OR
                     // has the slope changed levels (must be at least a certain length)
                     float dist=getDist(bp1.coordinate.latitude, bp1.coordinate.longitude, bp2.coordinate.latitude, bp2.coordinate.longitude);
                     float slope=100*fabs(bp1.elevation-bp2.elevation)/dist;
                     
                     //TGLog(@"%lu-%lu %f %f %f %f", bp1.idx, bp2.idx, bp1.elevation, bp2.elevation, dist, slope);
                     
                     UIColor* color=[self getWayColor:slope];
                     if ( (color.CGColor != prev_color.CGColor &&
                           dist > MIN_WAY_DIST_TO_DISPLAY)
                         || wp2>=[points count]-1)
                     {
                         // build way
                         TGLog(@"\tnew way[%lu->%lu] %d:pts d:%2.0f s:%2.0f", bp1.idx, bp2.idx, (int)[wp_points count], dist, slope);
                         
#if 0
                         NSArray *rr = [wp_points sortedArrayUsingComparator:^NSComparisonResult(ElevationPoint* p1, ElevationPoint* p2) {
                             if (p1.idx>p2.idx) return NSOrderedAscending;
                             else if (p1.idx<p2.idx) return NSOrderedDescending;
                             return NSOrderedSame;
                         }];
#endif
                         //[self dumpPoints:wp_points];

                         
                         NSMutableDictionary* way=[NSMutableDictionary dictionaryWithDictionary:ew];
                         [way removeObjectForKey:@"points"];
                         [way setObject:wp_points forKey:@"points"];
                         [way setObject:[NSNumber numberWithFloat:slope] forKey:@"slope"];
                         [way setObject:color forKey:@"color"];
                         
                         prev_color=color;
                         [n_ways addObject:way];
                         n_way_cnt++;
                         last_wp2=wp2;

                         wp2=(int)[points count]; // exit wp2 loop
                     }
                 }
             }
             if (n_way_cnt>1) TGLog(@"WAY %d/%d was broken up into %d ways", e_wcnt, (int)[_ways count], n_way_cnt);
             else {
                 TGLog(@"WAY %d/%d - didnt get broken up", e_wcnt, (int)[_ways count]);
                 [n_ways addObject:ew]; // add it back
             }
             
             
             
             
             
             
             // did we get the last request?
             if (e_wcnt>=[_ways count])
             {
                 //TGLog(@"got last request");
                 TGLog(@"the number of ways has changed from %d -> %d",(int)[ways count], (int)[n_ways count]);
                 delegateBlock(n_ways);
             }
             
             
         }];
        [_requests addObject:evr];
        
        
    }
    
}

@end
