//
//  ElevationDirectionTriangle.m
//  MapsElevation
//
//  Created by michael russell on 2014-05-17.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "ElevationDirectionTriangle.h"
#import <QuartzCore/QuartzCore.h> // For CAAnimation

#define FILL_COLOR  [UIColor redColor]

@implementation ElevationDirectionTriangle

@synthesize fillColor=_fillColor;
@synthesize bearing=_bearing;

- (id)initWithFrame:(CGRect)frame fillColor:(UIColor*) _f withBearing:(float) bearing
{
    id tmp=[self initWithFrame:frame];
    if (_f) _fillColor=_f.CGColor;
    _bearing=bearing;
    return tmp;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code	
    }
    self.backgroundColor=[UIColor clearColor];
    _fillColor=FILL_COLOR.CGColor;
    return self;
}

#define TRIANGLE_SIZE CGSizeMake(7,7)
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect currentFrame = self.bounds;
    
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetStrokeColorWithColor(context, _fillColor);
    CGContextSetFillColorWithColor(context, _fillColor);
    CGContextSetAlpha(context, 0.5);
    
    float width = currentFrame.size.width;
    float height = currentFrame.size.height;
    
#if 1
    CGContextMoveToPoint(context,width/2,0);
    CGContextAddLineToPoint(context, width*0.75, height);
    CGContextAddLineToPoint(context, width*0.25, height);
    CGContextAddLineToPoint(context, width/2, 0);
    
#else
    float r=width/2;
    CGContextMoveToPoint(context,width/2, height/2);
    CGContextAddLineToPoint(context, width/2+r*sin(deg2rad(_bearing)), height/2+r*cos(deg2rad(_bearing))); //  tip of triangle
    
    float leftPt=fmodf(_bearing-110.0, 360.0);
    float rightPt=fmodf(_bearing+110.0, 360.0);
    CGContextAddLineToPoint(context, width/2+r*sin(deg2rad(leftPt)), height/2+r*cos(deg2rad(leftPt)));
    CGContextAddLineToPoint(context, width/2+r*sin(deg2rad(rightPt)), height/2+r*cos(deg2rad(rightPt)));
 
    TGLog(@"adding arrow %f,%f,%f - %f,%f %f,%f %f,%f", _bearing, leftPt, rightPt,
          width/2+r*sin(deg2rad(_bearing)), height/2+r*cos(deg2rad(_bearing)),
          width/2+r*sin(deg2rad(leftPt)), height/2+r*cos(deg2rad(leftPt)),
          width/2+r*sin(deg2rad(rightPt)), height/2+r*cos(deg2rad(rightPt))
          );
#endif
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);
    
}

@end
