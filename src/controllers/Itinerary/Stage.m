/*

Copyright (C) 2010  CycleStreets Ltd

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

*/

//  Stage.m
//  CycleStreets
//
//  Created by Alan Paxton on 12/03/2010.
//


#import "Stage.h"
#import "SegmentVO.h"
#import "RMMarkerManager.h"
#import "MapViewController.h"
#import "CycleStreetsAppDelegate.h"
#import "CycleStreets.h"
#import "QueryPhoto.h"
#import "PhotoMapListVO.h"
#import "PhotoMapVO.h"
#import "PhotoMapImageLocationViewController.h"
#import "Markers.h"
#import "BlueCircleView.h"
#import "CSPointVO.h"
#import "AppConstants.h"
#import "GlobalUtilities.h"

@implementation Stage
@synthesize footerView;
@synthesize footerIsHidden;
@synthesize photoIconsVisisble;
@synthesize mapView;
@synthesize blueCircleView;
@synthesize lastLocation;
@synthesize lineView;
@synthesize attributionLabel;
@synthesize photoMarkers;
@synthesize locationButton;
@synthesize infoButton;
@synthesize photoIconButton;
@synthesize prev;
@synthesize next;
@synthesize route;
@synthesize index;
@synthesize photosIndex;
@synthesize markerLocation;
@synthesize locationManager;
@synthesize doingLocation;
@synthesize locationView;
@synthesize queryPhoto;

//=========================================================== 
// dealloc
//=========================================================== 
- (void)dealloc
{
    [footerView release], footerView = nil;
    [mapView release], mapView = nil;
    [blueCircleView release], blueCircleView = nil;
    [lastLocation release], lastLocation = nil;
    [lineView release], lineView = nil;
    [attributionLabel release], attributionLabel = nil;
    [photoMarkers release], photoMarkers = nil;
    [locationButton release], locationButton = nil;
    [infoButton release], infoButton = nil;
    [photoIconButton release], photoIconButton = nil;
    [prev release], prev = nil;
    [next release], next = nil;
    [route release], route = nil;
    [markerLocation release], markerLocation = nil;
    [locationManager release], locationManager = nil;
    [locationView release], locationView = nil;
    [queryPhoto release], queryPhoto = nil;
	
    [super dealloc];
}





- (void)viewDidLoad {
    [super viewDidLoad];
	
	//handle taps etc.
	[mapView setDelegate:self];
	
	//Necessary to start route-me service
	[RMMapView class];
	
	//get the configured map source.
	[[[RMMapContents alloc] initWithView:mapView tilesource:[MapViewController tileSource]] autorelease];
	
	// set up location manager
	locationManager = [[CLLocationManager alloc] init];
	doingLocation = NO;
	
	[blueCircleView setLocationProvider:self];
	blueCircleView.hidden = YES;
	
	[lineView setPointListProvider:self];
	
	//photo & info default to ON state
	self.infoButton.style = UIBarButtonItemStyleDone;
	self.photoIconButton.style = UIBarButtonItemStyleDone;
	
	photoIconsVisisble=YES;
	
	footerIsHidden=NO;
	footerView=[[CSSegmentFooterView alloc]initWithFrame:CGRectMake(0, SCREENHEIGHT, SCREENWIDTH, 10)];
	[mapView addSubview:footerView];
	
	
	self.attributionLabel.backgroundColor=UIColorFromRGBAndAlpha(0x008000,0.2);
	self.attributionLabel.text = [MapViewController mapAttribution];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(didNotificationMapStyleChanged)
												 name:@"NotificationMapStyleChanged"
											   object:nil];		
}

- (void) didNotificationMapStyleChanged {
	mapView.contents.tileSource = [MapViewController tileSource];
	self.attributionLabel.text = [MapViewController mapAttribution];
}



-(void)doubleTapOnMap:(RMMapView*)map At:(CGPoint)point{
	BetterLog(@"");
}

- (NSArray *) pointList {
	BetterLog(@"");
	return [MapViewController pointList:route withView:mapView];
}

- (void)setRoute:(Route *)newRoute {
	Route *oldRoute = route;
	route = newRoute;
	[newRoute retain];
	[oldRoute release];
	
	//go to the start
	index = 0;
	
	[lineView setNeedsDisplay];
}

//helper method for setSegmentIndex
- (void)setPrevNext {
	//set the prev/next/of
	[prev setEnabled:YES];
	if (index == 0) {
		[prev setEnabled:NO];
	}
	[next setEnabled:YES];
	if (index == [route numSegments]-1) {
		[next setEnabled:NO];
	}
	
	NSString *message = [NSString stringWithFormat:@"Stage: %d/%d", index+1, [route numSegments]];
	footerView.segmentIndexLabel.text=message;
	 
	
	[lineView setNeedsDisplay];
}



#pragma mark Photo Icons
//
/***********************************************
 * @description			PHOTO ICON METHODS
 ***********************************************/
//


- (void) photoSuccess:(XMLRequest *)request results:(NSDictionary *)elements {
	
	BetterLog(@"");
	
	//Check we're still looking for the same page of photos	
	if (index != photosIndex) return;
	
	
	[self clearPhotos];
	
	if (photoMarkers == nil) {
		photoMarkers = [[NSMutableArray alloc] initWithCapacity:10];
	}
	
	PhotoMapListVO *photoList = [[PhotoMapListVO alloc] initWithElements:elements];
	for (PhotoMapVO *photo in [photoList photos]) {
		RMMarker *marker = [Markers markerPhoto];
		marker.data = photo;
		[photoMarkers addObject:marker];
		marker.hidden=!photoIconsVisisble;
		[[mapView markerManager] addMarker:marker AtLatLong:[photo location]];
	}
	[photoList release];
	self.queryPhoto = nil;
}


- (void) clearPhotos {
	//Clear out the previous list.
	if (photoMarkers != nil) {
		NSArray *oldMarkers = [photoMarkers copy];
		for (RMMarker *oldMarker in photoMarkers) {
			[[mapView markerManager] removeMarker:oldMarker];
		}
		[oldMarkers release];
	}
}

- (void) photoFailure:(XMLRequest *)request message:(NSString *)message {
	//is it even worth bothering to alert ?
	self.queryPhoto = nil;
}

//helper, could be shelled out as more general.
- (void)fetchPhotoMarkersNorthEast:(CLLocationCoordinate2D)ne SouthWest:(CLLocationCoordinate2D)sw {
	
	BetterLog(@"");
	
	photosIndex = index;//we are looking for the photos associated with this index
	self.queryPhoto = [[[QueryPhoto alloc] initNorthEast:ne SouthWest:sw limit:4] autorelease];
	[queryPhoto runWithTarget:self onSuccess:@selector(photoSuccess:results:) onFailure:@selector(photoFailure:message:)];
}


- (void) tapOnMarker: (RMMarker*) marker onMap: (RMMapView*) map {
	BetterLog(@"tapMarker");
	if (locationView == nil) {
		locationView = [[PhotoMapImageLocationViewController alloc] initWithNibName:@"PhotoMapImageLocationView" bundle:nil];
		[locationView retain];
	}
	if ([marker.data isKindOfClass: [PhotoMapVO class]]) {
		[self presentModalViewController:locationView animated:YES];
		PhotoMapVO *photoEntry = (PhotoMapVO *)marker.data;
		[locationView loadContentForEntry:photoEntry];
	}	
}

//
/***********************************************
 * @description			END PHOTO METHODS
 ***********************************************/
//


//
/***********************************************
 * @description			Update Map view by segment
 ***********************************************/
//

- (void)setSegmentIndex:(NSInteger)newIndex {
	index = newIndex;
	SegmentVO *segment = [route segmentAtIndex:index];
	SegmentVO *nextSegment = nil;
	if (index + 1 < [route numSegments]) {
		nextSegment = [route segmentAtIndex:index+1];
	}
	
	// fill the labels from the segment we are showing
	footerView.dataProvider=[segment infoStringDictionary];
	[footerView updateLayout];
	[self updateFooterPositions];
	// centre the view around the segment
	CLLocationCoordinate2D start = [segment segmentStart];
	CLLocationCoordinate2D end = [segment segmentEnd];
	CLLocationCoordinate2D ne;
	CLLocationCoordinate2D sw;
	if (start.latitude < end.latitude) {
		sw.latitude = start.latitude;
		ne.latitude = end.latitude;
	} else {
		sw.latitude = end.latitude;
		ne.latitude = start.latitude;
	}
	if (start.longitude < end.longitude) {
		sw.longitude = start.longitude;
		ne.longitude = end.longitude;
	} else {
		sw.longitude = end.longitude;
		ne.longitude = start.longitude;
	}
	[mapView zoomWithLatLngBoundsNorthEast:(CLLocationCoordinate2D)ne SouthWest:(CLLocationCoordinate2D)sw];
	RMMarkerManager *markerManager = [mapView markerManager];
	NSMutableArray *toRemove = [NSMutableArray arrayWithCapacity:0];
	//
	for (RMMarker *marker in [markerManager markers]) {
		[toRemove addObject:marker];
	}
	for (RMMarker *marker in toRemove) {
		if (marker != self.markerLocation) {
			[marker retain];//Not clear why this gets a 0 refcount in 3.1.3, but it does, so just leak it, it's small.
			[markerManager removeMarker:marker];
		}
	}
	[markerManager addMarker:[Markers markerBeginArrow:[segment startBearing]] AtLatLong:start];
	[markerManager addMarker:[Markers markerEndArrow:[nextSegment startBearing]] AtLatLong:end];
	
	[self setPrevNext];
	[self fetchPhotoMarkersNorthEast:ne SouthWest:sw];
	
	[lineView setNeedsDisplay];
	[blueCircleView setNeedsDisplay];
}


//
/***********************************************
 * @description			update info footer
 ***********************************************/
//

-(void)updateFooterPositions{
	
	if(footerIsHidden==NO){
		CGRect	fframe=footerView.frame;
		CGRect	aframe=attributionLabel.frame;
		
		fframe.origin.y=SCREENHEIGHTWITHNAVIGATION-fframe.size.height;
		aframe.origin.y=fframe.origin.y-10-aframe.size.height;
		
		footerView.frame=fframe;
		attributionLabel.frame=aframe;
	}
}






 
//pop back to route overview
- (IBAction) didRoute {
	[self dismissModalViewControllerAnimated:YES];
	
}


// all the things that need fixed if we have asked (or been forced) to stop doing location.
- (void)stopDoingLocation {
	doingLocation = NO;
	locationButton.style = UIBarButtonItemStyleBordered;
	[locationManager stopUpdatingLocation];
	blueCircleView.hidden = YES;
}

// all the things that need fixed if we have asked (or been forced) to start doing location.
- (void)startDoingLocation {
	
	if([CLLocationManager locationServicesEnabled]==YES){
	
		doingLocation = YES;
		locationButton.style = UIBarButtonItemStyleDone;
		locationManager.delegate = self;
		[locationManager startUpdatingLocation];
		blueCircleView.hidden = NO;
	}else {
		UIAlertView *gpsAlert = [[UIAlertView alloc] initWithTitle:@"CycleStreets"
														   message:@"Location services for CycleStreets are off, please enable in Settings > General > Location Services to use location based features."
														  delegate:self
												 cancelButtonTitle:@"OK"
												 otherButtonTitles:nil];
		[gpsAlert show];
		[gpsAlert release];
	}

}

- (IBAction) didLocation {
	//turn on/off use of location to automatically move from one map position to the next...
	BetterLog(@"location");
	locationManager.delegate = self;
	if (!doingLocation) {
		[self startDoingLocation];
	} else {
		[self stopDoingLocation];
	}
}

- (void)locationManager:(CLLocationManager *)manager
	didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation
{
	if (!self.markerLocation) {
		//first location, construct the marker
		self.markerLocation = [Markers marker:@"currentLocation.png" label:nil];
		[[mapView markerManager] addMarker:self.markerLocation AtLatLong: newLocation.coordinate];
	}
	[[mapView markerManager] moveMarker:self.markerLocation AtLatLon: newLocation.coordinate];
	
	//carefully replace the location.
	CLLocation *oldLastLocation = lastLocation;
	[newLocation retain];
	lastLocation = newLocation;
	[oldLastLocation release];
	
	[lineView setNeedsDisplay];
	[blueCircleView setNeedsDisplay];
}

- (void)locationManager:(CLLocationManager *)manager
	   didFailWithError:(NSError *)error
{
	//TODO alert: What exactly does the location finding do in this view?
	[self stopDoingLocation];
	
	UIAlertView *gpsAlert = [[UIAlertView alloc] initWithTitle:@"CycleStreets"
													   message:@"Unable to retrieve location. Location services for CycleStreets may be off, please enable in Settings > General > Location Services to use location based features."
													  delegate:nil
											 cancelButtonTitle:@"OK"
											 otherButtonTitles:nil];
	[gpsAlert show];
	[gpsAlert release];
}


//
/***********************************************
 * @description			UI button events
 ***********************************************/
//


- (IBAction) didPrev {
	if (index > 0) {
		[self setSegmentIndex:index-1];
	}
}

- (IBAction) didNext {
	if (index < [route numSegments]-1) {
		[self setSegmentIndex:index+1];
	}
}

- (IBAction) didToggleInfo {
	
	if (footerIsHidden==NO) {
		
		CGRect	fframe=footerView.frame;
		CGRect	aframe=attributionLabel.frame;
		
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationDuration:0.4];
		
		fframe.origin.y=SCREENHEIGHTWITHNAVIGATION;
		aframe.origin.y=fframe.origin.y-aframe.size.height-10;
		
		footerView.frame=fframe;
		footerView.alpha=0;
		attributionLabel.frame=aframe;
		
		[UIView commitAnimations];
		
		footerIsHidden=YES;
		
	} else {
		
		CGRect	fframe=footerView.frame;
		CGRect	aframe=attributionLabel.frame;
		
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationBeginsFromCurrentState:YES];
		[UIView setAnimationDuration:0.4];
		
		fframe.origin.y=SCREENHEIGHTWITHNAVIGATION-fframe.size.height;
		aframe.origin.y=fframe.origin.y-10-aframe.size.height;
		
		footerView.frame=fframe;
		footerView.alpha=1;
		attributionLabel.frame=aframe;
		
		[UIView commitAnimations];
		
		footerIsHidden=NO;
	}
}


-(IBAction)photoIconButtonSelected{
	
	photoIconsVisisble=!photoIconsVisisble;
	
	for (RMMarker *marker in photoMarkers) {
		marker.hidden=!photoIconsVisisble;
	}
	
	if(photoIconsVisisble==YES){
		self.photoIconButton.style=UIBarButtonItemStyleDone;
	}else {
		self.photoIconButton.style=UIBarButtonItemStyleBordered;
	}

	
}


#pragma mark Location provider

- (float)getX {
	CGPoint p = [mapView.contents latLongToPixel:lastLocation.coordinate];
	return p.x;
}

- (float)getY {
	CGPoint p = [mapView.contents latLongToPixel:lastLocation.coordinate];
	return p.y;
}

- (float)getRadius {
	double metresPerPixel = [mapView.contents metersPerPixel];
	return (lastLocation.horizontalAccuracy / metresPerPixel);
}

#pragma mark mapView delegate

- (void) afterMapMove: (RMMapView*) map {
	[lineView setNeedsDisplay];
	[blueCircleView setNeedsDisplay];
}


- (void) afterMapZoom: (RMMapView*) map byFactor: (float) zoomFactor near:(CGPoint) center {
	[lineView setNeedsDisplay];
	[blueCircleView setNeedsDisplay];	
}


-(void)updateMapPhotoMarkers{
	
	CGRect bounds = mapView.contents.screenBounds;

	CLLocationCoordinate2D nw = [mapView pixelToLatLong:bounds.origin];
	CLLocationCoordinate2D se = [mapView pixelToLatLong:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height)];	
	CLLocationCoordinate2D ne;
	CLLocationCoordinate2D sw;
	ne.latitude = nw.latitude;
	ne.longitude = se.longitude;
	sw.latitude = se.latitude;
	sw.longitude = nw.longitude;
	[self fetchPhotoMarkersNorthEast:ne SouthWest:sw];
}


#pragma mark hygiene

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)nullify {
	self.footerView=nil;
	
	self.mapView = nil;
	self.blueCircleView = nil;	//overlay GPS location
	self.lineView = nil;
	self.attributionLabel = nil;
	
	//toolbar
	self.locationButton = nil;
	self.infoButton = nil;
	self.prev = nil;
	self.next = nil;
	
	[markerLocation release];
	markerLocation = nil;
	[locationManager release];
	locationManager = nil;
	[locationView release];
	locationView = nil;
	
	self.queryPhoto = nil;
}

- (void)viewDidUnload {
	
	[self nullify];
	[super viewDidUnload];
	BetterLog(@">>>");
}


@end
