
# pylint: disable=E0611
from iothub_client import IoTHubModuleClient, IoTHubTransportProvider
from iothub_client import IoTHubMessage, IoTHubMessageDispositionResult

import logging, json

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
    level=logging.INFO)

def send_confirmation_callback(message, result, user_context):
    logging.debug (f"Confirmation: id={user_context} received result = {result}")
    logging.debug (f"Data:  {message.get_string()}" )

def receive_message(message, callback):
    message_buffer = message.get_bytearray()
    size = len(message_buffer)
    message_str = message_buffer[:size].decode('utf-8')
    logging.info(f"Received: {message_str}" )

    callback(message_str)

    # we need to return this or bad things will happen
    return IoTHubMessageDispositionResult.ACCEPTED

class IoTMessaging:
    timeout = 10000

    def __init__(self):

        self.client = IoTHubModuleClient()
        self.client.create_from_environment(IoTHubTransportProvider.MQTT)

        # set the time until a message times out
        self.client.set_option("messageTimeout", self.timeout)
        self.output_queue = "iotHub"

    def send_event(self, event, send_context):

        self.client.send_event_async(self.output_queue, event, send_confirmation_callback, send_context)
        
    def send_to_output(self, event, output_name, send_context):
        self.client.send_event_async(output_name, event, send_confirmation_callback, send_context)

class IoTInferenceMessenger(IoTMessaging):
    def __init__(self):
        super().__init__()
        self.context = 0

    def send_inference(self, camId, classes, scores, bboxes, curtimename):

        if self.client is None or classes == []:
            return

        for classs, score, bbox in zip(classes, scores, bboxes):
            body = {"cameraId": camId, "time": curtimename, "cls": classs, "score": score}
            body["bbymin"] = bbox[0]
            body["bbxmin"] = bbox[1]
            body["bbymax"] = bbox[2]
            body["bbxmax"] = bbox[3]
            
            message_str = json.dumps(body)
            message = IoTHubMessage(message_str)
            message.properties().add("iothub-message-schema", "recognition;v1")
            message.properties().add("iothub-creation-time-utc", curtimename)
            self.context += 1

            self.send_event(message, self.context)

            logging.info(f"Sent: {body}")

    def send_upload(self, camId, featureCount, curtimename, proc_time):
        body = {"cameraId": camId, "time": curtimename, "procMsec": proc_time * 1000, "type": "jpg", "procType": "CPU"}
        body["featureCount"] = featureCount

        message_str = json.dumps(body)
        message = IoTHubMessage(message_str)
        message.properties().add("iothub-message-schema", "image-upload;v1")
        message.properties().add("iothub-creation-time-utc", curtimename)
        self.context += 1

        self.send_event(message, self.context)

        logging.info(f"Sent: {body}")

