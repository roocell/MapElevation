//
//  ElevationGrid.m
//  MapsElevation
//
//  Created by michael russell on 2014-04-19.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "ElevationGrid.h"

@interface ElevationGrid ()
@property (nonatomic, copy) ElevationGridBlock delegateBlock; // Attention: Copy the block and not retain it
@end

@implementation ElevationGrid
@synthesize delegateBlock;
@synthesize grid=_grid;
@synthesize requests=_requests;
@synthesize centerCoordinate=_centerCoordinate;
@synthesize width=_width;

-(id) initWithCenterCoordinate:(CLLocationCoordinate2D) centerCoordinate withWidth:(float) width;
{
    if (self=[super init])
    {
        _grid=[[NSMutableArray alloc] initWithCapacity:0];
        _requests=[[NSMutableArray alloc] initWithCapacity:0];
        _centerCoordinate=centerCoordinate;
        _width=width;
        
        return self;
    }
    return nil;
}

-(void) runUsingBlock:(ElevationGridBlock) delegate
{
    self.delegateBlock = delegate;
    [self buildGridPoints:_centerCoordinate withWidth:_width];
}

#define RADIUS 50*1000 // m
#define GRID_POINTS_PER_ROW 32

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

-(void) buildGridPoints:(CLLocationCoordinate2D) centerCoordinate withWidth:(float) width
{
    // build a grid of coordinates around the user's position
    [_grid removeAllObjects];
    ElevationRequest* evr;
    TGLog(@"cancelling...%lu", [_requests count]);
    for (evr in _requests)
    {
        TGLog(@"cancelling...%@", evr);
        if (evr) [evr cancel];
    }
    [_requests removeAllObjects];
    
    TGLog(@"Starting SCAN ....[%f,%f]", centerCoordinate.latitude, centerCoordinate.longitude);
    
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
        
        evr=[[ElevationRequest alloc] initWithQueryArray:path usingBlock:^(NSMutableArray* points)
        {
            int x,y;
            //TGLog(@"ElevationRequest complete %lu points", [points count]);
            
            // points need to be in order of latitude.
            NSArray *sortedLatitude = [points sortedArrayUsingComparator:^NSComparisonResult(ElevationPoint* p1, ElevationPoint* p2) {
                if (p1.coordinate.latitude>p2.coordinate.latitude) return NSOrderedAscending;
                else if (p1.coordinate.latitude<p2.coordinate.latitude) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            
            [_grid addObject:sortedLatitude];
            
            // did we get them all ?
            if ([_grid count]>=rows)
            {
                // the grid needs to be sorted by longitude
                NSArray *sortedLongitude = [_grid sortedArrayUsingComparator:^NSComparisonResult(NSMutableArray* arr1, NSMutableArray* arr2) {
                    ElevationPoint* p1=[arr1 objectAtIndex:0];
                    ElevationPoint* p2=[arr2 objectAtIndex:0];
                    if (p1.coordinate.longitude>p2.coordinate.longitude) return NSOrderedAscending;
                    else if (p1.coordinate.longitude<p2.coordinate.longitude) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
                [_grid removeAllObjects];
                [_grid addObjectsFromArray:sortedLongitude];
                
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
                        if ([row count]<=x)
                        {
                            TGLog(@"ERR - we dont have %d columns", GRID_POINTS_PER_ROW);
                            cgrid[x][y].elevation=MAPQUEST_STATUS_ELEVATION_NOT_FOUND;
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
                for (int l=1; l<=3; l++)
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
                            float rt,rr,rb,bb,lb,ll,lt,tt, z;
                            
                            // all points around z
                            
#if 0
                            // DEBUG sanity check that coords are in order x,y
                            if (cgrid[x][y+l].coordinate.longitude > cgrid[x][y].coordinate.longitude) TGLog(@"ERR %d %d lng+", x, y);
                            if (cgrid[x][y-l].coordinate.longitude < cgrid[x][y].coordinate.longitude) TGLog(@"ERR %d %d lng-", x, y);
                            if (cgrid[x+1][y].coordinate.latitude > cgrid[x][y].coordinate.latitude) TGLog(@"ERR %d %d lat+", x, y);
                            if (cgrid[x-1][y].coordinate.latitude < cgrid[x][y].coordinate.latitude) TGLog(@"ERR %d %d lat-", x, y);
#endif
                            
                            z=cgrid[x][y].elevation;
                            if (z==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;
                            
                            rt=cgrid[x+l][y+l].elevation;
                            if (rt==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;
                            rr=cgrid[x+l][y].elevation;
                            if (rr==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;
                            rb=cgrid[x+l][y-l].elevation;
                            if (rb==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;

                            lt=cgrid[x-l][y+l].elevation;
                            if (lt==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;
                            ll=cgrid[x-l][y-l].elevation;
                            if (ll==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;
                            lb=cgrid[x-1][y-l].elevation;
                            if (lb==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;

                            bb=cgrid[x][y-l].elevation;
                            if (bb==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;
                            tt=cgrid[x][y+l].elevation;
                            if (tt==MAPQUEST_STATUS_ELEVATION_NOT_FOUND) continue;

                            
                                //p.maxima+=1.0;
                                p.maxima+=(z-rt);
                                p.maxima+=(z-rr);
                                p.maxima+=(z-rb);
                            
                                p.maxima+=(z-lt);
                                p.maxima+=(z-ll);
                                p.maxima+=(z-lb);
                            
                                p.maxima+=(z-bb);
                                p.maxima+=(z-tt);
                            
                            //TGLog(@"[%f,%f][%d,%d,%d] z %7.1f %7.1f,%7.1f,%7.1f,%7.1f,%7.1f,%7.1f,%7.1f,%7.1f m %7.1f", cgrid[x][y].coordinate.latitude, cgrid[x][y].coordinate.longitude, x,y,l,z, rt,rr,rb,lt,ll,lb,bb,tt,p.maxima);
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
                    //TGLog(@"%f<>%f", p1.maxima, p2.maxima);
                    if (p1.maxima>p2.maxima) return NSOrderedAscending;
                    else if (p1.maxima<p2.maxima) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
#if 0
                NSArray *sortedMinima = [sort sortedArrayUsingComparator:^NSComparisonResult(ElevationPoint* p1, ElevationPoint* p2) {
                    if (p1.minima>p2.minima) return NSOrderedAscending;
                    else if (p1.minima<p2.minima) return NSOrderedDescending;
                    return NSOrderedSame;
                }];
#endif
                
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
                            TGLog(@"maxima %f elev %f [%f,%f]", p.maxima, p.elevation, p.coordinate.latitude, p.coordinate.longitude);
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
                            TGLog(@"minima %f elev %f [%f,%f]", p.maxima, p.elevation, p.coordinate.latitude, p.coordinate.longitude);
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
        [_requests addObject:evr];
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
