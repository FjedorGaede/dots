import QtQuick
import QtMultimedia

import qs.services

// Live webcam picture for WebcamBubble, mirrored like a selfie view (the
// recording shows exactly this). Its own file, loaded by URL: QtMultimedia
// is an optional package (qt6-multimedia + qt6-multimedia-ffmpeg) — a static
// import would break the whole shell without it, this way only the bubble
// stays empty.
Item {
    id: root

    // The camera picked in the recorder menu (V4L2 card name; matched on the
    // part before ": "), else the system default
    readonly property string preferred: RecorderService.cameraLabel(RecorderService.activeCamera)
    readonly property bool ok: camera.cameraDevice.id.length > 0 && !root.failed
    property bool failed: false

    MediaDevices { id: devices }

    function pickDevice() {
        const inputs = devices.videoInputs;
        for (let i = 0; i < inputs.length; i++)
            if (root.preferred !== "" && inputs[i].description.indexOf(root.preferred) !== -1)
                return inputs[i];
        return devices.defaultVideoInput;
    }

    // The bubble is ≤ 480 px: the smallest format ≥ 720p at ≥ 30 fps instead of
    // the camera's default (4K MJPEG on the Insta360 → decode load for nothing)
    function pickFormat(device) {
        let best = null;
        const formats = device.videoFormats;
        for (let i = 0; i < formats.length; i++) {
            const f = formats[i];
            if (f.resolution.height < 720 || f.maxFrameRate < 29) continue;
            if (!best || f.resolution.height < best.resolution.height
                    || (f.resolution.height === best.resolution.height && f.maxFrameRate > best.maxFrameRate))
                best = f;
        }
        return best;
    }

    CaptureSession {
        camera: Camera {
            id: camera
            cameraDevice: root.pickDevice()
            function applyFormat() {
                const f = root.pickFormat(camera.cameraDevice);
                if (f) camera.cameraFormat = f;
            }
            Component.onCompleted: applyFormat()
            onCameraDeviceChanged: { root.failed = false; applyFormat(); }
            active: true
            onErrorOccurred: (error, errorString) => {
                root.failed = true;
                console.warn("WebcamFeed:", errorString);
            }
        }
        videoOutput: output
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        transform: Scale { origin.x: output.width / 2; xScale: -1 }
    }
}
