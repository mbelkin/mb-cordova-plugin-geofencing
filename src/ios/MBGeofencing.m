//
//  MBGeofencing.m
//
//  Created by Michael Belkin on 3/14/16.
//
//

#import "MBGeofencing.h"

#define	iOS8_OR_ABOVE								([[[UIDevice currentDevice] systemVersion] compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending)

@interface MBGeofencing()<CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager * locationManager;
@property (nonatomic, strong) NSMutableDictionary * regionMonitoringCallbacks;

@end

@implementation MBGeofencing

#pragma mark - Interface
- (void)requestPermissions:(CDVInvokedUrlCommand *)command
{
	switch ([CLLocationManager authorizationStatus])
	{
		case kCLAuthorizationStatusRestricted:
		case kCLAuthorizationStatusDenied:
			//app is not permitted to use location services and you should abort your attempt to use them
			if (command) [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"App is not permitted to use location services and you should abort your attempt to use them"] callbackId:command.callbackId];
			break;
		case kCLAuthorizationStatusNotDetermined:
		case kCLAuthorizationStatusAuthorizedWhenInUse:
			if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
			{
				// iOS 8
				[self.locationManager requestAlwaysAuthorization];
			}
			else
			{
				// ios7
				[self.locationManager startUpdatingLocation]; // do this just to promopt the permissions alert to show
			}
			if (command) [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Requested necessary geofencing permissions (but they're not yet granted as of the invocation of this callback)"] callbackId:command.callbackId];
			break;
		case kCLAuthorizationStatusAuthorized: // same as kCLAuthorizationStatusAuthorizedAlways in iOS8
			if (command) [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Proper geofencing permissions are enabled"] callbackId:command.callbackId];
			break;
	}
}

- (void)startMonitoringRegion:(CDVInvokedUrlCommand *)command
{
	NSString * callbackId = command.callbackId;
	NSString * identifier = command.arguments[0];
	float lat = [command.arguments[1] floatValue];
	float lon = [command.arguments[2] floatValue];
	float radius = [command.arguments[3] floatValue];

	// make sure we're not monitoring too many events
	if (self.locationManager.monitoredRegions.count > 19)
	{
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Unable to add region. You've reached the maximum of 20. To proceed, remove regions or remove all. Then try again."] callbackId:callbackId];
		return;
	}
	
	// verify region monitoring availability and permissions
	if (![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]])
	{
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Geofencing is not supported on this device!"] callbackId:callbackId];
		return;
	}
	
	// all good, create the region and try to add it
	CLLocationCoordinate2D center = CLLocationCoordinate2DMake(lat, lon);
	CLCircularRegion * region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:identifier];
	region.notifyOnEntry = YES;
	region.notifyOnExit = NO;
	
	if (![self geofencingPermissionsGranted])
	{
		[self requestPermissions:nil];
		[self.locationManager startMonitoringForRegion:region];
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Region was saved but will only be activated once user grants permission to access the device location (which was just asked for)"] callbackId:callbackId];
	}
	else
	{
		if (!self.regionMonitoringCallbacks[identifier])
		{
			self.regionMonitoringCallbacks[identifier] = [NSMutableArray new];
		}
		
		[self.regionMonitoringCallbacks[identifier] addObject:callbackId];
		[self.locationManager startMonitoringForRegion:region];
	}
}

- (void)stopMonitoringRegion:(CDVInvokedUrlCommand *)command
{
	NSString * callbackId = command.callbackId;
	NSString * identifier = [command.arguments[0] stringValue];
	CLCircularRegion * regionToStop;
	
	for (CLCircularRegion * region in self.locationManager.monitoredRegions)
	{
		if ([region.identifier isEqualToString:identifier])
		{
			regionToStop = region;
			[self.locationManager stopMonitoringForRegion:region];
			break;
		}
	}
	
	CDVPluginResult * result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self dictionaryFromRegion:(CLCircularRegion *)regionToStop]];
	[self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (void)stopMonitoringAllRegions:(CDVInvokedUrlCommand *)command
{
	NSString * callbackId = command.callbackId;
	
	for (CLCircularRegion * region in self.locationManager.monitoredRegions)
	{
		[self.locationManager stopMonitoringForRegion:region];
	}
	
	[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:callbackId];
}

#pragma mark - CLLocationManager Delegate Methods
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(nonnull CLRegion *)region
{
	NSLog(@"Successfully monitoring region: %@", region.identifier);
	/* Not doing this because you wouldn't be able to distinguish it from didEnterRegion (which is really what the success callback wants)
	for (NSString * identifier in self.locationData.regionMonitoringCallbacks)
	{
		if ([identifier isEqualToString:region.identifier])
		{
			for (NSString * callbackId in self.locationData.regionMonitoringCallbacks[identifier])
			{
				[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:callbackId];
			}
			break;
		}
	}
	*/
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(nullable CLRegion *)region withError:(nonnull NSError *)error
{
	NSLog(@"Failed monitoring for region: %@ with error: %@", region.identifier, error);
	for (NSString * identifier in self.regionMonitoringCallbacks)
	{
		if ([identifier isEqualToString:region.identifier])
		{
			for (NSString * callbackId in self.regionMonitoringCallbacks[identifier])
			{
				CDVPluginResult * result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:[self dictionaryFromRegion:(CLCircularRegion *)region]];
				[self.commandDelegate sendPluginResult:result callbackId:callbackId];
			}
			break;
		}
	}
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
	[self logRegionEntry:(CLCircularRegion *)region];
	for (NSString * identifier in self.regionMonitoringCallbacks)
	{
		if ([identifier isEqualToString:region.identifier])
		{
			for (NSString * callbackId in self.regionMonitoringCallbacks[identifier])
			{
				CDVPluginResult * result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[self dictionaryFromRegion:(CLCircularRegion *)region]];
				[self.commandDelegate sendPluginResult:result callbackId:callbackId];
			}
			break;
		}
	}
}

#pragma mark - Helpers
- (BOOL)geofencingPermissionsGranted
{
	switch ([CLLocationManager authorizationStatus])
	{
		case kCLAuthorizationStatusAuthorized: // same as kCLAuthorizationStatusAuthorizedAlways in iOS8
			return YES;
		case kCLAuthorizationStatusRestricted:
		case kCLAuthorizationStatusDenied:
		case kCLAuthorizationStatusNotDetermined:
		case kCLAuthorizationStatusAuthorizedWhenInUse:
			return NO;
	}
}

- (void)logRegionEntry:(CLCircularRegion *)region
{
	NSString * postString = [NSString stringWithFormat:@"GEOFENCING: Region \"%@\" entered. (lat: %f, lon:%f)", region.identifier, region.center.latitude, region.center.longitude];
	
	NSURLSession * session = [NSURLSession sharedSession];
	NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api-dev.boosterfuels.com/phone-home"]];
	request.HTTPMethod = @"POST";
	request.HTTPBody = [postString dataUsingEncoding:NSUTF8StringEncoding];
	
	[[session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)
	{

	}] resume];
}

- (NSDictionary *)dictionaryFromRegion:(CLCircularRegion *)region
{
	return @{
			 @"identifier": region.identifier,
			 @"latitude": [NSNumber numberWithFloat:region.center.latitude],
			 @"longitude": [NSNumber numberWithFloat:region.center.longitude],
			 @"timestamp": @([[NSDate date] timeIntervalSince1970]),
			 };
}

#pragma mark - Getters
- (NSMutableDictionary *)regionMonitoringCallbacks
{
	if (!_regionMonitoringCallbacks)
	{
		_regionMonitoringCallbacks = [NSMutableDictionary new];
	}
	return _regionMonitoringCallbacks;
}

- (CLLocationManager *)locationManager
{
	if (!_locationManager)
	{
		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.delegate = self;
	}
	return _locationManager;
}
@end