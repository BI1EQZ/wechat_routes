#define kBundlePath @"/Library/MobileSubstrate/DynamicLibraries/supery_wechat.bundle"

#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>

@interface PositionItem
{
    double latitude;
    double longitude;
    double heading;
}
@property double heading;
@property double longitude;
@property double latitude;
@end

@interface UserPositionItem
{
    NSString *username;
    PositionItem *position;
}
@property(retain) PositionItem *position;
@property(retain) NSString *username;
@end

@interface TrackRoomView
-(void)showRouteToSomeone;
-(void)updatePolgins:(CLLocationCoordinate2D *)dots andCount:(int)n;
-(NSArray*) calculateRoutesFrom:(CLLocationCoordinate2D) from to: (CLLocationCoordinate2D) to ;
-(NSMutableArray *)decodePolyLine: (NSMutableString *)encoded ;
-(void)showMapSettingMenu:(id)sender;
-(void)segmentSelected:(id)sender;
- (id)getDisplayNameByUsername:(id)arg1;
-(void)removeOverlayByTitle:(NSString *)title;
-(void)getPointsFromGoogleWithA:(CLLocationCoordinate2D)a B:(CLLocationCoordinate2D)b andUName:(NSString *)username;
@end

MKMapView* mapView_;
NSMutableDictionary* locations = [[NSMutableDictionary alloc] initWithCapacity:1];

%hook TrackRoomView

#pragma mark - UIView
- (void)initMapView{
  %orig;
  object_getInstanceVariable(self,"_mapView",(void**)&mapView_);

  UISegmentedControl* mSegCtl = [[UISegmentedControl alloc] initWithItems:@[@"标准",@"卫星",@"混合"]];
  [mSegCtl setFrame:CGRectMake(195, 100, mSegCtl.frame.size.width, mSegCtl.frame.size.height)];
  [mapView_ addSubview:mSegCtl];
  [mSegCtl setTintColor:[UIColor grayColor]];
  [mSegCtl setSelectedSegmentIndex:0];
  [mSegCtl addTarget:self action:@selector(segmentSelected:) forControlEvents:UIControlEventValueChanged];
  [mSegCtl release];


  NSBundle *bundle = [[[NSBundle alloc] initWithPath:kBundlePath] autorelease];
  NSString *imagePath = [bundle pathForResource:@"routes" ofType:@"png"];
  UIImage *image = [UIImage imageWithContentsOfFile:imagePath];

  UIButton* showAllRoutes = [[UIButton alloc]initWithFrame:CGRectMake(150, 100, 44, 29)];
  [showAllRoutes setBackgroundImage:image forState:UIControlStateNormal];
  [showAllRoutes setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.25]];
  [showAllRoutes.layer setCornerRadius:5.0];
  [showAllRoutes.layer setMasksToBounds:YES];
  [showAllRoutes addTarget:self action:@selector(showAllRoutes) forControlEvents:UIControlEventTouchUpInside];
  [mapView_ addSubview:showAllRoutes];
  [showAllRoutes release];

}

%new
-(void)segmentSelected:(id)sender{
    UISegmentedControl* mSegControl = (UISegmentedControl *)sender;
    NSInteger idx = mSegControl.selectedSegmentIndex;
    switch (idx) {
        case 0:
            [mapView_ setMapType:MKMapTypeStandard];
            break;
        case 1:
            [mapView_ setMapType:MKMapTypeSatellite];
            break;
        case 2:
            [mapView_ setMapType:MKMapTypeHybrid];
            break;

        default:
            break;
    }
}

%new
-(void)showAllRoutes{
  [self showRouteToSomeone];
}

#pragma mark - ITrackRoomMgrExt

- (void)OnRefreshTrackRoom:(id)arg1 Type:(int)arg2{
	%orig;
	NSArray* arr = [[NSArray alloc]initWithArray:arg1];
  [locations setObject:arr forKey:@"otheruserslocation"];
  [arr release];
}


#pragma mark - MKMapViewDelegate

- (void)mapView:(id)arg1 didUpdateUserLocation:(id)arg2{
	%orig;

	MKUserLocation* userLocation = (MKUserLocation *)arg2;
	CLLocationCoordinate2D lc = CLLocationCoordinate2DMake(userLocation.coordinate.latitude, userLocation.coordinate.longitude);
	[locations setValue:[NSValue valueWithMKCoordinate:lc] forKey:@"mylocation"];

}

- (id)mapView:(id)arg1 viewForOverlay:(id)arg2{
	MKPolylineView *view = [[MKPolylineView alloc] initWithOverlay:arg2];
	if ([[arg2 title] hasPrefix:@"2222"]) {

    int r = arc4random()%1000;// 颜色深点
    int g = arc4random()%1000;
    int b = arc4random()%1000;

		view.strokeColor = [UIColor colorWithRed:r/1000.0 green:g/1000.0 blue:b/1000.0 alpha:1.0];
    [view setLineWidth:6];
		return view;
	}

	return %orig;

}


%new
-(void)removeOverlayByTitle:(NSString *)title{
  NSArray* polylies = mapView_.overlays;

  if(title)
  {
    for (MKPolyline *pl in polylies) {
      NSString* t = [NSString stringWithFormat:@"2222%@",title];
      if ([pl.title isEqualToString:t]) {
        [mapView_ removeOverlay:pl];
      }
    }

  }else{
    for (MKPolyline *pl in polylies) {
      [mapView_ removeOverlay:pl];
    }
  }
}

%new
-(void)showRouteToSomeone{

  CLLocationCoordinate2D myloc = [[locations objectForKey:@"mylocation"] MKCoordinateValue];

	NSArray* others = [locations objectForKey:@"otheruserslocation"];
	if(!others || others.count == 0){
		return;
	}


  for(UserPositionItem* userPositionItem in others)
  {
    NSString *username = userPositionItem.username;
    PositionItem* positionItem = userPositionItem.position;
    CLLocationCoordinate2D otherloc = CLLocationCoordinate2DMake(positionItem.latitude, positionItem.longitude);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [self   getPointsFromGoogleWithA:myloc B:otherloc andUName:username];
    });

  }

}

%new
-(void)getPointsFromGoogleWithA:(CLLocationCoordinate2D)a B:(CLLocationCoordinate2D)b andUName:(NSString *)username{
  NSArray* routes = [self calculateRoutesFrom:a to:b];


  dispatch_async(dispatch_get_main_queue(), ^{

    int n = [routes count];
    CLLocationCoordinate2D dots[n];
    for (int i = 0; i< n; i++) {
        dots[i] = ((CLLocation* )[routes objectAtIndex:i]).coordinate;
    }

    [self removeOverlayByTitle:username];
    MKPolyline* line = [MKPolyline polylineWithCoordinates:dots count:n];
    NSString* title = [NSString stringWithFormat:@"2222%@",username];
    [line setTitle:title];
    [mapView_ addOverlay:line];

  });

}


%new
-(NSArray*) calculateRoutesFrom:(CLLocationCoordinate2D) from to: (CLLocationCoordinate2D) to {

		NSString* saddr = [NSString stringWithFormat:@"%f,%f", from.latitude, from.longitude];
		NSString* daddr = [NSString stringWithFormat:@"%f,%f", to.latitude, to.longitude];

//    driving（默认），用于表示使用道路网络的标准行车路线。
//    walking，用于请求经过步行街和人行道（如果有的话）的步行路线。
//    bicycling，用于请求经过骑行道和优先街道（如果有的话）的骑行路线。
//    transit，用于请求经过公交路线（如果有的话）的路线。

		NSString* mode = @"walking";


		NSURL* apiUrl = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.googleapis.com/maps/api/directions/json?origin=%@&destination=%@&sensor=false&mode=%@",saddr,daddr,mode]];
		NSData* jsonData = [NSData dataWithContentsOfURL:apiUrl];
		NSDictionary* jsonDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
		if (![[jsonDic objectForKey:@"status"] isEqualToString:@"OK"]) {
				return nil;
		}
		NSString* pointsEncode  = [[[[jsonDic objectForKey:@"routes"] objectAtIndex:0] objectForKey:@"overview_polyline"] objectForKey:@"points"];
		return [self decodePolyLine:[pointsEncode mutableCopy]];
}
%new
-(NSMutableArray *)decodePolyLine: (NSMutableString *)encoded {
		[encoded replaceOccurrencesOfString:@"\\\\" withString:@"\\"
																options:NSLiteralSearch range:NSMakeRange(0, [encoded length])];

		NSInteger len = [encoded length];
		NSInteger index = 0;
		NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
		NSInteger lat=0;
		NSInteger lng=0;
		while (index < len) {
				NSInteger b;
				NSInteger shift = 0;
				NSInteger result = 0;
				do {
						b = [encoded characterAtIndex:index++] - 63;
						result |= (b & 0x1f) << shift;
						shift += 5;
				} while (b >= 0x20);
				NSInteger dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
				lat += dlat;
				shift = 0;
				result = 0;
				do {
						b = [encoded characterAtIndex:index++] - 63;
						result |= (b & 0x1f) << shift;
						shift += 5;
				} while (b >= 0x20);
				NSInteger dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
				lng += dlng;
				NSNumber *latitude = [[[NSNumber alloc] initWithFloat:lat * 1e-5] autorelease];
				NSNumber *longitude = [[[NSNumber alloc] initWithFloat:lng * 1e-5] autorelease];
				printf("[%f,", [latitude doubleValue]);
				printf("%f]", [longitude doubleValue]);
				CLLocation *loc = [[[CLLocation alloc] initWithLatitude:[latitude floatValue] longitude:[longitude floatValue]] autorelease];
				[array addObject:loc];
		}
		return array;
}
%end
