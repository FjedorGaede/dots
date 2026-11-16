import QtQuick
import QtMultimedia

// Live picture of the Insta360 for Insta360Menu. Streaming is also what wakes
// the gimbal (parked otherwise). Not mirrored: the pad arrows move the picture
// the way they point. Its own file, loaded by URL like recorder/WebcamFeed.qml
// — without qt6-multimedia only the preview stays empty.
Item {
    id: root

    // Camera found and streaming
    readonly property bool ok: camera.cameraDevice.id.length > 0 && !root.failed && camera.active
    property bool failed: false
    property string errorText: ""

    MediaDevices { id: devices }

    function pickDevice() {
        const inputs = devices.videoInputs;
        for (let i = 0; i < inputs.length; i++)
            if (inputs[i].description.indexOf("Insta360") !== -1) return inputs[i];
        return null;
    }

    // Small preview: the smallest format ≥ 720p at ≥ 30 fps (default is 4K MJPEG)
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
            cameraDevice: root.pickDevice() ?? devices.defaultVideoInput
            active: root.pickDevice() !== null
            Component.onCompleted: {
                const f = root.pickFormat(camera.cameraDevice);
                if (f) camera.cameraFormat = f;
            }
            onErrorOccurred: (error, errorString) => {
                root.failed = true;
                root.errorText = errorString;
                console.warn("Insta360 preview:", errorString);
            }
        }
        videoOutput: output
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }
}
