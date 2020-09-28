// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <iostream>
#include <stdio.h>
#include <stdlib.h>

#include "iothub_module_client_ll.h"
#include "iothub_message.h"
#include "azure_c_shared_utility/threadapi.h"
#include "azure_c_shared_utility/crt_abstractions.h"
#include "azure_c_shared_utility/platform.h"
#include "azure_c_shared_utility/shared_util_options.h"
#include "iothub_client_options.h"
#include "iothubtransportmqtt.h"
#include "iothub.h"
#include "parson.h"

#include "helper.hpp"
#include "rtsp.hpp"

void update_model(std::string data);
void set_running(bool data);

int telemetry_interval = 10;

static IOTHUB_MODULE_CLIENT_LL_HANDLE iotHubModuleClientHandle;
static int callbackCounter;

typedef struct EVENT_INSTANCE_TAG
{
    IOTHUB_MESSAGE_HANDLE messageHandle;
    size_t messageTrackingId;  // For tracking the messages within the user callback.
} EVENT_INSTANCE;

static void SendConfirmationCallback(IOTHUB_CLIENT_CONFIRMATION_RESULT result, void* userContextCallback)
{
    // The context corresponds to which message# we were at when we sent.
    /*
    try {
        EVENT_INSTANCE* messageInstance = (EVENT_INSTANCE*)userContextCallback;
        //printf("Confirmation[%zu] received for message with result = %d\r\n", messageInstance->messageTrackingId, result);
        if (messageInstance != NULL && messageInstance->messageHandle != NULL) {
            //IoTHubMessage_Destroy(messageInstance->messageHandle);
            free(messageInstance);
        }
    }
    catch (const char* msg) {
        std::cout << msg << std::endl;
    }
    */
}

static void ModuleTwinCallback(DEVICE_TWIN_UPDATE_STATE update_state, const unsigned char* payLoad, size_t size, void* userContextCallback)
{
    log_info("module twin callback called with (state=" +
        std::string(MU_ENUM_TO_STRING(DEVICE_TWIN_UPDATE_STATE, update_state)) +
        ", size=" +
        std::to_string(size) +
        "): " +
        reinterpret_cast<const char*>(payLoad));

    JSON_Value* root_value = json_parse_string(reinterpret_cast<const char*>(payLoad));
    JSON_Object* root_object = json_value_get_object(root_value);

    if (json_object_dotget_value(root_object, "desired.Logging") != NULL)
    {
        set_logging(json_object_dotget_boolean(root_object, "desired.Logging"));
    }
    if (json_object_get_value(root_object, "Logging") != NULL)
    {
        set_logging(json_object_get_boolean(root_object, "Logging"));
    }

    if (json_object_dotget_value(root_object, "desired.ModelZipUrl") != NULL)
    {
        update_model(json_object_dotget_string(root_object, "desired.ModelZipUrl"));
    }
    if (json_object_get_value(root_object, "ModelZipUrl") != NULL)
    {
        update_model(json_object_get_string(root_object, "ModelZipUrl"));
    }

    //if (json_object_dotget_value(root_object, "desired.Running") != NULL)
    //{
    //    set_running(json_object_dotget_boolean(root_object, "desired.Running"));
    //}
    //if (json_object_get_value(root_object, "Running") != NULL)
    //{
    //    set_running(json_object_get_boolean(root_object, "Running"));
    //}

    if (json_object_dotget_value(root_object, "desired.RawStream") != NULL)
    {
        set_raw_stream(json_object_dotget_boolean(root_object, "desired.RawStream"));
    }
    if (json_object_get_value(root_object, "RawStream") != NULL)
    {
        set_raw_stream(json_object_get_boolean(root_object, "RawStream"));
    }

    if (json_object_dotget_value(root_object, "desired.ResultStream") != NULL)
    {
        set_result_stream(json_object_dotget_boolean(root_object, "desired.ResultStream"));
    }
    if (json_object_get_value(root_object, "ResultStream") != NULL)
    {
        set_result_stream(json_object_get_boolean(root_object, "ResultStream"));
    }

    if (json_object_dotget_value(root_object, "desired.TelemetryInterval") != NULL)
    {
        telemetry_interval = json_object_dotget_number(root_object, "desired.TelemetryInterval");
        log_info("telemetry_interval: " + std::to_string(telemetry_interval));
    }
    if (json_object_get_value(root_object, "TelemetryInterval") != NULL)
    {
        telemetry_interval = json_object_get_number(root_object, "TelemetryInterval");
        log_info("telemetry_interval: " + std::to_string(telemetry_interval));
    }
}

void send_message(const char* msg)
{
    if (iotHubModuleClientHandle == NULL) {
        return;
    }

    // Send D2C messages every 10 frames
    if (callbackCounter > telemetry_interval) {
        callbackCounter = 0;
    }
    callbackCounter++;
    if (callbackCounter > 1) {
        return;
    }

    EVENT_INSTANCE messageInstance;

    // Uncomment the following lines to enable verbose logging (e.g., for debugging).
    // bool traceOn = true;
    // IoTHubModuleClient_LL_SetOption(iotHubModuleClientHandle, OPTION_LOG_TRACE, &traceOn);

    //sprintf_s(msgText, sizeof(msgText), msg);
    if ((messageInstance.messageHandle = IoTHubMessage_CreateFromString(msg)) == NULL)
    {
        log_error("iotHubMessageHandle is NULL!");
    }
    else
    {
        (void)IoTHubMessage_SetMessageId(messageInstance.messageHandle, "MSG_ID");
        (void)IoTHubMessage_SetCorrelationId(messageInstance.messageHandle, "CORE_ID");

        messageInstance.messageTrackingId = 1;

        /*
        MAP_HANDLE propMap = IoTHubMessage_Properties((messageInstance.messageHandle);
        (void)sprintf_s(propText, sizeof(propText), temperature > 28 ? "true" : "false");
        Map_AddOrUpdate(propMap, "temperatureAlert", propText);
        */

        if (IoTHubModuleClient_LL_SendEventToOutputAsync(iotHubModuleClientHandle, messageInstance.messageHandle, "AzureEyeModuleOutput", SendConfirmationCallback, &messageInstance) != IOTHUB_CLIENT_OK)
        {
            log_error("IoTHubModuleClient_LL_SendEventAsync..........FAILED!");
        }
        else
        {
            //(void)printf("IoTHubModuleClient_LL_SendEventAsync accepted message [%d] for transmission to IoT Hub.\r\n", (int)0);
        }
    }
    IoTHubModuleClient_LL_DoWork(iotHubModuleClientHandle);
    ThreadAPI_Sleep(5);
}

void start_iot()
{
    iotHubModuleClientHandle = NULL;

    if (IoTHub_Init() != 0)
    {
        log_error("failed to initialize the platform.");
        return;
    }
    else if ((iotHubModuleClientHandle = IoTHubModuleClient_LL_CreateFromEnvironment(MQTT_Protocol)) == NULL)
    {
        log_error("iotHubModuleClientHandle is NULL!");
    }
    else if (IoTHubModuleClient_LL_SetModuleTwinCallback(iotHubModuleClientHandle, ModuleTwinCallback, (void*)iotHubModuleClientHandle) != IOTHUB_CLIENT_OK)
    {
        log_error("IoTHubModuleClient_LL_SetModuleTwinCallback(default)..........FAILED!");
    }

    return;
}

void stop_iot()
{
    if (iotHubModuleClientHandle == NULL) {
        return;
    }

    IoTHubModuleClient_LL_Destroy(iotHubModuleClientHandle);
    log_info("finished executing");
    IoTHub_Deinit();
    return;
}