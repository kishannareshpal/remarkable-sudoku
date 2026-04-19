#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <cstdio>
#include <fcntl.h>
#include <iostream>
#include <linux/input.h>
#include <linux/uinput.h>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/ioctl.h>
#include <thread>
#include <unistd.h>

namespace
{
constexpr int kTouchSlot = 0;
constexpr int kScreenWidth = 1404;
constexpr int kScreenHeight = 1872;
constexpr int kTouchPressure = 80;
constexpr int kTouchMinor = 1;
constexpr int kTouchMajor = 1;
constexpr int kTrackingIdMin = 1;
constexpr int kTrackingIdMax = 65535;
constexpr int kTouchDistanceInactive = 255;
constexpr int kTouchDistanceActive = 0;
constexpr const char *kDeviceName = "remarkable-sudoku-touch-bridge";

void require(bool condition, const std::string &message)
{
    if (!condition) {
        throw std::runtime_error(message + ": " + std::strerror(errno));
    }
}

void emitEvent(int fileDescriptor, __u16 type, __u16 code, __s32 value)
{
    input_event event {};
    event.type = type;
    event.code = code;
    event.value = value;

    const ssize_t written = write(fileDescriptor, &event, sizeof(event));
    require(written == static_cast<ssize_t>(sizeof(event)), "failed to emit input event");
}

void syncEvents(int fileDescriptor)
{
    emitEvent(fileDescriptor, EV_SYN, SYN_REPORT, 0);
}

int clampX(int value)
{
    return std::clamp(value, 0, kScreenWidth - 1);
}

int clampY(int value)
{
    return std::clamp(value, 0, kScreenHeight - 1);
}

class TouchInjector
{
public:
    TouchInjector()
    {
        fileDescriptor_ = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
        require(fileDescriptor_ >= 0, "failed to open /dev/uinput");

        configureDevice();
        createDevice();
    }

    ~TouchInjector()
    {
        if (fileDescriptor_ < 0) {
            return;
        }

        ioctl(fileDescriptor_, UI_DEV_DESTROY);
        close(fileDescriptor_);
    }

    void press(int x, int y)
    {
        if (touchActive_) {
            move(x, y);
            return;
        }

        touchActive_ = true;
        trackingId_ = nextTrackingId();
        sendSlotEvent(x, y);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TRACKING_ID, trackingId_);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOUCH_MAJOR, kTouchMajor);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOUCH_MINOR, kTouchMinor);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_ORIENTATION, 0);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_PRESSURE, kTouchPressure);
        emitEvent(fileDescriptor_, EV_ABS, ABS_DISTANCE, kTouchDistanceActive);
        syncEvents(fileDescriptor_);
    }

    void move(int x, int y)
    {
        if (!touchActive_) {
            return;
        }

        sendSlotEvent(x, y);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOUCH_MAJOR, kTouchMajor);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOUCH_MINOR, kTouchMinor);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_PRESSURE, kTouchPressure);
        emitEvent(fileDescriptor_, EV_ABS, ABS_DISTANCE, kTouchDistanceActive);
        syncEvents(fileDescriptor_);
    }

    void release()
    {
        if (!touchActive_) {
            return;
        }

        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_SLOT, kTouchSlot);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TRACKING_ID, -1);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOUCH_MAJOR, 0);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOUCH_MINOR, 0);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_PRESSURE, 0);
        emitEvent(fileDescriptor_, EV_ABS, ABS_DISTANCE, kTouchDistanceInactive);
        syncEvents(fileDescriptor_);
        touchActive_ = false;
    }

private:
    void configureAbsRange(uinput_user_dev &device, int code, int minimum, int maximum)
    {
        require(ioctl(fileDescriptor_, UI_SET_ABSBIT, code) == 0, "failed to enable ABS code");
        device.absmin[code] = minimum;
        device.absmax[code] = maximum;
    }

    void configureDevice()
    {
        require(ioctl(fileDescriptor_, UI_SET_EVBIT, EV_ABS) == 0, "failed to enable EV_ABS");
        require(ioctl(fileDescriptor_, UI_SET_PROPBIT, INPUT_PROP_DIRECT) == 0,
                "failed to enable INPUT_PROP_DIRECT");

        uinput_user_dev device {};
        std::snprintf(device.name, UINPUT_MAX_NAME_SIZE, "%s", kDeviceName);
        device.id.bustype = BUS_VIRTUAL;
        device.id.vendor = 0x2d1f;
        device.id.product = 0x0095;
        device.id.version = 1;

        configureAbsRange(device, ABS_DISTANCE, 0, 255);
        configureAbsRange(device, ABS_MT_SLOT, 0, 31);
        configureAbsRange(device, ABS_MT_TOUCH_MAJOR, 0, 255);
        configureAbsRange(device, ABS_MT_TOUCH_MINOR, 0, 255);
        configureAbsRange(device, ABS_MT_ORIENTATION, -127, 127);
        configureAbsRange(device, ABS_MT_POSITION_X, 0, kScreenWidth - 1);
        configureAbsRange(device, ABS_MT_POSITION_Y, 0, kScreenHeight - 1);
        configureAbsRange(device, ABS_MT_TOOL_TYPE, 0, MT_TOOL_PEN);
        configureAbsRange(device, ABS_MT_TRACKING_ID, 0, kTrackingIdMax);
        configureAbsRange(device, ABS_MT_PRESSURE, 0, 255);

        const ssize_t written = write(fileDescriptor_, &device, sizeof(device));
        require(written == static_cast<ssize_t>(sizeof(device)), "failed to write uinput device");
    }

    void createDevice()
    {
        require(ioctl(fileDescriptor_, UI_DEV_CREATE) == 0, "failed to create uinput device");
        std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }

    int nextTrackingId()
    {
        if (trackingSequence_ >= kTrackingIdMax) {
            trackingSequence_ = kTrackingIdMin;
        }

        return trackingSequence_++;
    }

    void sendSlotEvent(int x, int y)
    {
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_SLOT, kTouchSlot);
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_POSITION_X, clampX(x));
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_POSITION_Y, clampY(y));
        emitEvent(fileDescriptor_, EV_ABS, ABS_MT_TOOL_TYPE, MT_TOOL_FINGER);
    }

    int fileDescriptor_ = -1;
    bool touchActive_ = false;
    int trackingId_ = -1;
    int trackingSequence_ = kTrackingIdMin;
};

bool parsePointCommand(std::istringstream &stream, int &x, int &y)
{
    return static_cast<bool>(stream >> x >> y);
}
}

int main()
{
    try {
        TouchInjector injector;
        std::cout << "READY width=" << kScreenWidth << " height=" << kScreenHeight << '\n';
        std::cout.flush();

        std::string line;
        while (std::getline(std::cin, line)) {
            if (line.empty()) {
                continue;
            }

            std::istringstream commandStream(line);
            std::string command;
            commandStream >> command;

            if (command == "down") {
                int x = 0;
                int y = 0;
                if (!parsePointCommand(commandStream, x, y)) {
                    throw std::runtime_error("invalid down command");
                }

                injector.press(x, y);
                continue;
            }

            if (command == "move") {
                int x = 0;
                int y = 0;
                if (!parsePointCommand(commandStream, x, y)) {
                    throw std::runtime_error("invalid move command");
                }

                injector.move(x, y);
                continue;
            }

            if (command == "up") {
                injector.release();
                continue;
            }

            if (command == "quit") {
                injector.release();
                return 0;
            }

            throw std::runtime_error("unsupported command: " + command);
        }

        injector.release();
        return 0;
    } catch (const std::exception &exception) {
        std::cerr << exception.what() << '\n';
        return 1;
    }
}
