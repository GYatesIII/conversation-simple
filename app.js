/**
 * Copyright 2015 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

var express = require('express'); // app server
var bodyParser = require('body-parser'); // parser for post requests
var Conversation = require('watson-developer-cloud/conversation/v1'); // watson sdk
var wcql = require('./public/js/wcql.js');

var app = express();

// Bootstrap application settings
app.use(express.static('./public')); // load UI from public folder
app.use(bodyParser.json());

// Create the service wrapper
var conversation = new Conversation({
  // If unspecified here, the CONVERSATION_USERNAME and CONVERSATION_PASSWORD env properties will be checked
  // After that, the SDK will fall back to the bluemix-provided VCAP_SERVICES environment property
  // username: '<username>',
  // password: '<password>',
  url: 'https://gateway.watsonplatform.net/conversation/api',
  version_date: '2016-10-21',
  version: 'v1'
});

// Endpoint to be call from the client side
app.post('/api/message', function(req, res) {
  var workspace = process.env.WORKSPACE_ID || '<workspace-id>';
  if (!workspace || workspace === '<workspace-id>') {
    return res.json({
      'output': {
        'text': 'The app has not been configured with a <b>WORKSPACE_ID</b> environment variable. Please refer to the ' + '<a href="https://github.com/watson-developer-cloud/conversation-simple">README</a> documentation on how to set this variable. <br>' + 'Once a workspace has been defined the intents may be imported from ' + '<a href="https://github.com/watson-developer-cloud/conversation-simple/blob/master/training/car_workspace.json">here</a> in order to get a working application.'
      }
    });
  }
  var payload = {
    workspace_id: workspace,
    context: req.body.context || {},
    input: req.body.input || {}
  };

  // Send the input to the conversation service
  conversation.message(payload, function(err, data) {
    if (err) {
      return res.status(err.code || 500).json(err);
    }

    var response = data;
    // if (!response.output || response.output.text[0] === "I'm sorry, I don't understand") {
    //   response.output = {};
    // } else {
    //   return response;
    // }

    if (response.intents && response.intents.length && response.entities && response.entities.length) {
      var cqlString = generateCql(response.entities);
      runCql(cqlString, function (error, resp, body) {
        if (!error && resp.statusCode == 200) {
          var result = JSON.parse(body);
          console.log(result);
          if (response.intents[0].intent == 'segment_profiles') {
            var ids = [];
            for (var profileI in result.data.profiles) {
              ids.push(result.data.profiles[profileI].id);
            }
            var text = "There are " + result.data.total + " profiles with the first five IDs: ";
            for (var idI in ids) {
              var text = text + ids[idI] + ", ";
            }
            var text = text + "<br>Parsed: " + cqlString;

            response.output.text = text;
          } else {
            response.output.text = "There are " + result.data.total + " profiles that match your question<br>Parsed CQL: " + cqlString;
          }

          return res.json(response);
        } else {
          return response;
        }
      });
      response.output.text = cqlString;
      return response;
    }

    return res.json(updateMessage(payload, data));
  });
});

/**
 * Updates the response text using the intent confidence
 * @param  {Object} input The request to the Conversation service
 * @param  {Object} response The response from the Conversation service
 * @return {Object}          The response with the updated message
 */
function updateMessage(input, response) {
  var responseText = null;
  if (!response.output || response.output.text[0] === "I'm sorry, I don't understand") {
    response.output = {};
  } else {
    return response;
  }

  if (response.intents && response.intents.length && response.entities && response.entities.length) {
    // var cqlString = generateCql(response.entities);
    // runCql(cqlString, function (error, resp, body) {
    //   if (!error && resp.statusCode == 200) {
    //     var result = JSON.parse(body);
    //     console.log(result);
    //     if (response.intents[0].intent == 'segment_profiles') {
    //       response.output.text = "There are " + result.data.total + " profiles | Parsed: " + cqlString;
    //     } else {
    //       response.output.text = "There are " + result.data.total + " profiles | Parsed: " + cqlString;
    //     }
    //   } else {
    //     return null;
    //   }
    // });
    response.output.text = cqlString;
    return response;
  }
}

/**
 * Updates the response text using the intent confidence
 * @param  {array} entities The entities from the Watson response
 * @return {string}         The CQL string
 */
function generateCql(entities, callback) {
  var entitiesString = [];
  for (var i = 0; i < entities.length; i++) {
    var entity = entities[i];
    var value = entity.value.replace(/([\\"])/g, '\\$1');
    entitiesString.push(entity.entity + ':"' + value + '"');
  }
  entitiesString = entitiesString.join(' ');
  try {
    return wcql.parse(entitiesString);
  } catch (exception) {
    return 'Failed to parse CQL';
  }
}

/**
 * Updates the response text using the intent confidence
 * @param  {string} entities The entities from the Watson response
 * @return {Object}          The server response
 */
function runCql(cqlString, callback) {
  // var parameters = {
  //   options: {
  //     url: 'https://back.crowdskout.com/segment',
  //     method: 'PUT',
  //     json: true,
  //     body: {
  //       query: cqlString,
  //       fields: [
  //         'FirstName',
  //         'LastName'
  //       ],
  //       offset: 0,
  //       limit: 5
  //     },
  //   }
  // };

  var request = require('request');

  var body = {
    query: cqlString,
    fields: [
      'FirstName',
      'LastName'
    ],
    offset: 0,
    limit: 5
  };
  var bodyString = JSON.stringify(body);
  // var options = {
  //   host: 'back.crowdskout.com',
  //   port: 443,
  //   path: '/segment',
  //   method: 'PUT',
  //   headers: {
  //     'Content-type': 'application/json',
  //     'token': '2bDjWzBQ0YjZ0TwgkFKfl7nlpnANdSCrt2WKLnsG'
  //   }
  // };

  var options = {
    url: 'https://back.crowdskout.com/segment',
    method: 'PUT',
    body: bodyString,
    headers: {
      'Content-type': 'application/json',
      'token': '2bDjWzBQ0YjZ0TwgkFKfl7nlpnANdSCrt2WKLnsG'
    }
  };

  return request(options, callback);

  //   , function (res) {
  //     res.setEncoding('utf8');
  //     res.on('data', function (chunk) {
  //       console.log('Response: ' + chunk)
  //     });
  //   });
  // segReq.write(bodyString);
  // segReq.end();

}

module.exports = app;
