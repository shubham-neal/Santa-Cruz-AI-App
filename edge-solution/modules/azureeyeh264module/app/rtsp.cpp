// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <iostream>
#include <string>
#include <queue>

#include <gst/gst.h>
#include <gst/rtsp-server/rtsp-server.h>

#include <opencv2/core/utility.hpp>
#include <opencv2/imgproc.hpp>

#include "helper.hpp"
#include "rtsp.hpp"

const int H264_FPS = 24;
const int RAW_FPS = 10;
const int RESULT_FPS = 10;

bool raw_stream = true;
bool result_stream = true;

cv::Mat raw(616, 816, CV_8UC3, cv::Scalar(0, 0, 0));
cv::Mat result(616, 816, CV_8UC3, cv::Scalar(0, 0, 0));
cv::Mat empty(616, 816, CV_8UC3, cv::Scalar(0, 0, 0));

std::queue<H264> h264_queue;

typedef struct
{
    gboolean white;
    GstClockTime timestamp;
} MyContext;

void update_data_raw(cv::Mat mat)
{
    mat.copyTo(raw);
}

void update_data_result(cv::Mat mat)
{
    mat.copyTo(result);
}

void set_raw_stream(bool data)
{
    raw_stream = data;
    log_info("raw_stream: " + std::to_string(raw_stream));
}

void set_result_stream(bool data)
{
    result_stream = data;
    log_info("result_stream: " + std::to_string(result_stream));
}

void update_data_h264(H264 frame)
{
    while (h264_queue.size() > 2 * H264_FPS)
    {
        h264_queue.pop();
    }

    h264_queue.push(frame);
}

/* called when we need to give data to appsrc */
void need_data_raw(GstElement* appsrc, guint unused, MyContext* ctx)
{
    GstBuffer* buffer;
    GstFlowReturn ret;

    if (raw_stream)
    {
        guint size = raw.size().width * raw.size().height * raw.channels();
        buffer = gst_buffer_new_allocate(NULL, size, NULL);

        gst_buffer_fill(buffer, 0, raw.data, size);
    }
    else
    {
        guint size = empty.size().width * empty.size().height * empty.channels();
        buffer = gst_buffer_new_allocate(NULL, size, NULL);

        gst_buffer_fill(buffer, 0, empty.data, size);
    }

    /* increment the timestamp */
    GST_BUFFER_PTS(buffer) = ctx->timestamp;
    GST_BUFFER_DURATION(buffer) = gst_util_uint64_scale_int(1, GST_SECOND, RAW_FPS);
    ctx->timestamp += GST_BUFFER_DURATION(buffer);

    g_signal_emit_by_name(appsrc, "push-buffer", buffer, &ret);
    gst_buffer_unref(buffer);

    log_debug("RTSP buffer pushed to raw with timestamp " + std::to_string(ctx->timestamp / 1000000) + " (ms)");
}

/* called when we need to give data to appsrc */
void need_data_result(GstElement* appsrc, guint unused, MyContext* ctx)
{

    GstBuffer* buffer;
    GstFlowReturn ret;

    if (result_stream)
    {
        guint size = result.size().width * result.size().height * result.channels();
        buffer = gst_buffer_new_allocate(NULL, size, NULL);

        gst_buffer_fill(buffer, 0, result.data, size);
    }
    else
    {
        guint size = empty.size().width * empty.size().height * empty.channels();
        buffer = gst_buffer_new_allocate(NULL, size, NULL);

        gst_buffer_fill(buffer, 0, empty.data, size);
    }

    /* increment the timestamp */
    GST_BUFFER_PTS(buffer) = ctx->timestamp;
    GST_BUFFER_DURATION(buffer) = gst_util_uint64_scale_int(1, GST_SECOND, RESULT_FPS);
    ctx->timestamp += GST_BUFFER_DURATION(buffer);

    g_signal_emit_by_name(appsrc, "push-buffer", buffer, &ret);
    gst_buffer_unref(buffer);

    log_debug("RTSP buffer pushed to result with timestamp " + std::to_string(ctx->timestamp / 1000000) + " (ms)");
}

/* called when we need to give data to appsrc */
void need_data_h264(GstElement* appsrc, guint unused, MyContext* ctx)
{
    GstBuffer* buffer;
    GstFlowReturn ret;

    while (!h264_queue.empty()) {
        H264 frame = h264_queue.front();
        // frame.data = *out_h264;
        // frame.timestamp = *out_h264_ts;

        // std::vector<uint8_t> vec = h264_queue.front();
        guint size = frame.data.size();

        buffer = gst_buffer_new_allocate(NULL, size, NULL);
        gst_buffer_fill(buffer, 0, frame.data.data(), size);

        /* increment the timestamp */
        GST_BUFFER_PTS(buffer) = frame.timestamp;
        GST_BUFFER_DURATION(buffer) = gst_util_uint64_scale_int(1, GST_SECOND, H264_FPS);

        g_signal_emit_by_name(appsrc, "push-buffer", buffer, &ret);
        gst_buffer_unref(buffer);

        if (ret != GstFlowReturn::Ok)
        {
            // push failed. stop for now.
            break;
        }

        h264_queue.pop();
        log_debug("RTSP buffer pushed to h264 with size " + std::to_string(size) + " and timestamp " + std::to_string(frame.timestamp));

    }
    
}

/* called when a new media pipeline is constructed. We can query the
 * pipeline and configure our appsrc */
void media_configure_raw(GstRTSPMediaFactory* factory, GstRTSPMedia* media, gpointer user_data)
{
    log_info("RTSP client connected to raw factory");

    GstElement* element, * appsrc;
    MyContext* ctx;

    /* get the element used for providing the streams of the media */
    element = gst_rtsp_media_get_element(media);

    /* get our appsrc, we named it 'mysrc' with the name property */
    appsrc = gst_bin_get_by_name_recurse_up(GST_BIN(element), "mysrc");

    /* this instructs appsrc that we will be dealing with timed buffer */
    gst_util_set_object_arg(G_OBJECT(appsrc), "format", "time");
    /* configure the caps of the video */
    g_object_set(G_OBJECT(appsrc), "caps",
        gst_caps_new_simple("video/x-raw",
            "format", G_TYPE_STRING, "BGR",
            "width", G_TYPE_INT, 816,
            "height", G_TYPE_INT, 616,
            "framerate", GST_TYPE_FRACTION, RAW_FPS, 1, NULL),
        NULL);

    ctx = g_new0(MyContext, 1);
    ctx->white = FALSE;
    ctx->timestamp = 0;
    /* make sure ther datais freed when the media is gone */
    g_object_set_data_full(G_OBJECT(media), "my-extra-data", ctx,
        (GDestroyNotify)g_free);

    /* install the callback that will be called when a buffer is needed */
    g_signal_connect(appsrc, "need-data", (GCallback)need_data_raw, ctx);
    gst_object_unref(appsrc);
    gst_object_unref(element);
}

/* called when a new media pipeline is constructed. We can query the
 * pipeline and configure our appsrc */
void media_configure_result(GstRTSPMediaFactory* factory, GstRTSPMedia* media, gpointer user_data)
{
    log_info("RTSP client connected to result factory");

    GstElement* element, * appsrc;
    MyContext* ctx;

    /* get the element used for providing the streams of the media */
    element = gst_rtsp_media_get_element(media);

    /* get our appsrc, we named it 'mysrc' with the name property */
    appsrc = gst_bin_get_by_name_recurse_up(GST_BIN(element), "mysrc");

    /* this instructs appsrc that we will be dealing with timed buffer */
    gst_util_set_object_arg(G_OBJECT(appsrc), "format", "time");
    /* configure the caps of the video */
    g_object_set(G_OBJECT(appsrc), "caps",
        gst_caps_new_simple("video/x-raw",
            "format", G_TYPE_STRING, "BGR",
            "width", G_TYPE_INT, 816,
            "height", G_TYPE_INT, 616,
            "framerate", GST_TYPE_FRACTION, RESULT_FPS, 1, NULL),
        NULL);

    ctx = g_new0(MyContext, 1);
    ctx->white = FALSE;
    ctx->timestamp = 0;
    /* make sure ther datais freed when the media is gone */
    g_object_set_data_full(G_OBJECT(media), "my-extra-data", ctx,
        (GDestroyNotify)g_free);

    /* install the callback that will be called when a buffer is needed */
    g_signal_connect(appsrc, "need-data", (GCallback)need_data_result, ctx);
    gst_object_unref(appsrc);
    gst_object_unref(element);
}

/* called when a new media pipeline is constructed. We can query the
 * pipeline and configure our appsrc */
void media_configure_h264(GstRTSPMediaFactory* factory, GstRTSPMedia* media, gpointer user_data)
{
    log_info("RTSP client connected to h264 factory");

    GstElement* element, * appsrc;
    MyContext* ctx;

    /* get the element used for providing the streams of the media */
    element = gst_rtsp_media_get_element(media);

    /* get our appsrc, we named it 'mysrc' with the name property */
    appsrc = gst_bin_get_by_name_recurse_up(GST_BIN(element), "mysrc");

    /* this instructs appsrc that we will be dealing with timed buffer */
    gst_util_set_object_arg(G_OBJECT(appsrc), "format", "time");
    /* configure the caps of the video */
    g_object_set(G_OBJECT(appsrc), "caps",
        gst_caps_new_simple("video/x-h264",
            "stream-format", G_TYPE_STRING, "byte-stream",
            "width", G_TYPE_INT, 3264,
            "height", G_TYPE_INT, 2464,
            "framerate", GST_TYPE_FRACTION, H264_FPS, 1, NULL),
        NULL);

    ctx = g_new0(MyContext, 1);
    ctx->white = FALSE;
    ctx->timestamp = 0;
    /* make sure ther datais freed when the media is gone */
    g_object_set_data_full(G_OBJECT(media), "my-extra-data", ctx,
        (GDestroyNotify)g_free);

    /* install the callback that will be called when a buffer is needed */
    g_signal_connect(appsrc, "need-data", (GCallback)need_data_h264, ctx);
    gst_object_unref(appsrc);
    gst_object_unref(element);
}

void* gst_rtsp_server_thread(void*)
{
    GMainLoop* loop;
    GstRTSPServer* server;
    GstRTSPMountPoints* mounts;
    GstRTSPMediaFactory* factory;

    put_text(raw, "No Video");
    put_text(result, "No Video");
    put_text(empty, "Stream Closed");

    // gst_init (&argc, &argv);
    gst_init(NULL, NULL);

    loop = g_main_loop_new(NULL, FALSE);

    /* create a server instance */
    server = gst_rtsp_server_new();

    /* get the mount points for this server, every server has a default object
   * that be used to map uri mount points to media factories */
    mounts = gst_rtsp_server_get_mount_points(server);

    /* make a media factory for a test stream. The default media factory can use
   * gst-launch syntax to create pipelines.
   * any launch line works as long as it contains elements named pay%d. Each
   * element with pay%d names will be a stream */
    factory = gst_rtsp_media_factory_new();
    gst_rtsp_media_factory_set_launch(factory,
        "( appsrc name=mysrc ! videoconvert ! video/x-raw,format=I420 ! jpegenc ! rtpjpegpay name=pay0 pt=96 )");

    /* notify when our media is ready, This is called whenever someone asks for
   * the media and a new pipeline with our appsrc is created */
    g_signal_connect(factory, "media-configure", (GCallback)media_configure_raw,
        NULL);

    /* attach the test factory to the /raw url */
    gst_rtsp_mount_points_add_factory(mounts, "/raw", factory);

    /* make another factory */
    factory = gst_rtsp_media_factory_new();
    gst_rtsp_media_factory_set_launch(factory,
        "( appsrc name=mysrc ! videoconvert ! video/x-raw,format=I420 ! jpegenc ! rtpjpegpay name=pay0 pt=96 )");

    /* notify when our media is ready, This is called whenever someone asks for
   * the media and a new pipeline with our appsrc is created */
    g_signal_connect(factory, "media-configure", (GCallback)media_configure_result,
        NULL);

    /* attach the test factory to the /result url */
    gst_rtsp_mount_points_add_factory(mounts, "/result", factory);

    /* make another factory */
    factory = gst_rtsp_media_factory_new();
    gst_rtsp_media_factory_set_launch(factory,
        "( appsrc name=mysrc ! h264parse ! rtph264pay name=pay0 pt=96 )");

    /* notify when our media is ready, This is called whenever someone asks for
   * the media and a new pipeline with our appsrc is created */
    g_signal_connect(factory, "media-configure", (GCallback)media_configure_h264,
        NULL);

    /* attach the test factory to the /result url */
    gst_rtsp_mount_points_add_factory(mounts, "/h264", factory);

    /* don't need the ref to the mounts anymore */
    g_object_unref(mounts);

    /* attach the server to the default maincontext */
    gst_rtsp_server_attach(server, NULL);

    /* start serving */
    log_info("stream ready at rtsp://127.0.0.1:8554/raw");
    log_info("stream ready at rtsp://127.0.0.1:8554/result");
    log_info("stream ready at rtsp://127.0.0.1:8554/h264");
    g_main_loop_run(loop);

    return NULL;
}