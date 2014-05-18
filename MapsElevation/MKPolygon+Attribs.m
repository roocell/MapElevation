//
//  MKPolygon+Attribs.m
//  MapsElevation
//
//  Created by michael russell on 2014-05-17.
//  Copyright (c) 2014 ThumbGenius Software. All rights reserved.
//

#import "MKPolygon+Attribs.h"
#import <objc/runtime.h>

@implementation MKPolygon (Attribs)

#define ASSOBJ_MKPOLYGON_COLOR  @"mkpolygon_color"
-(UIColor*)color {
    return objc_getAssociatedObject(self, ASSOBJ_MKPOLYGON_COLOR);
}
-(void)setColor:(UIColor *)color
{
    objc_setAssociatedObject(self, ASSOBJ_MKPOLYGON_COLOR, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
