//
//  OpenStreetMapsOverpass.h
//  MapsElevation
//
//  Created by michael russell on 2014-05-04.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

//Check out the Overpass API with the XAPI compatibility layer for getting data from the OpenStreetMap database with RESTful requests.
//The full documentation is here: http://wiki.openstreetmap.org/wiki/Overpass_API/XAPI_Compatibility_Layer
//To get all the roads in a bounding box, your request URL would look like this:
//http://www.overpass-api.de/api/xapi?way[bbox=7.1,51.2,7.2,51.3]

// http://wiki.openstreetmap.org/wiki/Map_Features#Roads
// http://wiki.openstreetmap.org/wiki/Bounding_box

// this is for greater London (12MB)
// http://www.overpass-api.de/api/xapi?node[bbox=-0.489,51.28,0.236,51.686][highway=*]
// http://www.overpass-api.de/api/xapi?node[bbox=-0.489,51.28,0.490,51.29][highway=*]


#import <Foundation/Foundation.h>
#import "AFHTTPRequestOperationManager.h"

typedef struct {
    float left;
    float bottom;
    float right;
    float top;
} BoundingBox;



typedef void (^OpenStreetMapsOverpassBlock)(NSMutableArray*);


@interface OpenStreetMapsOverpass : NSObject <NSXMLParserDelegate>
{
@protected OpenStreetMapsOverpassBlock delegateBlock;
}
@property BoundingBox bbox;
@property (nonatomic, retain) AFHTTPRequestOperationManager *manager;
@property (nonatomic, retain) NSMutableDictionary *currentNode; 
@property (nonatomic, retain) NSMutableDictionary *currentWay; // an array of nodes, and a dictionary of tags
@property (nonatomic, retain) NSMutableArray *nodes;
@property (nonatomic, retain) NSMutableArray *ways;
@property (retain, nonatomic) NSMutableArray* requests; // an array of ElevationRequest

-(id) initWithBoundingBox:(BoundingBox) bbox;
-(void) runUsingBlock:(OpenStreetMapsOverpassBlock) delegate;

@end
