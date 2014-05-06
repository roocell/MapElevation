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

@end
