//
//  CSImageAnnotationView.m
//  mapLines
//
//  Created by Craig on 5/15/09.
//  Copyright 2009 Craig Spitzkoff. All rights reserved.
//

#import "CSImageAnnotationView.h"
#import "CSMapAnnotation.h"
#import "util.h"

#define kHeight 48
#define kWidth  96
#define kBorder 2

@implementation CSImageAnnotationView
@synthesize imageView = _imageView;

- (id)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
	self.frame = CGRectMake(0, 0, kWidth, kHeight);
	self.backgroundColor = [UIColor clearColor];
	
    CSMapAnnotation* csAnnotation = (CSMapAnnotation*)annotation;
    _imageView = [[UIImageView alloc] initWithImage:csAnnotation.imgData];
    _imageView.frame = CGRectMake(kBorder, kBorder, kWidth - 2 * kBorder, kHeight - 2 * kBorder);

    [self addSubview:_imageView];
    return self;	
}

@end
