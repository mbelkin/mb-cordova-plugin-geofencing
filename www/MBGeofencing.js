/*global cordova, module*/

module.exports = {
	/**
    * Requestes necessary geofencing permissions. 
    * Calls success callback if permissions are already approved. 
    * Else, it calls the error callback and passes a string indicating if persmissions were previously denied, or have not been asked for yet. 
    * If the distinctions in the error callback are important, we can switch to returning an int or error code. 
    *
    * @param {Function} successCallback     The function to call when the position data is available
    * @param {Function} errorCallback       The function to call when there is an error getting the heading position. (OPTIONAL)
    */
    requestPermissions:function(successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "MBGeofencing", "requestPermissions", []);
    },
    /**
    * Starts monitoring a circular region
    *
    * @param {String} identifier            The identifier (or name) or the region for internal purposes
    * @param {Float} lat                    The latitude of the region to monitor
    * @param {Float} lon                    The longitude of the region to monitor
    * @param {Float} radius                 The radius (in meters) of the region to monitor
    * @param {Function} successCallback     The function to call when the position data is available
    * @param {Function} errorCallback       The function to call when there is an error getting the heading position. (OPTIONAL)
    */
    startMonitoringRegion:function(identifier, lat, lon, radius, successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "MBGeofencing", "startMonitoringRegion", [identifier, lat, lon, radius]);
    },
    /**
    * Stops monitoring a circular region
    *
    * @param {String} identifier            The identifier (or name) or the region for internal purposes
    * @param {Function} successCallback     The function to call when the position data is available
    * @param {Function} errorCallback       The function to call when there is an error getting the heading position. (OPTIONAL)
    */
    stopMonitoringRegion:function(identifier, successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "MBGeofencing", "stopMonitoringRegion", [identifier]);
    },
    /**
    * Stops monitoring all previously registered regions
    *
    * @param {Function} successCallback     The function to call when the position data is available
    * @param {Function} errorCallback       The function to call when there is an error getting the heading position. (OPTIONAL)
    */
    stopMonitoringAllRegions:function(successCallback, errorCallback) {
        cordova.exec(successCallback, errorCallback, "MBGeofencing", "stopMonitoringAllRegions", []);
    }
};
