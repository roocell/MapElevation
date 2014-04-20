//
//  ElevationGrid.m
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "ElevationGrid.h"
#import "ElevationRequest.h"

@interface ElevationGrid ()
@property (nonatomic, copy) ElevationGridBlock delegateBlock; // Attention: Copy the block and not retain it
@end

@implementation ElevationGrid
@synthesize delegateBlock;
@synthesize grid=_grid;

-(id) initWithCenterCoordinate:(CLLocationCoordinate2D) centerCoordinate withWidth:(float) width usingBlock:(ElevationGridBlock) delegate;
{
    if (self=[super init])
    {
        self.delegateBlock = delegate;
        _grid=[[NSMutableArray alloc] initWithCapacity:0];
        [self buildGridPoints:centerCoordinate withWidth:width];
        return self;
    }
    return nil;
}

#define RADIUS 50*1000 // m
#define PI 3.14159265
#define EARTH_RADIUS_METERS 6378100
#define GRID_POINTS_PER_ROW 32
float deg2rad(float deg)
{
	return deg*PI/180;
}
float rad2deg(float rad)
{
	return rad*180/PI;
}
float getDist(float lat1, float long1, float lat2, float long2)
{
	// haversine formula
	float dlat= lat1-lat2;
	float dlong= long1-long2;
	float a=pow( sin(deg2rad(dlat)/2) ,2) + cos(deg2rad (lat1)) * cos(deg2rad(lat2)) * pow(sin(deg2rad(dlong)/2),2);
	float c=2*atan2(sqrt(a), sqrt(1-a));
	float dist=EARTH_RADIUS_METERS*c;
	return dist;
}
-(CLLocationCoordinate2D) getDestination:(CLLocationCoordinate2D) startCoord withDistance:(float)meters andBearing:(float) bearing
{
    float lat1 = deg2rad(startCoord.latitude);
    float lng1 = deg2rad(startCoord.longitude);
    
    meters = meters/EARTH_RADIUS_METERS;
    bearing = deg2rad(bearing);
    
    float lat2 = asin( sin(lat1)*cos(meters) +
                      cos(lat1)*sin(meters)*cos(bearing) );
    float lng2 = lng1+ atan2(sin(bearing)*sin(meters)*cos(lat1),
                             cos(meters)-sin(lat1)*sin(lat2));
    lng2 = fmod((lng2+3*PI),(2*PI)) - PI;
    
    return CLLocationCoordinate2DMake(rad2deg(lat2),rad2deg(lng2));
}

-(void) buildGridPoints:(CLLocationCoordinate2D) centerCoordinate withWidth:(float) width
{
    // build a grid of coordinates around the user's position
    [_grid removeAllObjects];
    
    int scanArea=width/2;
    
    // we can query GOOGLE_ELEVATION_API_MAX_POINTS point at once.
    // if we build a region RADIUS across and an even distribution we should calculate how many rows/columns of points we want and how far apart the point are.
    int rows=GRID_POINTS_PER_ROW;
    int cols=GRID_POINTS_PER_ROW;
    float distBetweenPoints=(float)(scanArea*2)/rows;
        
    CLLocationCoordinate2D start=[self getDestination:centerCoordinate withDistance:sqrtf(powf(scanArea, 2)+powf(scanArea, 2)) andBearing:-45.0]; // top left point
    CLLocationCoordinate2D p=[self getDestination:start withDistance:distBetweenPoints andBearing:90.0]; // one point to the right
    // get the delta in lat/lng so we can easily jump to the next point.
    float delta=fabs(p.longitude-start.longitude);
    
    p.latitude=start.latitude;
    p.longitude=start.longitude;
    
    //TGLog(@"%d %f %f", rows, distBetweenPoints, delta);
    
    NSMutableArray* path=[[NSMutableArray alloc] initWithCapacity:0];
    int x,y;
    for (y=0; y<rows; y++)
    {
        for (x=0; x<cols; x++)
        {
            ElevationPoint* evp=[[ElevationPoint alloc] init];
            evp.coordinate=p;
            [path addObject:evp];
            
            p.latitude-=delta;
            
            
        }
        // go back to the start of the row
        p.latitude=start.latitude;
        p.longitude+=delta;
        
        ElevationRequest* request=[[ElevationRequest alloc] initWithQueryArray:path usingBlock:^(NSMutableArray* points)
        {
            int x,y;
            //TGLog(@"ElevationRequest complete %lu points", [points count]);
            
            [_grid addObject:points];
            
            // did we get them all ?
            if ([_grid count]>=rows)
            {
                TGLog(@"start maxima calculation");
                ElevationPoint_c cgrid[rows][cols];
                // put into C grid
                for (y=0; y<rows; y++)
                {
                    if ([_grid count]<=y)
                    {
                        TGLog(@"ERR - we dont have %d rows", GRID_POINTS_PER_ROW);
                        break;
                    }
                    NSMutableArray* row=[_grid objectAtIndex:y];
                    for (x=0; x<cols; x++)
                    {
                        if ([_grid count]<=x)
                        {
                            TGLog(@"ERR - we dont have %d columns", GRID_POINTS_PER_ROW);
                            break;
                        }
                        ElevationPoint* p=[row objectAtIndex:x];
                        cgrid[x][y].elevation=p.elevation;
                        cgrid[x][y].coordinate=p.coordinate;
                        p.row=y;
                        p.col=x;
                    }
                }
                
                // calc maxima/minima
#define ELEVATION_DELTA 0 // must be at least Xm different to consider maxima/minima
#define NEIGHBOURHOOD 5  // pick maxima at least this many points apart
                for (int l=0; l<3; l++)
                {
                    float delta=ELEVATION_DELTA*(l+1);
                    for (y=0; y<rows; y++)
                    {
                        if (y-l<0) continue;
                        if (y+l>=rows) continue;
                        NSMutableArray* row=[_grid objectAtIndex:y];
                        for (x=0; x<cols; x++)
                        {
                            if (x-l<0) continue;
                            if (x+l>=cols) continue;
                            ElevationPoint* p=[row objectAtIndex:x];
                            float a,b,c,d;
                            float z=cgrid[x][y].elevation;
                            a=cgrid[x-l][y-l].elevation;
                            b=cgrid[x][y-l].elevation;
                            c=cgrid[x+l][y].elevation;
                                //p.maxima+=1.0;
                                p.maxima+=(z-a);
                                p.maxima+=(z-b);
                                p.maxima+=(z-c);
                                p.maxima+=(z-d);
                        }
                    }
                }
                // put all points into one array so we can sort it
                NSMutableArray* sort=[[NSMutableArray alloc] initWithCapacity:0];
                for (NSMutableArray* a in _grid)
                {
                    [sort addObjectsFromArray:a];
                }
                NSArray *sortedMaxima = [sort sortedArrayUsingComparator:^NSComparisonResult(ElevationPoint* p1, ElevationPoint* p2) {
                    if (p1.maxima>p2.maxima) return NSOrderedAscending;
                    else if (p1.maxima<p2.maxima) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
                NSArray *sortedMinima = [sort sortedArrayUsingComparator:^NSComparisonResult(ElevationPoint* p1, ElevationPoint* p2) {
                    if (p1.minima>p2.minima) return NSOrderedAscending;
                    else if (p1.minima<p2.minima) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
                
                NSMutableArray* maxima=[[NSMutableArray alloc] initWithCapacity:0];
                NSMutableArray* minima=[[NSMutableArray alloc] initWithCapacity:0];
                int m=0;
#if 0 // top5 from sort
                for (m=0; m<5; m++)
                {
                    [maxima addObject:[sortedMaxima objectAtIndex:m]];
                    [minima addObject:[sortedMaxima objectAtIndex:[sortedMaxima count]-m]];
                }
#else
                while (m<5)
                {
                    for (ElevationPoint* p in sortedMaxima)
                    {
                        // make sure we dont pick a maxima near another one.
                        int near=0;
                        for (int n=0; n<m; n++)
                        {
                            ElevationPoint* mp=[maxima objectAtIndex:n];
                            if (abs(mp.row-p.row)<NEIGHBOURHOOD ||
                                abs(mp.col-p.col)<NEIGHBOURHOOD)
                            {
                                near=1;
                                break;
                            }
                        }
                        if (!near)
                        {
                            TGLog(@"maxima %f", p.maxima);
                            p.color=MKPinAnnotationColorGreen;
                           [maxima addObject:p];
                            m++;
                            break;
                        }
                    }
                }
                m=0;
                while (m<5)
                {
                    for (unsigned long q=[sortedMaxima count]-1; q>0; q--)
                    {
                        ElevationPoint* p=[sortedMaxima objectAtIndex:q];
                        // make sure we dont pick a maxima near another one.
                        int near=0;
                        for (int n=0; n<m; n++)
                        {
                            ElevationPoint* mp=[minima objectAtIndex:n];
                            if (abs(mp.row-p.row)<NEIGHBOURHOOD ||
                                abs(mp.col-p.col)<NEIGHBOURHOOD)
                            {
                                near=1;
                                break;
                            }
                        }
                        if (!near)
                        {
                            TGLog(@"minima %f", p.maxima);
                            p.color=MKPinAnnotationColorRed;
                            [minima addObject:p];
                            m++;
                            break;
                        }
                    }
                }
#endif
                //delegateBlock(sort);
                delegateBlock(maxima);
                delegateBlock(minima);
            }
            
        }];
        
        [path removeAllObjects];
    }
    


}


-(NSMutableArray*) FindLocalMaxima:(ElevationPoint_c*) cgrid
{
    NSMutableArray* maxima=[[NSMutableArray alloc] initWithCapacity:0];
    int x,y;

    
    
    return maxima;
}
-(NSMutableArray*) FindLocalMinima:(NSMutableArray*) grid
{
    NSMutableArray* minima=[[NSMutableArray alloc] initWithCapacity:0];
    return minima;
}

@end
