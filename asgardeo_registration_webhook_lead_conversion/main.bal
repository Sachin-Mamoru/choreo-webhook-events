import ballerinax/trigger.asgardeo;
import ballerina/log;
import ballerinax/salesforce;
import ballerinax/salesforce.soap;
import ballerina/http;

// Create Salesforce client configuration by reading from environment.
configurable string salesforceAppClientId = ?;
configurable string salesforceAppClientSecret = ?;
configurable string salesforceAppRefreshToken = ?;
configurable string salesforceAppRefreshUrl = ?;
configurable string salesforceAppBaseUrl = ?;

// Using direct-token config for client configuration
salesforce:ConnectionConfig sfConfig = {
    baseUrl: salesforceAppBaseUrl,
    auth: {
        clientId: salesforceAppClientId,
        clientSecret: salesforceAppClientSecret,
        refreshToken: salesforceAppRefreshToken,
        refreshUrl: salesforceAppRefreshUrl
    }
};

salesforce:Client baseClient = check new (sfConfig);
soap:Client soapClient = check new(sfConfig);

configurable asgardeo:ListenerConfig config = ?;

listener http:Listener httpListener = new(8090);
listener asgardeo:Listener webhookListener =  new(config,httpListener);

service asgardeo:LoginService on webhookListener {
  
    remote function onLoginSuccess(asgardeo:LoginSuccessEvent event ) returns error? {

        salesforce:Client baseClient = check new (sfConfig);

        log:printInfo(event.toJsonString());
        
        json responseData = event.eventData.toJson();

        map<json> mj = <map<json>> responseData;
        map<json> userClaims = <map<json>> mj.get("claims");

        string email = <string>userClaims["http://wso2.org/claims/emailaddress"];
        
        string sampleQuery = string `SELECT AccountID FROM Contact WHERE Email = '${email}'`;
        stream<record {}, error?> queryResults = check baseClient->query(sampleQuery);
        
        int nLines = 0;
        string recordId;
        check from record {} rd in queryResults
            do {
                recordId = check rd.toJson().AccountId;
                nLines += 1;
            };

        if (nLines != 0) {
            return error("Account already exists");
        }

        sampleQuery = string `SELECT Id FROM Lead WHERE Email = '${email}'`;
        queryResults = check baseClient->query(sampleQuery);
        
        int nLines2 = 0;
        check from record {} rd in queryResults
            do {
                recordId = check rd.toJson().Id;
                nLines2 += 1;
            };

        if (nLines2 == 0) {
            return error("Lead not found");
        }
        
        soap:ConvertedLead _ = check soapClient->convertLead({leadId: recordId, convertedStatus: "Closed - Converted"});
        log:printInfo("Lead converted successfully");
    }
}

service /ignore on httpListener {}

