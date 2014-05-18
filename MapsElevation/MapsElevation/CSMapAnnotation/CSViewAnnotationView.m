//
//  CSLabelAnnotationView.m
//  ocua
//
//  Created by michael russell on 12-09-26.
//  Copyright 2012 Thumb Genius Software. All rights reserved.
//

#import "CSViewAnnotationView.h"
#import "CSMapAnnotation.h"

@implementation CSViewAnnotationView
@synthesize customView=_customView;

- (id)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier
{
	self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    CSMapAnnotation* csAnnotation = (CSMapAnnotation*)annotation;
	self.frame = csAnnotation.customView.frame;
   [self addSubview:csAnnotation.customView];

	
    UILabel* label = [[UILabel alloc] initWithFrame:self.frame];
    label.text=csAnnotation.label;
    label.textAlignment = NSTextAlignmentCenter;
	label.backgroundColor = [UIColor clearColor];
    label.textColor=[UIColor whiteColor];
    
    label.font = [UIFont fontWithName:@"Arial-BoldMT" size: 10.0];
 	//_label.shadowColor = [UIColor blackColor];
	//_label.shadowOffset = CGSizeMake(1,1);
    //label.userInteractionEnabled=YES;
    [self addSubview:label];

    return self;
	
}

@end
