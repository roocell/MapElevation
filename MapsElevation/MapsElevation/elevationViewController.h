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

@interface elevationViewController : UIViewController <MKMapViewDelegate>
@property (retain, nonatomic) IBOutlet MKMapView* mapView;
@property (retain, nonatomic) IBOutlet UIButton* locationButton;  // will locate user and query google with grid
@property (retain, nonatomic) IBOutlet UIButton* top5Button;
@property (retain, nonatomic) IBOutlet UIButton* findSpotsButton;
@property (retain, nonatomic) IBOutlet UIActivityIndicatorView* loader;
@property (retain, nonatomic) ElevationGrid* grid;

@property (retain, nonatomic) NSMutableArray* data; // google's data for the grid
@property (retain, nonatomic) NSMutableArray* top5; // 5 highest points.

@property (retain, nonatomic) NSMutableArray* routes;

-(IBAction)locationButtonPressed:(id)sender;
-(IBAction)top5ButtonPressed:(id)sender;
-(IBAction)findSpotsButtonPressed:(id)sender;

@end
