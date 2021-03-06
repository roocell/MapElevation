//
//  elevationViewController.m
//  MapsElevation
//
//  Created by michael russell on 2014-04-05.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "elevationViewController.h"
#import "ElevationPoint.h"
#import "CSMapAnnotation.h"
#import "CSViewAnnotationView.h"
#import "ElevationDirectionTriangle.h"
#import "MKPolygon+Attribs.h"
#import "MKPolyline+Attribs.h"

@interface elevationViewController ()

@end

@implementation elevationViewController
@synthesize mapView=_mapView;
@synthesize locationButton=_locationButton;
@synthesize roadsButton=_roadsButton;
@synthesize findSpotsButton=_findSpotsButton;
@synthesize grid=_grid;
@synthesize loader=_loader;
@synthesize roads=_roads;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self setMapOttawa:_mapView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void) addPin:(CLLocationCoordinate2D) p withTitle:(NSString*) title withSubtitle:(NSString*) sub
{
    MKPointAnnotation *point = [[MKPointAnnotation alloc] init];
    point.coordinate = p;
    if (title) point.title = title;
    if (sub) point.subtitle = sub;
    [_mapView addAnnotation:point];

    //TGLog(@"%f,%f", p.latitude, p.longitude);

}

-(int) getMapWidthInMeters
{
    MKMapRect mRect = _mapView.visibleMapRect;
    MKMapPoint eastMapPoint = MKMapPointMake(MKMapRectGetMinX(mRect), MKMapRectGetMidY(mRect));
    MKMapPoint westMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), MKMapRectGetMidY(mRect));
    
    return MKMetersBetweenMapPoints(eastMapPoint, westMapPoint);

}



-(IBAction)locationButtonPressed:(id)sender
{
    //[self showUser];
    _loader.hidden=FALSE;
    [_loader startAnimating];
    [_mapView removeAnnotations:[_mapView annotations]];
    _grid=[[ElevationGrid alloc] initWithCenterCoordinate:_mapView.centerCoordinate withWidth:[self getMapWidthInMeters]];
                         
    [_grid runUsingBlock:^(NSMutableArray* points)
     {
         //TGLog(@"ElevationGrid complete");
                  
         for (ElevationPoint* p in points)
         {
             NSString* sub=@"point";
             if (p.color==MKPinAnnotationColorGreen) sub=@"maxima";
             else if (p.color==MKPinAnnotationColorRed) sub=@"minima";
             [self addPin:p.coordinate withTitle:[NSString stringWithFormat:@"%f", p.elevation] withSubtitle:sub];
         }
         [_loader stopAnimating];
     }];

 
}

-(UIColor*) getWayColor:(NSDictionary*) way
{
    UIColor* color=[UIColor clearColor];
    NSArray* points=[way objectForKey:@"points"];
    ElevationPoint* p1=[points objectAtIndex:0];
    ElevationPoint* p2=[points objectAtIndex:[points count]-1];
#if 0
    float drop=fabs(p1.elevation-p2.elevation);
    if (drop>12.0) color=[UIColor redColor];
    else if (drop>9.0) color=[UIColor orangeColor];
    else if (drop>6.0) color=[UIColor yellowColor];
    else if (drop>3.0) color=[UIColor greenColor];
#else
    // use slope
    float dist=[[way objectForKey:@"distance"] floatValue];
    float slope=100*fabs(p1.elevation-p2.elevation)/dist;
    
    if (slope>SLOPE_RED)            color=[UIColor redColor];
    else if (slope>SLOPE_ORANGE)    color=[UIColor orangeColor];
    else if (slope>SLOPE_YELLOW)    color=[UIColor yellowColor];
    else if (slope>SLOPE_GREEN)     color=[UIColor greenColor];
    else if (slope>SLOPE_BLUE)      color=[UIColor blueColor];
    
#endif
    return color;
}

-(CLLocationCoordinate2D)midpointBetweenCoordinate:(CLLocationCoordinate2D)c1 andCoordinate:(CLLocationCoordinate2D)c2
{
    c1.latitude = deg2rad(c1.latitude);
    c2.latitude = deg2rad(c2.latitude);
    CLLocationDegrees dLon = deg2rad(c2.longitude - c1.longitude);
    CLLocationDegrees bx = cos(c2.latitude) * cos(dLon);
    CLLocationDegrees by = cos(c2.latitude) * sin(dLon);
    CLLocationDegrees latitude = atan2(sin(c1.latitude) + sin(c2.latitude), sqrt((cos(c1.latitude) + bx) * (cos(c1.latitude) + bx) + by*by));
    CLLocationDegrees longitude = deg2rad(c1.longitude) + atan2(by, cos(c1.latitude) + bx);
    
    CLLocationCoordinate2D midpointCoordinate;
    midpointCoordinate.longitude = rad2deg(longitude);
    midpointCoordinate.latitude = rad2deg(latitude);
    
    return midpointCoordinate;
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


-(void) AddArrowForWay:(NSDictionary*) way withColor:(UIColor*) color
{
    NSArray* points=[way objectForKey:@"points"];
    ElevationPoint* p1=[points objectAtIndex:0];
    ElevationPoint* p2=[points objectAtIndex:[points count]-1];
    float drop=p1.elevation-p2.elevation;

    
    // just pick a point from the array - cant use midpoint on curves
    if ([points count]>2)
    {
        p1=[points objectAtIndex:[points count]/2-1];
        p2=[points objectAtIndex:[points count]/2];
    } else {
        // dont want to use an endpoint because it gets confusing at intersections - so find middle
        p1.coordinate =[self midpointBetweenCoordinate:p1.coordinate andCoordinate:p2.coordinate];
    }
    
    float bearing=getBearing(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
    if (drop<0) bearing=fmodf(bearing+180.0, 360.0); // make it face the other way

    //TGLog(@"%lu->%lu %f %f %2.0f b:%3.0f", p1.idx, p2.idx, p1.elevation, p2.elevation, drop, bearing);

    // build triangle around midpoint

#if 0
    CSMapAnnotation* annotation = [[CSMapAnnotation alloc] initWithCoordinate:p1.coordinate
                                              annotationType:CSMapAnnotationTypeView
                                                       title:@""
                                                    subtitle:@""
                                             reuseIdentifier:@"triangle"];
    
    annotation.customView=[[ElevationDirectionTriangle alloc] initWithFrame:CGRectMake(0, 0, 30, 30) fillColor:color withBearing:bearing];
    annotation.label=@"";
    annotation.userObject=nil;
    annotation.bearing=bearing;
    [_mapView addAnnotation:annotation];
#else
    // mkpolygon overlay
    CLLocationCoordinate2D poly_coords[4];
    poly_coords[0]=[self getDestination:p1.coordinate withDistance:10.0 andBearing:bearing];

    float leftPt=fmodf(bearing-110.0, 360.0);
    float rightPt=fmodf(bearing+110.0, 360.0);
    
    poly_coords[1]=[self getDestination:p1.coordinate withDistance:10.0 andBearing:leftPt];
    poly_coords[2]=[self getDestination:p1.coordinate withDistance:10.0 andBearing:rightPt];

    poly_coords[3]=p1.coordinate;

    MKPolygon *polygon = [MKPolygon polygonWithCoordinates:poly_coords count:3];
    polygon.color=color;
    [_mapView addOverlay:polygon];
#endif
    
}
                                                 
-(float) WayDistance:(NSMutableDictionary*) way
{
    NSArray* points=[way objectForKey:@"points"];
    float dist=0;
    for (int i=0; i<[points count]-1; i++)
    {
        ElevationPoint* p1=[points objectAtIndex:i];
        ElevationPoint* p2=[points objectAtIndex:i+1];
        dist+=getDist(p1.coordinate.latitude, p1.coordinate.longitude, p2.coordinate.latitude, p2.coordinate.longitude);
    }
    [way setValue:[NSNumber numberWithFloat:dist] forKey:@"distance"];
    return dist;
}
                                          

-(IBAction)roadsButtonPressed:(id)sender
{
    _loader.hidden=FALSE;
    [_loader startAnimating];
    [_mapView removeAnnotations:[_mapView annotations]];
    [_mapView removeOverlays:[_mapView overlays]];
    
    MKMapRect mRect = self.mapView.visibleMapRect;
    MKMapPoint neMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), mRect.origin.y);
    MKMapPoint swMapPoint = MKMapPointMake(mRect.origin.x, MKMapRectGetMaxY(mRect));
    CLLocationCoordinate2D neCoord = MKCoordinateForMapPoint(neMapPoint);
    CLLocationCoordinate2D swCoord = MKCoordinateForMapPoint(swMapPoint);
    
    float dist=getDist(neCoord.latitude, neCoord.longitude, swCoord.latitude, swCoord.longitude);
    TGLog(@"%f", dist);
    
    if (MAP_ZOOM_LIMIT && dist>MAP_ZOOM_LIMIT)
    {
#if 0
        UIAlertView* alert=[[UIAlertView alloc] initWithTitle:@"Zoom in" message:[NSString stringWithFormat:@"Too large of an area (%fm). Please zoom in.", dist]
													 delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
		[alert show];
        [_loader stopAnimating];
        return;
#endif
        // auto zoom in
        
    }

    
    BoundingBox bbox;
    bbox.left=neCoord.latitude;
    bbox.right=swCoord.latitude;
    bbox.top=neCoord.longitude;
    bbox.bottom=swCoord.longitude;
    
    _roads=[[ElevationRoads alloc] initWithBoundingBox:bbox];
    [_roads runUsingBlock:^(NSMutableArray* ways)
     {
         for (NSMutableDictionary* w in ways)
         {
             NSArray* points=[w objectForKey:@"points"];

             
             float dist=[self WayDistance:w];
             
             // calculate the drop of the way
             UIColor* color=[w objectForKey:@"color"];
             if (!color) color=[self getWayColor:w];
             if (color.CGColor!=[UIColor clearColor].CGColor && dist>=MIN_WAY_DIST_TO_DISPLAY)
             {
                 [self addRoute:points withColor:color];
                 [self AddArrowForWay:w withColor:color];
             }

             //[self addPin:p1.coordinate withTitle:[NSString stringWithFormat:@"%f", p1.elevation] withSubtitle:[NSString stringWithFormat:@"S w %lu d %2.0f", [ways indexOfObject:w], 0]];
             //[self addPin:p2.coordinate withTitle:[NSString stringWithFormat:@"%f", p2.elevation] withSubtitle:[NSString stringWithFormat:@"F w %lu d %2.0f", [ways indexOfObject:w], 0]];
#if 0
             ElevationPoint* p1=[points objectAtIndex:0];
             ElevationPoint* p2=[points objectAtIndex:[points count]-1];
             int i=0;
             for (ElevationPoint* p in points)
             {
                 [self addPin:p.coordinate withTitle:[NSString stringWithFormat:@"%f", p.elevation] withSubtitle:[NSString stringWithFormat:@"w %lu %d d %2.0f", [ways indexOfObject:w], i, drop]];
                 i++;
             }
#endif
         }
         [_mapView setNeedsDisplay];
         [_loader stopAnimating];
     }];
}

-(IBAction)findSpotsButtonPressed:(id)sender
{
    
}


#pragma mark MAPVIEW
#if 0
-(void) setMapZoomForElevation
{
    MKCoordinateRegion region=MKCoordinateRegionMakeWithDistance(_mapView.centerCoordinate,
    MAP_ZOOM_LIMIT
    float spanLat=sqrtf(<#float#>)
    float spanLng;
    [self setMapWithDimensions:_mapView.userLocation.coordinate.latitude lat:_mapView.userLocation.coordinate.longitude spanLat:spanLat spanLng:spanLng];
}

-(void) setMapWithDimensions:(MKMapView*) map lat:(dou  ble)_lat lng:(double)_lng spanLat:(double)_slat spanLng:(double)_slng
{
	MKCoordinateRegion region;
	MKCoordinateSpan span;
	span.latitudeDelta=_slat;
	span.longitudeDelta=_slng;
    
	CLLocationDegrees latitude  = _lat;
	CLLocationDegrees longitude = _lng;
	CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    
	CLLocationCoordinate2D location=coordinate;
	region.span=span;
	region.center=location;
	[map setRegion:region animated:TRUE];
	[map regionThatFits:region];
}
#endif


- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{

}
-(void) setMapWithDimensions:(MKMapView*) map lat:(double)_lat lng:(double)_lng spanLat:(double)_slat spanLng:(double)_slng
{
	TGLog(@"%f,%f - %f,%f", _lat, _lng, _slat, _slng);
	MKCoordinateRegion region;
	MKCoordinateSpan span;
	span.latitudeDelta=_slat;
	span.longitudeDelta=_slng;
    
	CLLocationDegrees latitude  = _lat;
	CLLocationDegrees longitude = _lng;
	CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    
	CLLocationCoordinate2D location=coordinate;
	region.span=span;
	region.center=location;
	[map setRegion:region animated:TRUE];
	[map regionThatFits:region];
}
-(void) setMapOttawa:(MKMapView*) map
{
#define OTTAWA_LAT 45.40761
	[self setMapWithDimensions:map lat:OTTAWA_LAT lng:-75.700264 spanLat:0.20 spanLng:0.20];
}
                                                                 
-(void) showUser
{
    //MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(_mapView.userLocation.coordinate, RADIUS*2, RADIUS*2);
    //[_mapView setRegion:[_mapView regionThatFits:region] animated:YES];

    
	MKCoordinateRegion region;
	MKCoordinateSpan span;
	span.latitudeDelta=0.05;
	span.longitudeDelta=0.05;
	CLLocationCoordinate2D location=_mapView.userLocation.location.coordinate;
	region.span=span;
    
    if (_mapView.userLocation.location==nil)
    {
        [self setMapOttawa:_mapView];
    }
    
	region.center=location;
	[_mapView setRegion:region animated:TRUE];
	[_mapView regionThatFits:region];
}



- (void)mapViewDidFailLoadingMap:(MKMapView *)mapView withError:(NSError *)error
{
    TGLog(@"%@", error);
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView
{
    
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    MKAnnotationView* annotationView = nil;

	if (annotation == mapView.userLocation){
		return nil; //default to blue dot
	}

	if ([annotation respondsToSelector:@selector(annotationType)])
    {
        CSMapAnnotation* csAnnotation = (CSMapAnnotation*)annotation;
        if(csAnnotation.annotationType == CSMapAnnotationTypeView)
        {
            NSString* identifier = csAnnotation.reuseIdentifier;
            CSViewAnnotationView* vAnnotationView = [[CSViewAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
            annotationView = vAnnotationView;
            //annotationView.centerOffset = CGPointMake(0, ANNO_OFFSET); // move it up slight so the point appears on the spot
            //annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            [annotationView setEnabled:NO];
            [annotationView setCanShowCallout:NO];

            CGAffineTransform transform = CGAffineTransformMakeRotation(deg2rad(csAnnotation.bearing));
            annotationView.transform = transform;

            return annotationView;
        }
    }
    
    //create annotation
    MKPinAnnotationView *pinView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"pinView"];
    if (!pinView) {
        pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"pinView"];
        pinView.pinColor = MKPinAnnotationColorRed;
        pinView.animatesDrop = FALSE;
        pinView.canShowCallout = YES;
        
        //details button
        UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        pinView.rightCalloutAccessoryView = rightButton;
        
    } else {
        pinView.annotation = annotation;
    }
    if([annotation.subtitle isEqualToString:@"maxima"])
    {
        pinView.animatesDrop=YES;
        pinView.pinColor=MKPinAnnotationColorGreen;
        
    } else if([annotation.subtitle isEqualToString:@"minima"]) {
            pinView.animatesDrop=YES;
            pinView.pinColor=MKPinAnnotationColorRed;
    } else {
        pinView.animatesDrop=NO;
        pinView.pinColor=MKPinAnnotationColorPurple;
    }
    return pinView;
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
    
}
- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    
}
- (void)mapView:(MKMapView *)mapView didAddOverlayRenderers:(NSArray *)renderers
{
    
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:MKPolygon.class]) {
        MKPolygon* polygon=(MKPolygon*)overlay;
        MKPolygonView *polygonView = [[MKPolygonView alloc] initWithOverlay:overlay];
        polygonView.strokeColor = [UIColor clearColor];
        polygonView.lineWidth = 1;
        polygonView.fillColor = polygon.color;
        return polygonView;
    }

    if ([overlay isKindOfClass:MKPolyline.class])
    {
        MKPolyline* polyline=(MKPolyline*)overlay;
        MKPolylineView* polylineView=[[MKPolylineView alloc] initWithPolyline:polyline];
        //poly.fillColor = [UIColor redColor];
        polylineView.strokeColor = polyline.color;
        polylineView.lineWidth = 5;
        return polylineView;
    }
	return nil;
}


- (void) addRoute:(NSArray*) route withColor:(UIColor*) color
{
	// while we create the route points, we will also be calculating the bounding box of our route
	// so we can easily zoom in on it.
	MKMapPoint northEastPoint;
	MKMapPoint southWestPoint;
	
	northEastPoint.x=northEastPoint.y=0.0;
	southWestPoint.x=southWestPoint.y=0.0;
	
	// create a c array of points.
	MKMapPoint* pointArr = malloc(sizeof(MKMapPoint) * [route count]);
    ElevationPoint* p;
    int idx=0;
	for(p in route)
	{
		MKMapPoint point = MKMapPointForCoordinate(p.coordinate);
		pointArr[idx] = point;
		idx++;
	}
	
	// create the polyline based on the array of points.
    MKPolyline* routeLine=[MKPolyline polylineWithPoints:pointArr count:[route count]];
    routeLine.color=color;
	// clear the memory allocated earlier for the points
	free(pointArr);
	
	// add the overlay to the map
    [_mapView addOverlay:routeLine level:MKOverlayLevelAboveRoads];
}


@end
