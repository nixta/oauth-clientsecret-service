oauth-appsecret-server
======================

A simple Express.js OAuth provider which takes an Application ID and some authentication token which, once matched, results in a negotiated App Login based Token for ArcGIS Online.

Included is an ArcGIS Runtime for iOS Sample client.

# Installation
Modify the JSON configuration in app.js to specify a Client ID and Client Secret. This sample operates on matching well known text, but in practice you would modify the service to handle some other kind of authentication.

```javascript
var clientsDetails = {
	"OeGPy3X6ERqWPNFS": { // <-- Client ID
		"authString": "I could be a username and password.",
		"secret": "<< INSERT CLIENT SECRET HERE >>" // <-- Client Secret
	}
};
```

See [this page](https://developers.arcgis.com/en/authentication/app-logins.html) for more details.
