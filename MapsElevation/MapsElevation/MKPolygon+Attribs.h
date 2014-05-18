//
//  MKPolygon+Attribs.h
//  MapsElevation
//
//  Created by michael russell on 2014-05-17.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

// have to use a category because we cant sublass mkpolygon

@interface MKPolygon (Attribs)
@property (retain, nonatomic) UIColor* color;
@end
