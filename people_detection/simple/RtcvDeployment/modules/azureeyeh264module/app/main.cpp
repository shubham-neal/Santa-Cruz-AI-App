// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <string>
#include <vector>
#include <map>
#include <thread>

#include <opencv2/core/utility.hpp>
#include <opencv2/gapi/azure.hpp>
#include <opencv2/gapi/core.hpp>
#include <opencv2/gapi/infer.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/gapi/streaming/desync.hpp>

#include <VPUTempRead.hpp>

#include <libusb-1.0/libusb.h>
#include <parson.h>
#include <signal.h>

#include <cstdio>

#include "helper.hpp"
#include "parser.hpp"
#include "rtsp.hpp"
#include "send_messages.hpp"
#include "validator.h"

// STM32
const int mcu_vid = 0x045E;
const int mcu_pid = 0x066F;

// Myriad X
const int mx_vid = 0x03E7;
const int mx_pid = 0x2485;

// colors to be used for bounding boxes
std::vector<cv::Scalar> colors = {
        cv::Scalar(0, 0, 255), cv::Scalar(85, 0, 255), cv::Scalar(170, 0, 255),
        cv::Scalar(255, 0, 255), cv::Scalar(255, 0, 170), cv::Scalar(255, 0, 85),
        cv::Scalar(0, 255, 0), cv::Scalar(0, 255, 85), cv::Scalar(0, 255, 170),
        cv::Scalar(0, 255, 255), cv::Scalar(0, 170, 255), cv::Scalar(0, 85, 255),
        cv::Scalar(255, 0, 0), cv::Scalar(255, 85, 0), cv::Scalar(255, 170, 0),
        cv::Scalar(255, 255, 0), cv::Scalar(170, 255, 0), cv::Scalar(85, 255, 0)
};

bool restarting = false;
bool running = true;

std::string labelfile = "";
std::string modelfile = "";
std::string modelZipUrl = "";
std::string new_labelfile = "";
std::string new_parser = "";
std::string parser = "ssd100";
std::string status = "";
std::string resolution = "native";

std::vector<std::string> classes;

void load_label()
{
    std::ifstream file(labelfile);

    if (file.is_open())
    {
        classes.clear();

        std::string line;

        while (getline(file, line))
        {
            // remove \r in the end of line
            if (!line.empty() && line[line.size() - 1] == '\r')
            {
                line.erase(line.size() - 1);
            }

            classes.push_back(line);
        }

        file.close();
    }
}

void load_default()
{
    int ret = run_command("rm -rf /app/model && mkdir /app/model");

    if (ret != 0)
    {
        log_error("rm && mkdir failed with " + ret);
    }

    modelfile = "/app/data/ssd-mobilenet-v2-fp32.blob";

    new_labelfile = "/app/data/labels.txt";
    new_parser = "ssd100";

    restarting = true;
}

void load_config(std::string filename)
{
    JSON_Value* root_value = json_parse_file(filename.c_str());
    JSON_Object* root_object = json_value_get_object(root_value);

    if (json_object_get_value(root_object, "ModelFileName") != NULL)
    {
        modelfile = "/app/model/" + std::string(json_object_get_string(root_object, "ModelFileName"));
    }

    if (json_object_get_value(root_object, "DomainType") != NULL)
    {
        new_parser = to_lower(json_object_get_string(root_object, "DomainType"));
    }

    if (json_object_get_value(root_object, "LabelFileName") != NULL)
    {
        new_labelfile = "/app/model/" + std::string(json_object_get_string(root_object, "LabelFileName"));
    }
}

std::string get_label(int index)
{
    if (index < classes.size())
    {
        return classes[index];
    }
    else
    {
        return std::to_string(index);
    }
}

void convert_model()
{
    status = "Converting Model";

    int ret = run_command(("/openvino/bin/aarch64/Release/myriad_compile \
                     -m " + modelfile + " \
                     -ip U8 \
                     -VPU_MYRIAD_PLATFORM VPU_MYRIAD_2480 \
                     -VPU_NUMBER_OF_SHAVES 8 \
                     -VPU_NUMBER_OF_CMX_SLICES 8 \
                     -o /app/model/model.blob \
                     -op FP32").c_str());

    if (ret != 0)
    {
        log_error("myriad_compile failed with " + ret);
        load_default();
        return;
    }

    modelfile = "/app/model/model.blob";
}

void unzip_model()
{
    int ret = 0;

    ret = run_command(("unzip -o \"" + modelfile + "\" -d /app/model").c_str());

    if (ret != 0)
    {
        log_error("unzip failed with " + ret);
        load_default();
        return;
    }

    if (exist_file("/app/model/config.json"))
    {
        load_config("/app/model/config.json");
    }
    else if (exist_file("/app/model/cvexport.manifest"))
    {
        load_config("/app/model/cvexport.manifest");

        if (new_parser == "objectdetection")
        {
            if (search_keyword_in_file("mobilenetv2ssdlitev2_pytorch", "/app/model/model.xml"))
            {
                new_parser = "s1";
            }
            else
            {
                new_parser = "yolo";
            }
        }

        ret = run_command("python3 /app/update_cvs_openvino.py /app/model/model.xml /app/model/model.bin /app/model/out.bin && mv /app/model/out.bin /app/model/model.bin");

        if (ret != 0)
        {
            log_error("update_cvs_openvino.py && mv failed with " + ret);
            load_default();
            return;
        }

        modelfile = "/app/model/model.xml";
    }
    else
    {
        log_error("no config.json / cvexport.manifest");
        load_default();
        return;
    }

    if (modelfile.size() > 4 && modelfile.substr(modelfile.size() - 4, 4) == ".xml")
    {
        convert_model();
    }

    restarting = true;
}

void* download_model(void*)
{
    int ret = run_command(("wget --no-check-certificate -O /app/model/model.zip \"" + modelfile + "\"").c_str());

    if (ret != 0)
    {
        log_error("wget failed with " + ret);
        load_default();
        return NULL;
    }

    modelfile = "/app/model/model.zip";

    unzip_model();

    return NULL;
}

void load_model()
{
    int ret = run_command("rm -rf /app/model && mkdir /app/model");

    if (ret != 0)
    {
        log_error("rm && mkdir failed with " + ret);
        load_default();
        return;
    }

    if (std::string::npos != modelfile.find("https://"))
    {
        status = "Downloading Model";

        // create download thread
        pthread_t threadDownload;
        if (pthread_create(&threadDownload, NULL, download_model, NULL))
        {
            log_error("pthread_create(&threadDownload, NULL, download_model, NULL) failed");
            return;
        }
        else
        {
            log_info("download thread created");
        }
    }
    else if (std::string::npos != modelfile.find(".zip"))
    {
        unzip_model();
    }
    else if (std::string::npos != modelfile.find(".xml") && "" != new_labelfile && "" != new_parser)
    {
        convert_model();
    }
    else if (std::string::npos != modelfile.find(".blob") && "" != new_labelfile && "" != new_parser)
    {
        restarting = true;
    }
    else
    {
        load_default();
    }
}

void update_model(std::string data)
{
    if (modelZipUrl != data)
    {
        modelZipUrl = data;

        modelfile = data;
        log_info("modelfile: " + modelfile);

        load_model();
    }
}

void set_running(bool data)
{
    running = data;
    log_info("running: " + std::to_string(running));
}

namespace
{
    void preview(const cv::Mat& rgb, const std::vector<cv::Rect>& boxes, const std::vector<int>& labels, const std::vector<float>& confidences)
    {
        for (std::size_t i = 0; i < boxes.size(); i++)
        {
            // color of a label
            int index = labels[i] % colors.size();

            cv::rectangle(rgb, boxes[i], colors.at(index), 2);
            cv::putText(rgb,
                get_label(labels[i]) + ": " + to_string_with_precision(confidences[i], 2),
                boxes[i].tl() + cv::Point(3, 20),
                cv::FONT_HERSHEY_SIMPLEX,
                0.7,
                cv::Scalar(colors.at(index)),
                2);
        }
    }

    void preview(const cv::Mat& rgb, const std::vector<int>& labels, const std::vector<float>& confidences)
    {
        for (std::size_t i = 0; i < labels.size(); i++)
        {
            // color of a label
            int index = labels[i] % colors.size();

            cv::putText(rgb,
                get_label(labels[i]) + ": " + to_string_with_precision(confidences[i], 2),
                cv::Point(0, i * 20) + cv::Point(3, 20),
                cv::FONT_HERSHEY_SIMPLEX,
                0.7,
                cv::Scalar(colors.at(index)),
                2);
        }
    }

    //void preview(const cv::Mat& rgb)
    //{
    //    cv::putText(rgb,
    //        status,
    //        cv::Point(300, 20),
    //        cv::FONT_HERSHEY_SIMPLEX,
    //        0.7,
    //        cv::Scalar(0, 255, 0),
    //        2);
    //}
} // namespace

const std::string keys =
"{ h help   |        | print this message }"
"{ f mvcmd  |        | mvcmd firmware }"
"{ h264_out |        | Output file name for the raw H264 stream. No files written by default }"
"{ l label  |        | label file }"
"{ m model  |        | model zip file }"
"{ p parser | ssd100 | Parser kind required for input model. Possible values: ssd100, ssd200, yolo, classification, s1 }"
"{ s size   | native | Output video resolution. Possible values: native, 1080p, 720p }"
"{ show     | false  | Show output BGR image. Requires graphical environment }";

const std::map<std::string, cv::gapi::azure::Camera::Mode> modes = {
    {"native", cv::gapi::azure::Camera::MODE_NATIVE},
    {"1080p", cv::gapi::azure::Camera::MODE_1080P},
    {"720p", cv::gapi::azure::Camera::MODE_720P} };

// Configure G-API
G_API_NET(SingleOutput, <cv::GMat(cv::GMat)>, "single-output-detector");

using MOInfo = std::tuple<cv::GMat, cv::GMat>;
G_API_NET(MultiOutput, <MOInfo(cv::GMat)>, "multi-output-detector");

void interrupt(int sig)
{
    log_info("received interrupt signal");

    stop_validator();
    stop_iot();

    exit(0);
}

int main(int argc, char** argv)
{
    cv::CommandLineParser cmd(argc, argv, keys);

    if (cmd.has("help"))
    {
        cmd.printMessage();
        return 0;
    }

    // application parameters
    const auto opt_mvcmd = cmd.get<std::string>("mvcmd") != "" ? cmd.get<std::string>("mvcmd") : "/eyesom/AzureEyeMX.mvcmd";

    new_labelfile = cmd.get<std::string>("label");
    modelfile = cmd.get<std::string>("model");
    new_parser = cmd.get<std::string>("parser");
    resolution = cmd.get<std::string>("size");

    const auto opt_size = cmd.get<std::string>("size");
    const auto opt_show = cmd.get<bool>("show");
    const auto opt_h264_out = cmd.get<std::string>("h264_out");

    signal(SIGINT, interrupt);

    load_model();

    if (!libusb_open_device_with_vid_pid(NULL, mx_vid, mx_pid))
    {
        log_info("libusb_open_device_with_vid_pid VID 0x" + to_hex_string(mx_vid) + " PID 0x" + to_hex_string(mx_pid) + " failed");

        log_info("starting validator with VID 0x" + to_hex_string(mcu_vid) + " PID 0x" + to_hex_string(mcu_pid));
        start_validator(mcu_vid, mcu_pid);

        // wait for authentication
        while (true)
        {
            log_info("authentication status: " + std::to_string(check_som_status()));

            if (0 == check_som_status())
            {
                std::this_thread::sleep_for(std::chrono::seconds(1));
            }
            else
            {
                break;
            }
        }
    }
    else
    {
        log_info("libusb_open_device_with_vid_pid VID 0x" + to_hex_string(mx_vid) + " PID 0x" + to_hex_string(mx_pid) + " found");
    }

    // create RTSP thread
    pthread_t threadRTSP;
    if (pthread_create(&threadRTSP, NULL, gst_rtsp_server_thread, NULL))
    {
        log_error("pthread_create(&threadRTSP, NULL, gst_rtsp_server_thread, NULL) failed");
        return 0;
    }
    else
    {
        log_info("RTSP thread created");
    }

    start_iot();
    int count = 0;

    while (!restarting)
    {
        log_info("waiting...");
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }

    restarting = false;

    while (true)
    {
        // wait for MX
        while (true)
        {
            if (!libusb_open_device_with_vid_pid(NULL, mx_vid, mx_pid))
            {
                log_info("libusb_open_device_with_vid_pid VID 0x" + to_hex_string(mx_vid) + " PID 0x" + to_hex_string(mx_pid) + " failed");
                std::this_thread::sleep_for(std::chrono::seconds(1));
            }
            else
            {
                log_info("libusb_open_device_with_vid_pid VID 0x" + to_hex_string(mx_vid) + " PID 0x" + to_hex_string(mx_pid) + " found");
                break;
            }
        }

        labelfile = new_labelfile;
        load_label();
        parser = new_parser;

        log_info("blob: " + modelfile + ", firmware: " + opt_mvcmd + ", parser: " + parser + ", label: " + labelfile + ", classes: " + std::to_string((int)classes.size()));

        // Build the camera pipeline with G-API. Lambda-based constructor is used to keep all temporary objects in a dedicated scope
        cv::GComputation graph([]()
            {
                // Declare an empty GMat - the beginning of the pipeline
                cv::GMat in;
                cv::GMat preproc = cv::gapi::azure::preproc(in, modes.at(resolution));
                cv::GArray<uint8_t> h264;
                cv::GOpaque<int64_t> h264_seqno;
                cv::GOpaque<int64_t> h264_ts;
                std::tie(h264, h264_seqno, h264_ts) = cv::gapi::azure::encH264ts(preproc);

                // We have BGR output and H264 output in the same graph.
                // In this case, BGR always must be desynchronized from the main path
                // to avoid internal queue overflow (FW reports this data to us via
                // separate channels)
                // copy() is required only to maintain the graph contracts
                // (there must be an operation following desync()). No real copy happens
                cv::GMat img = cv::gapi::copy(cv::gapi::streaming::desync(preproc));

                // This branch has inference and is desynchronized to keep
                // a constant framerate for the encoded stream (above)
                cv::GMat bgr = cv::gapi::streaming::desync(preproc);

                cv::GMat nn, nn2;

                if ("s1" == parser || "textdetection" == parser)
                {
                    std::tie(nn, nn2) = cv::gapi::infer<MultiOutput>(bgr);
                }
                else
                {
                    nn = cv::gapi::infer<SingleOutput>(bgr);
                }

                cv::GOpaque<int64_t> nn_seqno = cv::gapi::streaming::seqNo(nn);
                cv::GOpaque<int64_t> nn_ts = cv::gapi::streaming::timestamp(nn);
                cv::GOpaque<cv::Size> sz = cv::gapi::streaming::size(bgr);

                cv::GArray<cv::Rect> rcs;
                cv::GArray<int> ids;
                cv::GArray<float> cfs;

                std::tie(rcs, ids, cfs) = (parser == "ssd100" || parser == "ssd200")
                    ? cv::gapi::streaming::parseSSDWithConf(nn, sz)
                    : (parser == "yolo")
                    ? cv::gapi::streaming::parseYoloWithConf(nn, sz)
                    : (parser == "s1")
                    ? cv::gapi::streaming::parseS1WithConf(nn, nn2, sz)
                    : (parser == "textdetection")
                    ? cv::gapi::streaming::parseTextDetection(nn, nn2, sz)
                    : cv::gapi::streaming::parseClass(nn, sz);

                // Now specify the computation's boundaries
                return cv::GComputation(cv::GIn(in),
                    cv::GOut(h264, h264_seqno, h264_ts,      // main path: H264 (~constant framerate)
                        img,                                 // desynchronized path: BGR
                        nn_seqno, nn_ts, sz, rcs, ids, cfs));
            });

        // Prepare parameters for the graph
        // Note: These dimensions are model-specific! Tested with bundled models only!
        std::map<std::string, cv::gapi::GNetPackage> nets = {
            {"ssd100", cv::gapi::networks(cv::gapi::azure::Params<SingleOutput>{ modelfile, cv::GMatDesc{ CV_32F, std::vector<int>{1, 1, 100, 7}}})},
            {"ssd200", cv::gapi::networks(cv::gapi::azure::Params<SingleOutput>{ modelfile, cv::GMatDesc{ CV_32F, std::vector<int>{1, 1, 200, 7}}})},
            {"yolo", cv::gapi::networks(cv::gapi::azure::Params<SingleOutput>{ modelfile, cv::GMatDesc{ CV_32F, std::vector<int>{1, 13, 13, ((int)classes.size() + 5) * 5}}})},
            {"classification", cv::gapi::networks(cv::gapi::azure::Params<SingleOutput>{ modelfile, cv::GMatDesc{ CV_32F, std::vector<int>{ 1, (int)classes.size()}}})},
            {"s1", cv::gapi::networks(cv::gapi::azure::Params<MultiOutput>{ modelfile, std::vector<cv::GMatDesc>{ {CV_32F, std::vector<int>{1, 3234, 4}}, { CV_32F, std::vector<int>{1, 3234, (int)classes.size() + 1}}}})},
            {"textdetection", cv::gapi::networks(cv::gapi::azure::Params<MultiOutput>{ modelfile, std::vector<cv::GMatDesc>{ {CV_32F, std::vector<int>{1, 16, 192, 320}}, { CV_32F, std::vector<int>{1, 2, 192, 320} }}})}
        };

        auto networks = nets.at(parser);
        auto kernels = cv::gapi::combine(cv::gapi::azure::kernels(),
            cv::gapi::kernels<cv::gapi::streaming::GOCVParseClass>(),
            cv::gapi::kernels<cv::gapi::streaming::GOCVParseS1WithConf>(),
            cv::gapi::kernels<cv::gapi::streaming::GOCVParseSSDWithConf>(),
            cv::gapi::kernels<cv::gapi::streaming::GOCVParseTextDetection>(),
            cv::gapi::kernels<cv::gapi::streaming::GOCVParseYoloWithConf>());

        // Compile the graph in streamnig mode, set all the parameters
        auto pipeline = graph.compileStreaming(cv::gapi::azure::Camera::params(),
            cv::compile_args(networks, kernels, cv::gapi::azure::mvcmdFile{ opt_mvcmd }));

        // Specify the AzureEye's Camera as the input to the pipeline, and start processing
        pipeline.setSource(cv::gapi::wip::make_src<cv::gapi::azure::Camera>());

        status = "";

        log_info("starting the pipeline...");
        pipeline.start();

        cv::optional<cv::Mat> out_bgr;

        cv::optional<std::vector<uint8_t>> out_h264;
        cv::optional<int64_t> out_h264_seqno;
        cv::optional<int64_t> out_h264_ts;
        cv::optional<cv::Size> img_size;

        cv::optional<cv::Mat> out_nn;
        cv::optional<cv::Mat> out_nn2;
        cv::optional<int64_t> out_nn_ts;
        cv::optional<int64_t> out_nn_seqno;
        cv::optional<std::vector<cv::Rect>> out_boxes;
        cv::optional<std::vector<int>> out_labels;
        cv::optional<std::vector<float>> out_confidences;

        std::vector<cv::Rect> last_boxes;
        std::vector<int> last_labels;
        std::vector<float> last_confidences;
        cv::Mat last_bgr;

        std::ofstream ofs;
        if (!opt_h264_out.empty())
        {
            ofs.open(opt_h264_out, std::ofstream::out | std::ofstream::binary | std::ofstream::trunc);
        }

        // Pull the data from the pipeline while it is running
        while (
            pipeline.pull(
                cv::gout(out_h264, out_h264_seqno, out_h264_ts, out_bgr, out_nn_seqno, out_nn_ts, img_size, out_boxes, out_labels, out_confidences)))
        {
            // NOTE: This version is asynchronous.
            // Different outputs may be available at different time

            // H264 stream: Write it to disk and report
            if (out_h264.has_value())
            {
                CV_Assert(out_h264_seqno.has_value());
                CV_Assert(out_h264_ts.has_value());

                if (ofs.is_open())
                {
                    ofs.write(reinterpret_cast<char*>(out_h264->data()), out_h264->size());
                }

                H264 frame;
                frame.data = *out_h264;
                frame.timestamp = *out_h264_ts;

                update_data_h264(frame);

                log_debug("h264: size=" + std::to_string(out_h264->size()) + ", seqno=" + std::to_string(*out_h264_seqno) + ", ts=" + std::to_string(*out_h264_ts));
            }

            // BGR output: visualize and optionally display
            if (out_bgr.has_value())
            {
                log_debug("bgr: size=" + to_size_string(out_bgr.value()));

                last_bgr = *out_bgr;

                update_data_raw(last_bgr);

                if (parser == "classification")
                {
                    preview(last_bgr, last_labels, last_confidences);
                }
                else
                {
                    preview(last_bgr, last_boxes, last_labels, last_confidences);
                }

                if (status.empty())
                {
                    update_data_result(last_bgr);
                }
                else
                {
                    cv::Mat bgr_with_status;
                    last_bgr.copyTo(bgr_with_status);

                    put_text(bgr_with_status, status);
                    update_data_result(bgr_with_status);
                }
            }

            // Inference data
            if (out_nn_ts.has_value())
            {
                // The below objects are on the same desynchronized path
                // and are coming together
                CV_Assert(out_nn_ts.has_value());
                CV_Assert(out_nn_seqno.has_value());
                CV_Assert(out_boxes.has_value());
                CV_Assert(out_labels.has_value());
                CV_Assert(out_confidences.has_value());
                CV_Assert(img_size.has_value());

                cv::Size2f im_size(img_size->width, img_size->height);
                std::vector<std::string> messages;

                for (std::size_t i = 0; i < out_labels->size(); i++)
                {
                    std::string str = std::string("{");

                    if ("classification" != parser)
                    {
                        cv::Rect ract = out_boxes.value()[i];
                        cv::Rect2f rect_abs(ract.x / im_size.width, ract.y / im_size.height, ract.width / im_size.width, ract.height / im_size.height);

                        char buf[500];
                        snprintf(buf, 500, "bbox: [%.3f, %.3f, %.3f, %.3f]", rect_abs.x, rect_abs.y, rect_abs.x + rect_abs.width, rect_abs.y + rect_abs.height);
                        str.append(buf);
                    }
                    str.append("\"label\": \"").append(get_label(out_labels.value()[i])).append("\", ")
                        .append("\"confidence\": ").append(std::to_string(out_confidences.value()[i])).append(", ")
                        .append("\"timestamp\": ").append(std::to_string(*out_nn_ts))
                        .append("}");

                    messages.push_back(str);
                }

                last_boxes = std::move(*out_boxes);
                last_labels = std::move(*out_labels);
                last_confidences = std::move(*out_confidences);

                std::string str = std::string("{ \"inferences\": [");
                for (size_t i = 0; i < messages.size(); i++)
                {
                    if (i > 0)
                    {
                        str.append(", ");
                    }
                    str.append(messages[i]);
                }
                str.append("]");
                // terminate
                str.append("}");

                //log_info("nn: size=" + to_size_string(out_nn.value()) + ", seqno=" + std::to_string(*out_nn_seqno) + ", ts=" + std::to_string(*out_nn_ts) + ", " + str);
                log_info("nn: seqno=" + std::to_string(*out_nn_seqno) + ", ts=" + std::to_string(*out_nn_ts) + ", " + str);

                send_message(const_cast<char*>(str.c_str()));

                // read MX temperature
                float css = 0.f, mss = 0.f, upa = 0.f, dss = 0.f;
                CV_Assert(vpual::tempread::GET_SUCCESS == vpual::tempread::stub::Get(&css, &mss, &upa, &dss));
                log_info("temperature: CSS=" + std::to_string(css) +
                    ", MSS=" + std::to_string(mss) +
                    ", UPA=" + std::to_string(upa) +
                    ", DSS=" + std::to_string(dss));
            }

            // Preview
            if (opt_show && !last_bgr.empty())
            {
                cv::imshow("preview", last_bgr);
                cv::waitKey(1);
            }

            if (restarting)
            {
                restarting = false;

                status = "Loading Model";

                put_text(last_bgr, status);
                update_data_result(last_bgr);

                log_info("stopping the pipeline...");
                pipeline.stop();

                // Sleep some time to let the device properly
                // deregister in the system
                std::this_thread::sleep_for(std::chrono::seconds(2));

                break;
            }
        }
    }

    stop_iot();

    return 0;
}