import ballerinax/trigger.asgardeo;
import ballerina/log;
import ballerinax/salesforce;
import ballerina/http;

// Create Salesforce client configuration by reading from environment.
configurable string clientId = "3MVG9WVXk15qiz1LXVcaGvsNQeTi36.LwOcKMSWRZrew6uoBnnccPtGaFuBaCd6py9QIeWwNxxEOjdoc.fjeN";
configurable string clientSecret = "A3FBBCFD891F4990E7C5F93C59BF98A77DC843FBB1C9319D057385654EFC6573";
configurable string refreshToken = "5Aep861iCXbTx3lghSuFmJNOdQvwTpfRk8ZLfDM02_wYKyX0gylS1vumDzIziO7nhDRYDJtFqlVfQb6VscFaSkP";
configurable string refreshUrl = "https://wso230-dev-ed.develop.my.salesforce.com/services/oauth2/token";
configurable string baseUrl = "https://wso230-dev-ed.develop.my.salesforce.com";

// Using direct-token config for client configuration
salesforce:ConnectionConfig sfConfig = {
    baseUrl,
    auth: {
        clientId,
        clientSecret,
        refreshToken,
        refreshUrl
    }
};

configurable asgardeo:ListenerConfig config = ?;

listener http:Listener httpListener = new(8090);
listener asgardeo:Listener webhookListener =  new(config,httpListener);

service asgardeo:RegistrationService on webhookListener {

    remote function onAddUser(asgardeo:AddUserEvent event ) returns error? {

        salesforce:Client baseClient = check new (sfConfig);

        record {} leadRecord = {
            "Email": event.get("userName"),
            "Company": "WSO2",
            "FirstName": "Lead First Name",
            "LastName": "Lead Last Name"
        };

        salesforce:CreationResponse|error res = baseClient->create("Lead", leadRecord);

        if res is salesforce:CreationResponse {
            log:printInfo("Account Created Successfully. Account ID : " + res.id);
        } else {
            log:printError(msg = res.message());
        }
        log:printInfo(event.toJsonString());
    }

    remote function onConfirmSelfSignup(asgardeo:GenericEvent event ) returns error? {

        log:printInfo(event.toJsonString());
    }

    remote function onAcceptUserInvite(asgardeo:GenericEvent event ) returns error? {

        log:printInfo(event.toJsonString());
    }
}

service /ignore on httpListener {}

