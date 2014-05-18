//
//  CSMapAnnotation.m
//  mapLines
//
//  Created by Craig on 5/15/09.
//  Copyright 2009 Craig Spitzkoff. All rights reserved.
//

#import "CSMapAnnotation.h"


@implementation CSMapAnnotation

@synthesize coordinate     = _coordinate;
@synthesize annotationType = _annotationType;
@synthesize userData       = _userData;
@synthesize imgData       = _imgData;
@synthesize customView=_customView;
@synthesize url            = _url;
@synthesize label=_label;
@synthesize userObject;
@synthesize reuseIdentifier;

-(id) initWithCoordinate:(CLLocationCoordinate2D)coordinate 
		  annotationType:(CSMapAnnotationType) annotationType
				   title:(NSString*)title  subtitle:(NSString*)subtitle reuseIdentifier:(NSString*)reuseId
{
	self = [super init];
    
	_coordinate = coordinate;
	_title      = title;
	_annotationType = annotationType;
	reuseIdentifier = reuseId;
    _subtitle = subtitle;
	return self;
}
- (NSString *)title
{
	return _title;
}

- (NSString *)subtitle
{
	return _subtitle;
}
@end
