//
//  elevationViewController.h
//  MapsElevation
//
//  Created by michael russell on 2014-04-05.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "ElevationGrid.h"
#import "ElevationRoads.h"

@interface elevationViewController : UIViewController <MKMapViewDelegate>
@property (retain, nonatomic) IBOutlet MKMapView* mapView;
@property (retain, nonatomic) IBOutlet UIButton* locationButton;  // will locate user and query google with grid
@property (retain, nonatomic) IBOutlet UIButton* roadsButton;
@property (retain, nonatomic) IBOutlet UIButton* findSpotsButton;

@property (retain, nonatomic) IBOutlet UIActivityIndicatorView* loader;
@property (retain, nonatomic) ElevationGrid* grid;
@property (retain, nonatomic) ElevationRoads* roads;


-(IBAction)locationButtonPressed:(id)sender;
-(IBAction)roadsButtonPressed:(id)sender;
-(IBAction)findSpotsButtonPressed:(id)sender;

-(void) addPin:(CLLocationCoordinate2D) p withTitle:(NSString*) title withSubtitle:(NSString*) sub;

@end
