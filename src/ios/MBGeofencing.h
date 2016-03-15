//
//  MBGeofencing.h
//
//  Created by Michael Belkin on 3/14/16.
//
//

#import <Cordova/CDV.h>
#import <CoreLocation/CoreLocation.h>

@interface MBGeofencing : CDVPlugin

- (void)requestPermissions:(CDVInvokedUrlCommand *)command;
- (void)startMonitoringRegion:(CDVInvokedUrlCommand *)command;
- (void)stopMonitoringRegion:(CDVInvokedUrlCommand *)command;
- (void)stopMonitoringAllRegions:(CDVInvokedUrlCommand *)command;

@end