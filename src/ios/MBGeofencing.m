//
//  MBGeofencing.m
//
//  Created by Michael Belkin on 3/14/16.
//
//

#import "MBGeofencing.h"

@interface MBGeofencing()<CLLocationManagerDelegate>

@property (strong, nonatomic) CLLocationManager * locationManager;
@property (nonatomic, strong) NSMutableDictionary * regionMonitoringCallbacks;

@end

@implementation MBGeofencing

#pragma mark - Interface
- (void)requestPermissions:(CDVInvokedUrlCommand *)command
{

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
	
	// create the CLRegion
	CLLocationCoordinate2D center = CLLocationCoordinate2DMake(lat, lon);
	CLCircularRegion * region = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:identifier];
	region.notifyOnEntry = YES;
	region.notifyOnExit = NO;
	
	// verify region monitoring availability and permissions
	if (![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]])
	{
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Geofencing is not supported on this device!"] callbackId:callbackId];
		return;
	}
	if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways)
	{
		[self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Region wass saved but will only be activated once user grants permission to access the device location."] callbackId:callbackId];
		return;
	}
	
	// all good, now try to add the region
	if (!self.regionMonitoringCallbacks)
	{
		self.regionMonitoringCallbacks = [NSMutableDictionary new];
	}
	if (!self.regionMonitoringCallbacks[identifier])
	{
		self.regionMonitoringCallbacks[identifier] = [NSMutableArray new];
	}
	
	[self.regionMonitoringCallbacks[identifier] addObject:callbackId];
	[self.locationManager startMonitoringForRegion:region];
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
- (BOOL)isAuthorized
{
    BOOL authorizationStatusClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]; // iOS 4.2+

    if (authorizationStatusClassPropertyAvailable) {
        NSUInteger authStatus = [CLLocationManager authorizationStatus];
#ifdef __IPHONE_8_0
        if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {  //iOS 8.0+
            return (authStatus == kCLAuthorizationStatusAuthorizedWhenInUse) || (authStatus == kCLAuthorizationStatusAuthorizedAlways) || (authStatus == kCLAuthorizationStatusNotDetermined);
        }
#endif
        return (authStatus == kCLAuthorizationStatusAuthorized) || (authStatus == kCLAuthorizationStatusNotDetermined);
    }

    // by default, assume YES (for iOS < 4.2)
    return YES;
}

- (BOOL)isLocationServicesEnabled
{
    BOOL locationServicesEnabledInstancePropertyAvailable = [self.locationManager respondsToSelector:@selector(locationServicesEnabled)]; // iOS 3.x
    BOOL locationServicesEnabledClassPropertyAvailable = [CLLocationManager respondsToSelector:@selector(locationServicesEnabled)]; // iOS 4.x

    if (locationServicesEnabledClassPropertyAvailable) { // iOS 4.x
        return [CLLocationManager locationServicesEnabled];
    } else if (locationServicesEnabledInstancePropertyAvailable) { // iOS 2.x, iOS 3.x
        return [(id)self.locationManager locationServicesEnabled];
    } else {
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