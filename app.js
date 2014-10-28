var express = require('express'),
  app = express(),
  https = require('https'),
  bodyParser = require('body-parser'),
  querystring = require('querystring');

// Get the Client ID and Client Secret from https://developers.arcgis.com/en/applications/
var clientsDetails = {
  'OeGPy3X6ERqWPNFS': { // <-- Client ID
    authString: 'I could be a username and password.',
    appSecret: '<< INSERT CLIENT SECRET HERE >>' // <-- Client Secret
  }
};

for (var clientId in clientsDetails) {
  var clientDetails = clientsDetails[clientId];
  clientDetails.tokenInfo = {};
}

app.disable("x-powered-by");

var allowCrossDomain = function(req, res, next) {
  // ## CORS middleware
  //
  // see: http://stackoverflow.com/questions/7067966/how-to-allow-cors-in-express-nodejs
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  // intercept OPTIONS method
  if ('OPTIONS' == req.method) {
    res.send(200);
  } else {
    next();
  }
};

app.use(allowCrossDomain);

app.use(express.static(__dirname, {
  maxAge: 31557600000
}));

app.post('/oauth', bodyParser.json(), function onRequest(request, response) {
  var clientID = request.body.clientID;

  if (!clientsDetails.hasOwnProperty(clientID)) {
    response.status(501).send('Invalid Client ID');
  } else {
    // We know how to handle this Client
    var authString = request.body.authString;
    var clientDetails = clientsDetails[clientID];

    if (authString !== clientDetails.authString) {
      response.status(501).send('Invalid Client Secret');
    } else {
      // OK. We're good to ask for a token if we don't have one
      var tokenInfo = clientDetails.tokenInfo;
      var token = '';
      var haveValidToken = false;
      if (tokenInfo.hasOwnProperty('token')) {
        // Is the token still valid?
        if (tokenInfo.expiration > new Date()) {
          haveValidToken = true;
        }
      }
      if (haveValidToken) {
        respondSuccess(response, tokenInfo);
      } else {
        // Send data to the AGOL Token Server
        var tokenPostData = querystring.stringify({
          'client_id': clientID,
          'client_secret': clientDetails.appSecret,
          'grant_type': 'client_credentials',
          'expiration': 15 * 24 * 60
        });

        var options = {
          hostname: 'www.arcgis.com',
          path: '/sharing/oauth2/token',
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': tokenPostData.length
          }
        };

        var authReq = https.request(options, function(res) {
          res.setEncoding('utf8');

          var authJSON = '';
          res.on('data', function(chunk) {
            authJSON = authJSON + chunk;
          });

          res.on('end', function() {
            var auth = JSON.parse(authJSON);
            if (auth.hasOwnProperty('error')) {
              response.status(501).send(auth.error.code + ' : ' + auth.error.error_description);
            } else {
              tokenInfo.token = auth.access_token;
              var expires_in = auth.expires_in; // minutes
              var expirationMS = (new Date()).getTime() + (expires_in * 1000);
              tokenInfo.expirationUTC = expirationMS;

              respondSuccess(response, tokenInfo);
            }
          });
        });

        authReq.write(tokenPostData);
        authReq.end();
      }
    }
  }
});

var respondSuccess = function(response, tokenInfo) {
  response.status(200).send(tokenInfo);
};

app.listen(process.env.VCAP_APP_PORT || 1337, function() {
  console.log('Listening at http://%s:%d/', this.address().address, this.address().port);
  console.log('Client IDs I know about:');
  console.log(Object.keys(clientsDetails));
});