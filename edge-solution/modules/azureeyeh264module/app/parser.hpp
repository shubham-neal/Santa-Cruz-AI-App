// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <opencv2/gapi/azure.hpp>
#include <opencv2/gapi/cpu/gcpukernel.hpp>

namespace cv
{
    namespace gapi
    {
        namespace streaming
        {
            std::vector<Rect> maskToBoxes(const cv::Mat& mask, float min_area, float min_height,
                cv::Size image_size) {
                std::vector<Rect> bboxes;
                double min_val;
                double max_val;
                cv::minMaxLoc(mask, &min_val, &max_val);
                int max_bbox_idx = static_cast<int>(max_val);
                cv::Mat resized_mask;
                cv::resize(mask, resized_mask, image_size, 0, 0, cv::INTER_NEAREST);

                for (int i = 1; i <= max_bbox_idx; i++) {
                    cv::Mat bbox_mask = resized_mask == i;
                    std::vector<std::vector<cv::Point>> contours;

                    cv::findContours(bbox_mask, contours, cv::RETR_CCOMP, cv::CHAIN_APPROX_SIMPLE);
                    if (contours.empty())
                        continue;
                    cv::RotatedRect r = cv::minAreaRect(contours[0]);
                    if (std::min(r.size.width, r.size.height) < min_height)
                        continue;
                    if (r.size.area() < min_area)
                        continue;
                    bboxes.emplace_back(r.boundingRect());
                }

                return bboxes;
            }

            int findRoot(int point, std::unordered_map<int, int>* group_mask) {
                int root = point;
                bool update_parent = false;
                while (group_mask->at(root) != -1) {
                    root = group_mask->at(root);
                    update_parent = true;
                }
                if (update_parent) {
                    (*group_mask)[point] = root;
                }
                return root;
            }

            void join(int p1, int p2, std::unordered_map<int, int>* group_mask) {
                int root1 = findRoot(p1, group_mask);
                int root2 = findRoot(p2, group_mask);
                if (root1 != root2) {
                    (*group_mask)[root1] = root2;
                }
            }

            cv::Mat get_all(const std::vector<cv::Point>& points, int w, int h,
                std::unordered_map<int, int>* group_mask) {
                std::unordered_map<int, int> root_map;

                cv::Mat mask(h, w, CV_32S, cv::Scalar(0));
                for (const auto& point : points) {
                    int point_root = findRoot(point.x + point.y * w, group_mask);
                    if (root_map.find(point_root) == root_map.end()) {
                        root_map.emplace(point_root, static_cast<int>(root_map.size() + 1));
                    }
                    mask.at<int>(point.x + point.y * w) = root_map[point_root];
                }

                return mask;
            }

            cv::Mat decodeImageByJoin(const float* cls_data,
                const float* link_data, int h, int w, int neighbors,
                float cls_conf_threshold, float link_conf_threshold) {

                std::vector<uchar> pixel_mask(h * w, 0);
                std::unordered_map<int, int> group_mask;
                std::vector<cv::Point> points;
                for (size_t i = 0; i < pixel_mask.size(); i++) {
                    pixel_mask[i] = cls_data[i] >= cls_conf_threshold;
                    if (pixel_mask[i]) {
                        points.emplace_back(i % w, i / w);
                        group_mask[i] = -1;
                    }
                }

                std::vector<uchar> link_mask(h * w * neighbors, 0);
                //for (size_t i = 0; i < link_mask.size(); i++) {
                //    link_mask[i] = link_data[i] >= link_conf_threshold;
                //}

                for (size_t i = 0; i < neighbors; i++) {
                    for (size_t j = 0; j < h * w; j++) {
                        link_mask[i * h * w + j] = link_data[i * 2 * h * w + j] >= link_conf_threshold;
                    }
                }

                //size_t neighbours = size_t(link_data_shape[3]);
                for (const auto& point : points) {
                    size_t neighbor = 0;
                    for (int ny = point.y - 1; ny <= point.y + 1; ny++) {
                        for (int nx = point.x - 1; nx <= point.x + 1; nx++) {
                            if (nx == point.x && ny == point.y)
                                continue;
                            if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                                uchar pixel_value = pixel_mask[size_t(ny) * size_t(w) + size_t(nx)];
                                uchar link_value = link_mask[
                                    (size_t(point.y) * size_t(w) + size_t(point.x)) * neighbors + neighbor];
                                if (pixel_value && link_value) {
                                    join(point.x + point.y * w, nx + ny * w, &group_mask);
                                }
                            }
                            neighbor++;
                        }
                    }
                }

                return get_all(points, w, h, &group_mask);
            }

            using GDetectionsWithConf = std::tuple<GArray<Rect>, GArray<int>, GArray<float>>;
            using GYoloAnchors = std::vector<float>;

            G_API_OP(GParseClass, <GDetectionsWithConf(GMat, GOpaque<Size>, float)>, "org.opencv.dnn.parseClass")
            {
                static std::tuple<GArrayDesc, GArrayDesc, GArrayDesc> outMeta(const GMatDesc&, const GOpaqueDesc&, float)
                {
                    return std::make_tuple(empty_array_desc(), empty_array_desc(), empty_array_desc());
                }
            };

            G_API_OP(GParseTextDetection, <GDetectionsWithConf(GMat, GMat, GOpaque<Size>, float, float)>, "org.opencv.dnn.parseTextDetection")
            {
                static std::tuple<GArrayDesc, GArrayDesc, GArrayDesc> outMeta(const GMatDesc&, const GMatDesc&, const GOpaqueDesc&, float, float)
                {
                    return std::make_tuple(empty_array_desc(), empty_array_desc(), empty_array_desc());
                }
            };

            G_API_OP(GParseS1WithConf, <GDetectionsWithConf(GMat, GMat, GOpaque<Size>, float, float)>, "org.opencv.dnn.parseS1WithConf")
            {
                static std::tuple<GArrayDesc, GArrayDesc, GArrayDesc> outMeta(const GMatDesc&, const GMatDesc&, const GOpaqueDesc&, float, float)
                {
                    return std::make_tuple(empty_array_desc(), empty_array_desc(), empty_array_desc());
                }
            };

            G_API_OP(GParseSSDWithConf, <GDetectionsWithConf(GMat, GOpaque<Size>, float, int)>, "org.opencv.dnn.parseSSDWithConf")
            {
                static std::tuple<GArrayDesc, GArrayDesc, GArrayDesc> outMeta(const GMatDesc&, const GOpaqueDesc&, float, int)
                {
                    return std::make_tuple(empty_array_desc(), empty_array_desc(), empty_array_desc());
                }
            };

            G_API_OP(GParseYoloWithConf, <GDetectionsWithConf(GMat, GOpaque<Size>, float, float, GYoloAnchors)>, "org.opencv.dnn.parseYoloWithConf")
            {
                static std::tuple<GArrayDesc, GArrayDesc, GArrayDesc> outMeta(const GMatDesc&, const GOpaqueDesc&, float, float, const GYoloAnchors&)
                {
                    return std::make_tuple(empty_array_desc(), empty_array_desc(), empty_array_desc());
                }

                static const GYoloAnchors& defaultAnchors() {
                    static GYoloAnchors anchors{
                        0.57273, 0.677385, 1.87446, 2.06253, 3.33843, 5.47434, 7.88282,3.52778, 9.77052, 9.16828
                    };
                    return anchors;
                }
            };

            GAPI_OCV_KERNEL(GOCVParseClass, GParseClass)
            {
                static void run(const Mat & in_result,
                    const Size & in_size,
                    float confidence_threshold,
                    std::vector<Rect> & out_boxes,
                    std::vector<int> & out_labels,
                    std::vector<float> & out_confidences) {
                    const auto& in_dims = in_result.size;

                    out_boxes.clear();
                    out_labels.clear();
                    out_confidences.clear();

                    const auto results = in_result.ptr<float>();
                    float max_confidence = 0;
                    int label = 0;

                    for (int i = 0; i < in_dims[1]; i++)
                    {
                        if (results[i] > max_confidence)
                        {
                            label = i;
                            max_confidence = results[label];
                        }
                    }

                    out_labels.emplace_back(label);
                    out_confidences.emplace_back(results[label]);
                }
            };

            GAPI_OCV_KERNEL(GOCVParseTextDetection, GParseTextDetection) {
                static void run(const Mat & in_raw_cls,
                    const Mat & in_raw_link,
                    const Size & in_size,
                    float confidence_threshold,
                    float nms_threshold,
                    std::vector<Rect> & out_boxes,
                    std::vector<int> & out_labels,
                    std::vector<float> & out_confidences)
                {
                    const int kMinArea = 300;
                    const int kMinHeight = 10;

                    out_boxes.clear();
                    out_labels.clear();
                    out_confidences.clear();

                    const auto& link_shape = in_raw_link.size;
                    const auto link_data = in_raw_link.ptr<float>();
                    const auto cls_data = in_raw_cls.ptr<float>();

                    cv::Mat mask = decodeImageByJoin(cls_data, link_data, link_shape[2], link_shape[3], link_shape[1] / 2, 0.5, 0.5);
                    std::vector<Rect> rects = maskToBoxes(mask, static_cast<float>(kMinArea),
                        static_cast<float>(kMinHeight), in_size);

                    for (const auto& r : rects) {
                        out_boxes.emplace_back(r);
                    }
                }
            };

            GAPI_OCV_KERNEL(GOCVParseS1WithConf, GParseS1WithConf) {
                static void run(const Mat & in_raw_boxes,
                    const Mat & in_raw_probs,
                    const Size & in_size,
                    float confidence_threshold,
                    float nms_threshold,
                    std::vector<Rect> & out_boxes,
                    std::vector<int> & out_labels,
                    std::vector<float> & out_confidences)
                {
                    const auto& in_boxes_dims = in_raw_boxes.size;
                    GAPI_Assert(in_boxes_dims.dims() == 3u);

                    const auto& in_probs_dims = in_raw_probs.size;
                    GAPI_Assert(in_probs_dims.dims() == 3u);

                    const int MAX_PROPOSALS = in_probs_dims[1];
                    const int NUM_CLASSES = in_probs_dims[2];
                    const int OBJECT_SIZE = in_boxes_dims[2];

                    out_boxes.clear();
                    out_labels.clear();
                    out_confidences.clear();

                    struct Detection {
                        cv::Rect rect;
                        float    conf;
                        int      label;
                    };
                    std::vector<Detection> detections;

                    const auto boxes = in_raw_boxes.ptr<float>();
                    const auto probs = in_raw_probs.ptr<float>();

                    for (int i = 0; i < MAX_PROPOSALS; i++) {
                        for (int label = 1; label < NUM_CLASSES; label++) {
                            float confidence = probs[i * NUM_CLASSES + label];

                            if (confidence < confidence_threshold) {
                                continue; // skip objects with low confidence
                            }

                            float center_x = boxes[i * OBJECT_SIZE];
                            float center_y = boxes[i * OBJECT_SIZE + 1];
                            float w = boxes[i * OBJECT_SIZE + 2];
                            float h = boxes[i * OBJECT_SIZE + 3];

                            const Rect surface({ 0,0 }, in_size);

                            Rect rc;  // map relative coordinates to the original image scale
                            rc.x = static_cast<int>((center_x - w / 2) * in_size.width);
                            rc.y = static_cast<int>((center_y - h / 2) * in_size.height);
                            rc.width = static_cast<int>(w * in_size.width);
                            rc.height = static_cast<int>(h * in_size.height);

                            detections.emplace_back(Detection{ rc, confidence, label - 1 });
                        }
                    }

                    std::stable_sort(std::begin(detections), std::end(detections),
                        [](const Detection& a, const Detection& b) {
                            return a.conf > b.conf;
                        });

                    if (nms_threshold < 1.0f) {
                        for (const auto& d : detections) {
                            // Reject boxes which overlap with previously pushed ones
                            // (They are sorted by confidence, so rejected box
                            // always has a smaller confidence
                            if (std::end(out_boxes) ==
                                std::find_if(std::begin(out_boxes), std::end(out_boxes),
                                    [&d, nms_threshold](const Rect& r) {
                                        float rectOverlap = 1.f - static_cast<float>(jaccardDistance(r, d.rect));
                                        return rectOverlap > nms_threshold;
                                    })) {
                                out_boxes.emplace_back(d.rect);
                                out_labels.emplace_back(d.label);
                                out_confidences.emplace_back(d.conf);
                            }
                        }
                    }
                    else {
                        for (const auto& d : detections) {
                            out_boxes.emplace_back(d.rect);
                            out_labels.emplace_back(d.label);
                            out_confidences.emplace_back(d.conf);
                        }
                    }
                }
            };

            GAPI_OCV_KERNEL(GOCVParseSSDWithConf, GParseSSDWithConf) {
                static void run(const Mat & in_ssd_result,
                    const Size & in_size,
                    float confidence_threshold,
                    int filter_label,
                    std::vector<Rect> & out_boxes,
                    std::vector<int> & out_labels,
                    std::vector<float> & out_confidences) {
                    const auto& in_ssd_dims = in_ssd_result.size;
                    GAPI_Assert(in_ssd_dims.dims() == 4u);

                    const int MAX_PROPOSALS = in_ssd_dims[2];
                    const int OBJECT_SIZE = in_ssd_dims[3];
                    GAPI_Assert(OBJECT_SIZE == 7); // fixed SSD object size

                    out_boxes.clear();
                    out_labels.clear();
                    out_confidences.clear();

                    const auto items = in_ssd_result.ptr<float>();
                    for (int i = 0; i < MAX_PROPOSALS; i++) {
                        const auto it = items + i * OBJECT_SIZE;
                        float image_id = it[0];
                        float label = it[1];
                        float confidence = it[2];
                        float rc_left = it[3];
                        float rc_top = it[4];
                        float rc_right = it[5];
                        float rc_bottom = it[6];

                        if (image_id < 0.f) {
                            break;    // marks end-of-detections
                        }

                        if (confidence < confidence_threshold) {
                            continue; // skip objects with low confidence
                        }
                        if (filter_label != -1 && static_cast<int>(label) != filter_label) {
                            continue; // filter out object classes if filter is specified
                        }

                        const Rect surface({ 0,0 }, in_size);

                        Rect rc;  // map relative coordinates to the original image scale
                        rc.x = static_cast<int>(rc_left * in_size.width);
                        rc.y = static_cast<int>(rc_top * in_size.height);
                        rc.width = static_cast<int>(rc_right * in_size.width) - rc.x;
                        rc.height = static_cast<int>(rc_bottom * in_size.height) - rc.y;
                        out_boxes.emplace_back(rc & surface);
                        out_labels.emplace_back(label);
                        out_confidences.emplace_back(confidence);
                    }
                }
            };

            namespace {
                class YoloParser
                {
                    const float* m_out;
                    int m_side, m_lcoords, m_lclasses;

                    int index(int i, int b, int entry) {
                        return b * m_side * m_side * (m_lcoords + m_lclasses + 1) + entry * m_side * m_side + i;
                    }

                public:
                    YoloParser(const float* out, int side, int lcoords, int lclasses)
                        : m_out(out), m_side(side), m_lcoords(lcoords), m_lclasses(lclasses)
                    {}

                    float scale(int i, int b) {
                        int obj_index = index(i, b, m_lcoords);
                        return m_out[obj_index];
                    }

                    double x(int i, int b)
                    {
                        int box_index = index(i, b, 0);
                        int col = i % m_side;
                        return (col + m_out[box_index]) / m_side;
                    }

                    double y(int i, int b)
                    {
                        int box_index = index(i, b, 0);
                        int row = i / m_side;
                        return (row + m_out[box_index + m_side * m_side]) / m_side;
                    }

                    double width(int i, int b, float anchor) {
                        int box_index = index(i, b, 0);
                        return std::exp(m_out[box_index + 2 * m_side * m_side]) * anchor / m_side;
                    }

                    double height(int i, int b, float anchor) {
                        int box_index = index(i, b, 0);
                        return std::exp(m_out[box_index + 3 * m_side * m_side]) * anchor / m_side;
                    }

                    float classConf(int i, int b, int label) {
                        int class_index = index(i, b, m_lcoords + 1 + label);
                        return m_out[class_index];
                    }
                };

                class YoloParams {
                public:
                    int num = 5;
                    int coords = 4;
                };

                cv::Rect toBox(double x, double y, double h, double w, cv::Size in_sz)
                {
                    auto h_scale = in_sz.height;
                    auto w_scale = in_sz.width;
                    Rect r;
                    r.x = static_cast<int>((x - w / 2) * w_scale);
                    r.y = static_cast<int>((y - h / 2) * h_scale);
                    r.width = static_cast<int>(w * w_scale);
                    r.height = static_cast<int>(h * h_scale);
                    return r;
                }
            } // anonymous namespace

            GAPI_OCV_KERNEL(GOCVParseYoloWithConf, GParseYoloWithConf) {
                static void run(const Mat & in_yolo_result,
                    const Size & in_size,
                    float confidence_threshold,
                    float nms_threshold,
                    const GYoloAnchors & anchors,
                    std::vector<Rect> & out_boxes,
                    std::vector<int> & out_labels,
                    std::vector<float> & out_confidences) {
                    const auto& dims = in_yolo_result.size;
                    GAPI_Assert(dims.dims() == 4);
                    GAPI_Assert(dims[0] == 1);
                    GAPI_Assert(dims[1] == 13);
                    GAPI_Assert(dims[2] == 13);
                    GAPI_Assert(dims[3] % 5 == 0); // 5 boxes
                    const auto num_classes = dims[3] / 5 - 5;
                    GAPI_Assert(num_classes > 0);
                    GAPI_Assert(0 < nms_threshold && nms_threshold <= 1);

                    out_boxes.clear();
                    out_labels.clear();
                    out_confidences.clear();

                    YoloParams params;
                    constexpr auto side = 13;
                    constexpr auto side_square = side * side;
                    const auto output = in_yolo_result.ptr<float>();

                    YoloParser parser(output, side, params.coords, num_classes);

                    struct Detection {
                        cv::Rect rect;
                        float    conf;
                        int      label;
                    };
                    std::vector<Detection> detections;

                    for (int i = 0; i < side_square; i++) {
                        for (int b = 0; b < params.num; b++) {
                            float scale = parser.scale(i, b);
                            if (scale < confidence_threshold)
                            {
                                continue;
                            }
                            double x = parser.x(i, b);
                            double y = parser.y(i, b);
                            double height = parser.height(i, b, anchors[2 * b + 1]);
                            double width = parser.width(i, b, anchors[2 * b]);

                            for (int label = 0; label < num_classes; label++) {
                                float prob = scale * parser.classConf(i, b, label);
                                if (prob < confidence_threshold)
                                {
                                    continue;
                                }
                                auto box = toBox(x, y, height, width, in_size);

                                detections.emplace_back(Detection{ box, prob, label });
                            }
                        }
                    }
                    std::stable_sort(std::begin(detections), std::end(detections),
                        [](const Detection& a, const Detection& b) {
                            return a.conf > b.conf;
                        });

                    if (nms_threshold < 1.0f) {
                        for (const auto& d : detections) {
                            // Reject boxes which overlap with previously pushed ones
                            // (They are sorted by confidence, so rejected box
                            // always has a smaller confidence
                            if (std::end(out_boxes) ==
                                std::find_if(std::begin(out_boxes), std::end(out_boxes),
                                    [&d, nms_threshold](const Rect& r) {
                                        float rectOverlap = 1.f - static_cast<float>(jaccardDistance(r, d.rect));
                                        return rectOverlap > nms_threshold;
                                    })) {
                                out_boxes.emplace_back(d.rect);
                                out_labels.emplace_back(d.label);
                                out_confidences.emplace_back(d.conf);
                            }
                        }
                    }
                    else {
                        for (const auto& d : detections) {
                            out_boxes.emplace_back(d.rect);
                            out_labels.emplace_back(d.label);
                            out_confidences.emplace_back(d.conf);
                        }
                    }
                }
            };

            GAPI_EXPORTS GDetectionsWithConf parseClass(const GMat& in,
                const GOpaque<Size>& in_sz,
                float confidence_threshold = 0.5f)
            {
                return GParseClass::on(in, in_sz, confidence_threshold);
            };

            GAPI_EXPORTS GDetectionsWithConf parseTextDetection(const GMat& in_raw_boxes,
                const GMat& in_raw_probs,
                const GOpaque<Size>& in_sz,
                float confidence_threshold = 0.5f,
                float nms_threshold = 0.5f)
            {
                return GParseTextDetection::on(in_raw_boxes, in_raw_probs, in_sz, confidence_threshold, nms_threshold);
            };

            GAPI_EXPORTS GDetectionsWithConf parseS1WithConf(const GMat& in_raw_boxes,
                const GMat& in_raw_probs,
                const GOpaque<Size>& in_sz,
                float confidence_threshold = 0.5f,
                float nms_threshold = 0.5f)
            {
                return GParseS1WithConf::on(in_raw_boxes, in_raw_probs, in_sz, confidence_threshold, nms_threshold);
            };

            GAPI_EXPORTS GDetectionsWithConf parseSSDWithConf(const GMat& in,
                const GOpaque<Size>& in_sz,
                float confidence_threshold = 0.5f,
                int   filter_label = -1)
            {
                return GParseSSDWithConf::on(in, in_sz, confidence_threshold, filter_label);
            };

            GAPI_EXPORTS GDetectionsWithConf parseYoloWithConf(const GMat& in,
                const GOpaque<Size>& in_sz,
                float confidence_threshold = 0.5f,
                float nms_threshold = 0.5f,
                const GYoloAnchors& anchors = GParseYolo::defaultAnchors())
            {
                return GParseYoloWithConf::on(in, in_sz, confidence_threshold, nms_threshold, anchors);
            };
        } // namespace streaming
    } // namespace gapi
} // namespace cv