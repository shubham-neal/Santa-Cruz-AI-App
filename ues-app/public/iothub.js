const WebSocket = require('ws')
const wss = new WebSocket.Server({ port: 8080 })
const { EventHubClient, EventPosition } = require('@azure/event-hubs');
const connectionString = 'HostName=iot-unifiededge-001.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=kvujEICkipUjqIOi+fDfjyy9yYByy3Ge8QYoz5BhEWk=';
// 'Endpoint=sb://unifiededge.servicebus.windows.net/;SharedAccessKeyName=iothubroutes_iot-unifiededge-001;SharedAccessKey=5+KdOjkqQ1LFZkp2VCX2WQBRFZ2F71gyLueTbhPplr0=;EntityPath=uploadhub'
// https://ms.portal.azure.com/#blade/Microsoft_Azure_IotHub/StandaloneFrameBlade/path/%2Fdevices%2Fdevice%3FdeviceId%3Dbrain-box%26edgeDevice%3Dtrue/title/brain-box/resourceId/%2Fsubscriptions%2F7c9469c0-29ac-424a-85ab-d01f2cea1c38%2FresourceGroups%2Frg-unifiededge-dev-001%2Fproviders%2FMicrosoft.Devices%2FIotHubs%2Fiot-unifiededge-001
let eventHubClient;
let webSocket = null;
wss.on('connection', ws => {
    ws.on('message', message => {
        console.log(`Received message => ${message}`);
    });
    webSocket = ws;
    console.log('Hello! Message From Server!!');
})

EventHubClient
    .createFromIotHubConnectionString(connectionString)
    .then((client) => {
        eventHubClient = client;
        return eventHubClient.getPartitionIds();
    })
    .then((ids) => {
        console.log("The partition ids are: ", ids);
        console.log('');
        return ids.map((id) => {
            return eventHubClient.receive(
                id,
                (message) => {
                    // console.log("START OF MESSAGE");
                    console.log(JSON.stringify(message));
                    // console.log(`partition id: ${id}`);
                    if (message.hasOwnProperty("body") && message.body.hasOwnProperty("detections")) {
                        // console.log(JSON.stringify(message.body));
                        webSocket.send(JSON.stringify(message));
                    } else if(message.hasOwnProperty("applicationProperties") && message.applicationProperties.hasOwnProperty("type")) {
                        // console.log(JSON.stringify(message));
                        webSocket.send(JSON.stringify(message));
                    }
                    // console.log("END OF MESSAGE");
                    //webSocket.send(JSON.stringify(message));
                },
                (error) => {
                    console.log(error);
                },
                {
                    eventPosition: EventPosition.fromEnqueuedTime(Date.now())
                });
        });
    })
    .catch((error) => {
        console.log(error);
    });
