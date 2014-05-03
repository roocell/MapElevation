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
@synthesize findSpotsButton=_findSpotsButton;
@synthesize grid=_grid;
@synthesize data=_data;
@synthesize top5=_top5;
@synthesize routes=_routes;
@synthesize loader=_loader;

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
     }];

 
}

-(IBAction)top5ButtonPressed:(id)sender
{
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

@end
