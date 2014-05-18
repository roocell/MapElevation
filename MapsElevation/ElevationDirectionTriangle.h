//
//  ElevationDirectionTriangle.h
//  MapsElevation
//
//  Created by michael russell on 2014-05-17.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ElevationDirectionTriangle : UIView
@property CGColorRef fillColor;
@property float bearing;

- (id)initWithFrame:(CGRect)frame fillColor:(UIColor*) _f withBearing:(float) bearing;

@end
