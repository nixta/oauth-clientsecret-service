//
//  SampleViewController.m
//
//  Created by Nicholas Furness on 10/24/12.
//  Copyright (c) 2012 Esri. All rights reserved.
//

#import "SampleViewController.h"
#import <ArcGIS/ArcGIS.h>

@interface SampleViewController () <AGSLayerDelegate>
@property (weak, nonatomic) IBOutlet AGSMapView *mapView;
@property (nonatomic, strong) AGSLayer *zoomLayer;
@end

#define kClientId @"OeGPy3X6ERqWPNFS"
#define kAuthString @"I could be a username and password."

@implementation SampleViewController
- (void)viewDidLoad
{
    [super viewDidLoad];

	// Basemap Layer
	NSURL *basemapURL = [NSURL URLWithString:@"http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer"];
	AGSTiledMapServiceLayer *basemapLayer = [AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:basemapURL];
	[self.mapView addMapLayer:basemapLayer];

    // Public Bikes Layer
    NSURL *bikesSvcUrl = [NSURL URLWithString:@"http://geonode.geeknixta.com/citybikes/rest/services/citibikenyc/FeatureServer/0"];
    AGSFeatureLayer *bikes = [AGSFeatureLayer featureServiceLayerWithURL:bikesSvcUrl mode:AGSFeatureLayerModeOnDemand];
    [self.mapView addMapLayer:bikes];
    bikes.delegate = self;
    self.zoomLayer = bikes;
    
    // Now negotiate a token via OAuth handled with a node service.
    NSMutableURLRequest *tokenReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://localhost:1337/oauth"]];
    
    tokenReq.HTTPMethod = @"POST";
    NSDictionary *httpBody = @{
                                @"clientID": kClientId,
                                @"authString": kAuthString
                              };
    NSError *error = nil;
    NSString *errorResponse = nil;
    tokenReq.HTTPBody = [NSJSONSerialization dataWithJSONObject:httpBody
                                                        options:0
                                                          error:&error];
    tokenReq.allHTTPHeaderFields = @{@"Content-Type": @"application/json"};
    
    if (!error) {
        NSHTTPURLResponse *tokenResponse = nil;
        NSData *tokenData = [NSURLConnection sendSynchronousRequest:tokenReq
                                                  returningResponse:&tokenResponse
                                                              error:&error];
        if (tokenResponse.statusCode == 200 && !error) {
            NSDictionary *tokenInfo = [NSJSONSerialization JSONObjectWithData:tokenData
                                                                      options:0
                                                                        error:&error];
            if (!error)
            {
                NSString *token = tokenInfo[@"token"];
                NSNumber *tokenExpirationNum = tokenInfo[@"expirationUTC"];
                NSDate *tokenExpiration = [NSDate dateWithTimeIntervalSince1970:[tokenExpirationNum doubleValue]/1000];
                NSLog(@"Got a token that expires at %@: %@", [tokenExpiration descriptionWithLocale:[NSLocale currentLocale]], token);
                AGSCredential *cred = [[AGSCredential alloc] initWithToken:token];

                // This service is not shared publicly and relies on the negotiated token.
                NSURL *tilesURL = [NSURL URLWithString:@"http://services.arcgis.com/OfH668nDRN7tbJh0/arcgis/rest/services/NYCEvacZones2013_(Tiles)/MapServer"];
                AGSTiledMapServiceLayer *tiles = [AGSTiledMapServiceLayer tiledMapServiceLayerWithURL:tilesURL
                                                        credential:cred];
                tiles.delegate = self;
                tiles.opacity = 0.5;
                [self.mapView insertMapLayer:tiles atIndex:1];
            } else {
                errorResponse = [[NSString alloc] initWithData:tokenData encoding:NSUTF8StringEncoding];
            }
        } else {
            if (error) {
                errorResponse = error.description;
            } else {
                errorResponse = [[NSString alloc] initWithData:tokenData encoding:NSUTF8StringEncoding];
            }
        }
    }
    
    if (error || errorResponse) {
        NSLog(@"Error getting token: %@\n%@", error, errorResponse!=nil?errorResponse:error.description);
        // Give the user some feedback if something went wrong.
        [[[UIAlertView alloc] initWithTitle:@"Could not get token"
                                    message:errorResponse!=nil?errorResponse:error.description
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil, nil] show];
    }
}

-(void)layerDidLoad:(AGSLayer *)layer
{
    if (layer == self.zoomLayer) {
        AGSMutableEnvelope *newEnv = [layer.initialEnvelope mutableCopy];
        [newEnv expandByFactor:1.2];
        [self.mapView zoomToEnvelope:newEnv animated:YES];
    }
}

-(void)layer:(AGSLayer *)layer didFailToLoadWithError:(NSError *)error
{
    NSLog(@"Failed to load layer: %@\n%@", layer.name, error);
}
@end