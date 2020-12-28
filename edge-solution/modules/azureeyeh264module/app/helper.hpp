// Copyright (c) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE file in the project root for full license information.

#include <algorithm>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <string>

#include <opencv2/core/utility.hpp>
#include <opencv2/imgproc.hpp>

static bool verbose_logging = true;

static bool exist_file(std::string filename)
{
    std::ifstream file(filename.c_str());
    return file.good();
}

static void log_error(std::string str)
{
    time_t t = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
    std::cout << std::put_time(std::localtime(&t), "%Y-%m-%d %X") << " ERROR: " << str << std::endl;
}

static void log_info(std::string str)
{
    time_t t = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
    std::cout << std::put_time(std::localtime(&t), "%Y-%m-%d %X") << " " << str << std::endl;
}

static void log_debug(std::string str)
{
    if (verbose_logging)
    {
        time_t t = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
        std::cout << std::put_time(std::localtime(&t), "%Y-%m-%d %X") << " " << str << std::endl;
    }
}

static void put_text(const cv::Mat& rgb, std::string text)
{
    cv::putText(rgb,
        text,
        cv::Point(300, 20),
        cv::FONT_HERSHEY_SIMPLEX,
        0.7,
        cv::Scalar(0, 0, 0),
        5);

    cv::putText(rgb,
        text,
        cv::Point(300, 20),
        cv::FONT_HERSHEY_SIMPLEX,
        0.7,
        cv::Scalar(255, 255, 255),
        2);
}

static void set_logging(bool data)
{
    verbose_logging = data;
    log_info("verbose_logging: " + std::to_string(verbose_logging));
}

static std::string to_hex_string(int i)
{
    std::stringstream ss;
    ss << std::hex << i;
    return ss.str();
}

static std::string to_lower(std::string str)
{
    // convert string to back to lower case
    std::for_each(str.begin(), str.end(), [](char& c)
        {
            c = ::tolower(c);
        });

    return str;
}

static std::string to_size_string(cv::Mat& mat)
{
    std::string str = std::string("");

    for (int i = 0; i < mat.dims; ++i)
    {
        str.append(i ? " x " : "").append(std::to_string(mat.size[i]));
    }

    return str;
}

//static std::string to_size_string(std::vector<cv::Mat>& mat)
//{
//    std::string str = std::string("");
//
//    for (int i = 0; i < mat.dims; ++i)
//    {
//        str.append(i ? " x " : "").append(std::to_string(mat.size[i]));
//    }
//
//    return str;
//}

static std::string to_string_with_precision(float f, int precision)
{
    std::stringstream ss;
    ss << std::fixed << std::setprecision(precision) << f;
    return ss.str();
}

static int run_command(std::string command)
{
    log_info(command);
    return system(command.c_str());
}

static bool search_keyword_in_file(std::string keyword, std::string filename)
{
    std::ifstream file(filename);

    if (file.is_open())
    {
        std::string line;

        while (getline(file, line))
        {
            if (std::string::npos != line.find(keyword))
            {
                return true;
            }
        }

        file.close();
    }

    return false;
}