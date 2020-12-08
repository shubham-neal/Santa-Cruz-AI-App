import React from 'react';
import { Editor } from './Editor';

export class Camera extends React.Component {
    static defaultProps = {
        border: '0px solid black',
        width: 300,
        height: 300,
        fps: 30,
        aggregator: {
            lines: [],
            zones: [{
                name: "threshold",
                polygon: [[
                    0,
                    0.5
                ],
                [
                    0.9,
                    0.5
                ]],
                threshold: 10.0
            }]
        },
        frame: {
            detections: []
        },
        ampStreamingUrl: null
    }
    constructor(props) {
        super(props);
        // TODO: temp for dev, remove when finished with it
        const devOptions = JSON.parse(localStorage.getItem("UES-APP-DEVOPTIONS")) || {
            syncOffset: 0,
            syncBuffer: 0.1,
            restartTime: 0
        };
        

        this.state = {
            aggregator: JSON.parse(JSON.stringify(this.props.aggregator)),
            ampStreamingUrl: null,
            blobPartition: null,
            
            // TODO: temp for dev, remove when finished with it
            syncOffset: devOptions.syncOffset,
            syncBuffer: devOptions.syncBuffer,
            restartTime: devOptions.restartTime,
            editingAllowed: false
        };

        this.canvasRef = React.createRef();
        this.videoRef = React.createRef();
        this.amp = null;

        this.currentMediaTime = null;
        this.inferences = {};
        this.detections = [];
    }

    componentDidMount() {
        if (this.props.ampStreamingUrl) {
            this.setState({
                ampStreamingUrl: this.props.ampStreamingUrl
            }, () => {
                this.amp = window.amp(this.videoRef.current, {
                    "nativeControlsForTouch": false,
                    autoplay: true,
                    controls: true,
                    width: this.props.width,
                    height: this.props.height,
                });
                this.amp.src([
                    {
                        "src": this.state.ampStreamingUrl,
                        "type": "application/vnd.ms-sstr+xml"
                    }
                ]);
            });
        }
        setInterval(() => {
            this.draw();
        }, 1000 / this.props.fps);

        setInterval(() => {
            this.sync();
        }, 1000);

        setInterval(() => {
            this.updateCurrentMediaTime();
        }, 1000 / this.props.fps);

        setInterval(() => {
            this.updateDetections();
        }, 1000 / this.props.fps);

        setInterval(() => {
            this.updateRealTimeMetrics();
        }, 1000 / this.props.fps);
    }

    componentDidUpdate(prevProps) {
        if (prevProps.aggregator !== this.props.aggregator) {
            this.setState({
                aggregator: this.props.aggregator
            });
        }
        if (prevProps.ampStreamingUrl !== this.props.ampStreamingUrl) {
            this.setState({
                ampStreamingUrl: this.props.ampStreamingUrl
            }, () => {
                this.amp.src([
                    {
                        "src": this.state.ampStreamingUrl,
                        "type": "application/vnd.ms-sstr+xml"
                    }
                ]);
            });
        }
    }

    render() {
        return (
            <React.Fragment>
                {
                    // temp dev tools
                }
                <div
                    style={{
                        margin: 10,
                        padding: 5,
                        backgroundColor: '#d3d3d3',
                        position: 'relative'
                    }}>
                    <label
                        style={{ marginLeft: 5 }}>
                        Offset
                    </label>
                    <input
                        type="number"
                        step="250"
                        style={{ marginLeft: 5 }}
                        defaultValue={this.state.syncOffset}
                        onChange={(e) => this.setState({ syncOffset: +e.target.value }, () => { this.saveDevOptions() })}
                    />
                    <label
                        style={{ marginLeft: 5 }}>
                        Buffer
                    </label>
                    <input
                        type="number"
                        step="0.1"
                        style={{ marginLeft: 5 }}
                        defaultValue={this.state.syncBuffer}
                        onChange={(e) => this.setState({ syncBuffer: +e.target.value }, () => { this.saveDevOptions() })}
                    />
                    <br />

                    {/* <label
                        style={{ marginLeft: 5 }}>
                        Editing
                    </label>
                    <input
                        type="checkbox"
                        style={{ marginLeft: 5 }}
                        defaultChecked={this.state.editingAllowed}
                        onChange={(e) => this.setState({ editingAllowed: e.target.checked })}
                    /> */}
                    <label
                        style={{ marginLeft: 5 }}>
                        Jump to Time in Seconds
                    </label>
                    <input
                        type="number"
                        step="1"
                        style={{ marginLeft: 5 }}
                        defaultValue={this.state.restartTime}
                        onChange={(e) => this.setState({ restartTime: +e.target.value }, () => { this.saveDevOptions() })}
                    />
                    <input
                        type="button"
                        value="Jump To"
                        style={{ marginLeft: 5 }}
                        onClick={(e) => {
                            this.amp.currentTime(this.state.restartTime);
                            this.amp.play();
                        }} />
                </div>
                <div
                    style={{
                        margin: 10,
                        width: this.props.width,
                        height: this.props.height,
                        position: 'relative'
                    }}
                >
                    {
                        this.state.ampStreamingUrl ? (
                            <video
                                ref={this.videoRef}
                                className="azuremediaplayer amp-default-skin amp-big-play-centered"
                                tabIndex={0}
                                style={{
                                    position: 'absolute',
                                    zIndex: 1
                                }}
                                tabIndex={2}
                            />
                        ) : null
                    }

                    <canvas
                        ref={this.canvasRef}
                        width={this.props.width}
                        height={this.props.height}
                        style={{
                            border: this.props.border,
                            position: 'absolute',
                            zIndex: 2
                        }}
                        tabIndex={1}
                    />
                    <Editor
                        fps={this.props.fps}
                        width={this.props.width}
                        height={this.props.height}
                        aggregator={this.props.aggregator}
                        updateAggregator={this.props.updateAggregator}
                        selectedZoneIndex={this.props.selectedZoneIndex}
                        updateSelectedZoneIndex={this.props.updateSelectedZoneIndex}
                        collision={this.props.collision}
                        editingAllowed={this.state.editingAllowed}
                    />
                </div>
            </React.Fragment>
        );
    }

    // TODO: temp for dev, remove when finished with it
    saveDevOptions = () => {
        localStorage.setItem("UES-APP-DEVOPTIONS", JSON.stringify({
            syncOffset: this.state.syncOffset,
            syncBuffer: this.state.syncBuffer,
            restartTime: this.state.restartTime,
        }));
    }

    updateDetections = () => {
        if (this.currentMediaTime && !this.paused) {
            const detections = [];
            for (const inference in this.inferences) {
                const currentMediaTime = new Date(this.currentMediaTime * 1000);
                const inferenceTime = new Date(this.inferences[inference].timestamp / 1000 / 1000);

                const cmTime = currentMediaTime.getTime() + this.state.syncOffset;
                const iTime = inferenceTime.getTime();
                const difference = cmTime - iTime;
                const seconds = Math.abs(difference / 1000);
                if (seconds <= this.state.syncBuffer && this.inferences[inference].label === "person") {
                    detections.push(this.inferences[inference]);
                }
            }
            this.detections = detections;
        }
    }

    updateRealTimeMetrics = () => {
        let inside = 0;
        let outside = 0;
        const l = this.detections.length;
        for (let i = 0; i < l; i++) {
            const detection = this.detections[i];
            if (detection.in) {
                inside = inside + 1;
            } else if (detection.out) {
                outside = outside + 1;
            }
        }
        this.props.updateRealTimeMetrics({ inside, outside });
    }

    updateCurrentMediaTime = () => {
        if (this.amp && this.amp.currentMediaTime) {
            this.currentMediaTime = this.amp.currentMediaTime();
            // const d = new Date(this.currentMediaTime * 1000);
            // console.log(`${d.toString()} ${d.toUTCString()}`);
        }
    }

    async sync() {
        if (this.amp && this.amp.currentMediaTime && !this.paused) {
            if (this.state.blobPartition === null) {
                for (let i = 0; i < 4; i++) {
                    let containerName = `${this.props.iotHubName}/0${i}`;
                    const exists = await this.blobExists("detectoroutput", containerName);
                    if (exists) {
                        this.setState({
                            blobPartition: i
                        });
                        break;
                    }
                }
            } else {
                const dates = [
                    new Date(this.currentMediaTime * 1000),
                    new Date(this.currentMediaTime * 1000),
                    new Date(this.currentMediaTime * 1000)
                ];
                dates[0].setMinutes(dates[0].getMinutes() - 1);
                dates[2].setMinutes(dates[2].getMinutes() + 1);
                for (let d = 0; d < 3; d++) {
                    // TODO: account for daylight saving
                    let hours = dates[d].getUTCHours();
                    if (hours.length === 1) {
                        hours = `0${hours}`;
                    }
                    let minutes = dates[d].getUTCMinutes();
                    if (minutes.length === 1) {
                        minutes = `0${minutes}`;
                    }
                    let containerName = `${this.props.iotHubName}/0${this.state.blobPartition}/${dates[d].toLocaleDateString('fr-CA', {
                        year: 'numeric',
                        month: '2-digit',
                        day: '2-digit'
                    }).replace(/-/g, '/')}/${hours}/${minutes}`;

                    const exists = await this.blobExists("detectoroutput", containerName);
                    if (exists) {
                        const containerClient = this.props.blobServiceClient.getContainerClient("detectoroutput");
                        let iter = containerClient.listBlobsByHierarchy("/", { prefix: containerName });
                        const blobs = [];
                        for await (const item of iter) {
                            const blob = await this.downloadBlob("detectoroutput", item.name);
                            for (let i = 0; i < blob.length; i++) {
                                const view = blob[i];
                                const inferences = view.inferences;
                                for (let j = 0; j < inferences.length; j++) {
                                    const inference = inferences[j];
                                    if (inference.label === "person") {
                                        inference.in = view.in === 0 ? true : false;
                                        inference.out = view.out === 0 ? true : false;
                                    }
                                    const time = inference.timestamp;
                                    if (!this.inferences.hasOwnProperty(time)) {
                                        this.inferences[time] = inference;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    async blobExists(containerName, blobName) {
        const containerClient = this.props.blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobName);
        const exists = blobClient.exists();
        return exists;
    }

    async downloadBlob(containerName, blobName) {
        const containerClient = this.props.blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobName);
        const downloadBlockBlobResponse = await blobClient.download();

        const downloaded = await this.blobToString(await downloadBlockBlobResponse.blobBody);
        const views = downloaded.replace(/\\"/g, /'/).split('\r\n');

        const frames = [];
        const l = views.length;
        for (let i = 0; i < l; i++) {
            const view = views[i];
            if (view && view !== undefined && view !== "") {
                let parsedView = JSON.parse(view);
                if (parsedView.hasOwnProperty('Body')) {
                    let body = parsedView.Body;
                    if (body && body !== undefined && body !== "") {
                        let decodedBody = atob(body);
                        if (decodedBody && decodedBody !== undefined && decodedBody !== "") {
                            try {
                                let parsedBody = JSON.parse(decodedBody.replace(/bbox:/g, '"bbox:"'));
                                if (parsedBody && parsedBody !== undefined && parsedBody !== "") {
                                    if (parsedBody.hasOwnProperty('inferences')) {
                                        if (parsedBody.inferences.length > 0) {
                                            frames.push(parsedBody);
                                        }
                                    }
                                }
                            } catch (e) {
                                console.log(e);
                            }
                        }
                    }
                }
            }
        }

        return frames;
    }

    async blobToString(blob) {
        const fileReader = new FileReader();
        return new Promise((resolve, reject) => {
            fileReader.onloadend = (ev) => {
                resolve(ev.target.result);
            };
            fileReader.onerror = reject;
            fileReader.readAsText(blob);
        });
    }

    clamp = (value, min, max) => {
        return Math.min(Math.max(value, min), max);
    }

    draw = () => {
        const canvasContext = this.canvasRef.current?.getContext("2d");
        if (canvasContext) {
            canvasContext.clearRect(0, 0, this.props.width, this.props.height);
            // this.drawDetections(canvasContext, this.props.frame.detections);
            this.drawDetections(canvasContext, this.detections);
        }
    }

    drawDetections(canvasContext, detections) {
        const l = detections.length;
        for (let i = 0; i < l; i++) {
            const detection = detections[i];
            this.drawDetection(canvasContext, detection);
        }
    }

    drawDetection(canvasContext, detection) {
        if (detection.in || this.isAcrossThresholds(detection.bbox, this.props.aggregator.zones)) {
            canvasContext.strokeStyle = 'yellow';
            canvasContext.lineWidth = 4;
        } else {
            canvasContext.strokeStyle = 'lightblue';
            canvasContext.lineWidth = 2;
        }
        const x = this.props.width * detection.bbox[0];
        const y = this.props.height * detection.bbox[1];
        const w = this.props.width * Math.abs(detection.bbox[2] - detection.bbox[0]);
        const h = this.props.height * Math.abs(detection.bbox[3] - detection.bbox[1]);
        canvasContext.strokeRect(x, y, w, h);
    }

    isAcrossThresholds(bbox, zones) {
        const l = zones.length;
        for (let i = 0; i < l; i++) {
            const zone = zones[i];
            if (zone.polygon.length > 0) {
                if (this.isAcrossThreshold(bbox, zone)) {
                    return true;
                }
            }
        }
        return false;
    }

    isAcrossThreshold(bbox, zone) {
        let pointA = [];
        let pointB = [];
        let pointC = zone.polygon[0];
        let pointD = zone.polygon[1];
        pointA = [pointC[0], 0];
        pointB = [pointD[0], 0]
        return this.props.collision.isBBoxInZones(bbox, [{
            name: zone.name,
            polygon: [pointA, pointB, pointC, pointD],
            threshold: zone.threshold
        }]);
    }
}
