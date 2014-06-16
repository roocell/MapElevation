//
//  MKPolyline+Attribs.m
//  MapsElevation
//
//  Created by michael russell on 2014-05-22.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "MKPolyline+Attribs.h"
#import <objc/runtime.h>

@implementation MKPolyline (Attribs)

#define ASSOBJ_MKPOLYLINE_COLOR  @"mkpolyline_color"
-(UIColor*)color {
    return objc_getAssociatedObject(self, ASSOBJ_MKPOLYLINE_COLOR);
}
-(void)setColor:(UIColor *)color
{
    objc_setAssociatedObject(self, ASSOBJ_MKPOLYLINE_COLOR, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
