//
//  elevationViewController.m
//  MapsElevation
//
//  Created by michael russell on 2014-04-05.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "elevationViewController.h"
#import "ElevationPoint.h"

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
@synthesize routeLines=_routeLines;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    _routeLines=[NSMutableArray array];
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

-(IBAction)roadsButtonPressed:(id)sender
{
    _loader.hidden=FALSE;
    [_loader startAnimating];
    [_mapView removeAnnotations:[_mapView annotations]];

    
    MKMapRect mRect = self.mapView.visibleMapRect;
    MKMapPoint neMapPoint = MKMapPointMake(MKMapRectGetMaxX(mRect), mRect.origin.y);
    MKMapPoint swMapPoint = MKMapPointMake(mRect.origin.x, MKMapRectGetMaxY(mRect));
    CLLocationCoordinate2D neCoord = MKCoordinateForMapPoint(neMapPoint);
    CLLocationCoordinate2D swCoord = MKCoordinateForMapPoint(swMapPoint);
    
    float width=fabs(neCoord.latitude-swCoord.latitude);
    TGLog(@"%f", width);
    
    if (width>0.02)
    {
        UIAlertView* alert=[[UIAlertView alloc] initWithTitle:@"Zoom in" message:[NSString stringWithFormat:@"Too large of an area (%f). Please zoom in.", width]
													 delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
		[alert show];
        [_loader stopAnimating];
        return;
    }

    
    BoundingBox bbox;
    bbox.left=neCoord.latitude;
    bbox.right=swCoord.latitude;
    bbox.top=neCoord.longitude;
    bbox.bottom=swCoord.longitude;
    
    _roads=[[ElevationRoads alloc] initWithBoundingBox:bbox];
    [_roads runUsingBlock:^(NSMutableArray* ways)
     {
         for (NSDictionary* w in ways)
         {
             NSArray* points=[w objectForKey:@"points"];
             
             // calculate the drop of the way
             ElevationPoint* p1=[points objectAtIndex:0];
             ElevationPoint* p2=[points objectAtIndex:[points count]-1];
             float drop=fabs(p1.elevation-p2.elevation);
             UIColor* color=[UIColor blueColor];
             if (drop>1) color=[UIColor greenColor];
             else if (drop>2) color=[UIColor yellowColor];
             else if (drop>3) color=[UIColor orangeColor];
             else if (drop>4) color=[UIColor redColor];
             
             [self addRoute:points withColor:color];
             [_mapView setNeedsDisplay];

#if 1
             int i=0;
             for (ElevationPoint* p in points)
             {
                 [self addPin:p.coordinate withTitle:[NSString stringWithFormat:@"%f", p.elevation] withSubtitle:[NSString stringWithFormat:@"%d", i]];
                 i++;
             }
#endif
         }
         [_loader stopAnimating];
     }];
}

-(IBAction)findSpotsButtonPressed:(id)sender
{
    
}


#pragma mark MAPVIEW
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
	MKOverlayView* overlayView = nil;

    // TODO: is there a more efficient way to do this?
    // like not cache the polyline view?
	for (NSMutableDictionary* d in _routeLines)
    {
        MKPolyline* routeLine=[d objectForKey:@"line"];
        if(overlay == routeLine)
        {
            //if we have not yet created an overlay view for this overlay, create it now.
            overlayView=[d objectForKey:@"view"];
            if(overlayView==nil)
            {
                MKPolylineView* poly=[[MKPolylineView alloc] initWithPolyline:routeLine];
                //poly.fillColor = [UIColor redColor];
                poly.strokeColor = [d objectForKey:@"color"];
                poly.lineWidth = 5;
                [d setValue:poly forKey:@"view"];
                overlayView=[d objectForKey:@"view"];
            }
        }
    }
	return overlayView;
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
    NSMutableDictionary* d=[NSMutableDictionary dictionary];
    [d setValue:routeLine forKey:@"line"];
    [d setValue:color forKey:@"color"];
    [_routeLines addObject:d];
	    
	// clear the memory allocated earlier for the points
	free(pointArr);
	
	// add the overlay to the map
    [_mapView addOverlay:routeLine level:MKOverlayLevelAboveRoads];
}


@end
