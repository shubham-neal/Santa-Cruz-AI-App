// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

typedef struct {
   std::vector<uint8_t> data;
   int64_t timestamp;
} H264;

void* gst_rtsp_server_thread(void*);

void set_raw_stream(bool);

void set_result_stream(bool);

void update_data_raw(cv::Mat mat);

void update_data_result(cv::Mat mat);

void update_data_h264(H264 frame);