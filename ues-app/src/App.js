import React from 'react';
import axios from 'axios';
import './App.css';
import { Pivot, PivotItem } from 'office-ui-fabric-react/lib/Pivot';
import io from 'socket.io-client';
import { Camera } from './components/Camera';
import { Password } from './components/Password';
import { RealTimeMetrics } from './components/RealTimeMetrics';
import { CountOfPeopleVsTime } from './components/CountOfPeopleVsTime';
import { AggregateStatsInTimeWindow } from './components/AggregateStatsInTimeWindow';
import { AggregateCountOfPeopleVsTime } from './components/AggregateCountOfPeopleVsTime';
import { Azure } from './components/Azure';
import { EditZones } from './components/EditZones';
import { report } from 'process';

const { BlobServiceClient } = require("@azure/storage-blob");

let account = null; //'adlsunifiededgedev001';
let containerName = null; //'still-images';
let blobPath = null; //'Office/cam001';
let sharedAccessSignature = null; //"sv=2019-10-10&ss=bfqt&srt=sco&sp=rwdlacupx&se=2021-06-17T08:40:10Z&st=2020-06-17T00:40:10Z&spr=https&sig=rOA0RnsukPtfqNfqa7STBNtEG7LPwTP4aZcD2h0et%2B0%3D";
let blobServiceClient = null;// new BlobServiceClient(`https://${account}.blob.core.windows.net?${sharedAccessSignature}`);

const isAdmin = false;

let socket = null;// io('wss://ues-messages-app.azurewebsites.net', { transports: ['websocket'] });

// demo =           "rtsp": "/tmp/video/caffeteria.mp4",
// live =           "rtsp": "rtsp://rtspsim:554/media/caffeteria.mkv",

class App extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            width: 640,
            height: 360,
            fps: 30,
            aggregator: {
                lines: [],
                zones: [{
                    name: "queue",
                    polygon: [],
                    threshold: 10.0
                }]
            },
            frame: {
                detections: []
            },
            frames: [],
            collisions: 0,
            detections: 0,
            image: new Image(),
            accessGranted: isAdmin,
            blobServiceClient: blobServiceClient,
            realTimeChart: true,
            aggregateChartMetrics: {
                times: [],
                collisions: [],
                detections: []
            }
        }
    }

    componentDidMount() {
        axios.get(`./settings`)
            .then((response) => {
                console.log(response);
                const data = response.data;
                // blob storage
                account = data.account;
                containerName = data.containerName;
                blobPath = data.blobPath;
                sharedAccessSignature = data.sharedAccessSignature;
                blobServiceClient = new BlobServiceClient(`https://${account}.blob.core.windows.net?${sharedAccessSignature}`);

                const location = document.location.host

                // messages
                socket = io(`wss://${window.location.host}`, { transports: ['websocket'] });

                socket.on('connect', function () {
                    console.log('connected!');
                });
                socket.on('message', (message) => {
                    const data = JSON.parse(message);
                    this.updateData(data);
                });
                socket.on('passwordchecked', (message) => {
                    const data = JSON.parse(message);
                    if (data.success) {
                        localStorage.setItem("UES-APP-PASSWORD", btoa(data.value));
                        this.setState({
                            accessGranted: true
                        });
                    }
                })

                // password
                let password = "";
                const passwordEncoded = localStorage.getItem("UES-APP-PASSWORD") || "";
                if (passwordEncoded !== "") {
                    const passwordDecoded = atob(passwordEncoded);
                    this.checkPassword(passwordDecoded);
                }

                // aggregator
                let aggregator = this.state.aggregator;
                const aggregatorEncoded = localStorage.getItem("UES-APP-AGGREGATOR") || "";
                if (aggregatorEncoded !== "") {
                    const aggregatorDecoded = atob(aggregatorEncoded);
                    aggregator = JSON.parse(aggregatorDecoded);
                    this.setState({
                        aggregator: aggregator
                    });
                }
            });
    }

    render() {
        return this.state.accessGranted ? (
            <React.Fragment>
                <Azure />
                <div style={{
                    display: "flex",
                    flexDirection: "column",
                    justifyContent: "center",
                    alignItems: "center",
                    margin: 10,
                    padding: 10
                }}>
                    <div
                        style={{
                            display: 'flex',
                            flexDirection: 'row',
                            backgroundColor: 'white',
                            margin: 10,
                            padding: 10
                        }}
                    >
                        <div
                            style={{
                                display: 'flex',
                                flexDirection: 'column'
                            }}
                        >
                            {
                                this.isAdmin ? (
                                    <Pivot>
                                        <PivotItem
                                            headerText="Demo"
                                        />
                                        <PivotItem

                                            headerText="Live"
                                        />
                                    </Pivot>
                                ) : null
                            }
                            <Camera
                                fps={this.state.fps}
                                width={this.state.width}
                                height={this.state.height}
                                aggregator={this.state.aggregator}
                                frame={this.state.frame}
                                image={this.state.image}
                                updateAggregator={this.updateAggregator}
                            />
                            <Pivot
                                onLinkClick={(item) => {
                                    this.setState({
                                        realTimeChart: item.props.itemKey === "realtime"
                                    });
                                }}
                            >
                                <PivotItem
                                    headerText="Real time"
                                    itemKey="realtime"
                                />
                                <PivotItem
                                    headerText="Aggregate"
                                    itemKey="aggregate"
                                />
                            </Pivot>
                            {
                                this.state.realTimeChart ?
                                    <CountOfPeopleVsTime
                                        aggregator={this.state.aggregator}
                                        frame={this.state.frame}
                                        collisions={this.state.collisions}
                                        detections={this.state.detections}
                                    /> :
                                    <AggregateCountOfPeopleVsTime
                                        aggregator={this.state.aggregator}
                                        frame={this.state.frame}
                                        collisions={this.state.collisions}
                                        detections={this.state.detections}

                                        aggregateChartMetrics={this.state.aggregateChartMetrics}
                                    />
                            }
                        </div>
                        <div
                            style={{
                                display: 'flex',
                                flexDirection: 'column',
                                backgroundColor: 'white',
                                margin: 10,
                                padding: 10
                            }}
                        >
                            <RealTimeMetrics
                                aggregator={this.state.aggregator}
                                frame={this.state.frame}
                                collisions={this.state.collisions}
                                detections={this.state.detections}
                            />
                            <AggregateStatsInTimeWindow
                                aggregator={this.state.aggregator}
                                isBBoxInZones={this.isBBoxInZones}
                                blobServiceClient={this.state.blobServiceClient}
                                updateAggregateChartMetrics={this.updateAggregateChartMetrics}
                            />
                            <EditZones
                                aggregator={this.state.aggregator}
                                updateAggregator={this.updateAggregator}
                            />
                        </div>
                    </div>
                </div>
            </React.Fragment>
        ) : (
                <React.Fragment>
                    <Azure />
                    <Password updatePassword={this.updatePassword} />
                </React.Fragment>
            );
    }

    updateAggregateChartMetrics = (metrics) => {
        this.setState({
            aggregateChartMetrics: metrics
        });
    }

    // date and time
    formatDate = (date) => {
        // Note: en-EN won't return in year-month-day order
        return date.toLocaleDateString('fr-CA', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        });
    }

    formatTime = (date) => {
        // Note: en-EN won't return in without the AM/PM
        return date.toLocaleTimeString('it-IT');
    }

    // image from blob storage

    async updateImage(imageName) {
        const blobName = `${blobPath}/${imageName.split('T')[0]}/${imageName}.jpg`;
        const containerClient = blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobName);

        const downloadBlockBlobResponse = await blobClient.download();
        const downloaded = await this.blobToBinaryString(await downloadBlockBlobResponse.blobBody);
        const image = new Image();
        image.src = `data:image/jpeg;base64,${btoa(downloaded)}`;
        this.setState({
            image: image
        });
    }

    async blobToBinaryString(blob) {
        const fileReader = new FileReader();
        return new Promise((resolve, reject) => {
            fileReader.onloadend = (ev) => {
                resolve(ev.target.result);
            };
            fileReader.onerror = reject;
            fileReader.readAsBinaryString(blob);
        });
    }

    updateAggregator = (aggregator) => {
        localStorage.setItem("UES-APP-AGGREGATOR", btoa(JSON.stringify(aggregator)));
        this.setState({
            aggregator: aggregator
        });
    }

    updatePassword = (e) => {
        const value = e.target.value;
        this.checkPassword(value);
    }

    checkPassword = (value) => {
        socket.emit("checkpassword", value);
    }

    // detections
    updateData = (data) => {
        if (data && data.hasOwnProperty('body')) {
            const frame = data.body;
            if (frame.hasOwnProperty("cameraId")) {
                if (frame.hasOwnProperty('detections') && !this.state.rtcv) {
                    let collisions = 0;
                    let detections = 0;
                    const l = frame.detections.length;
                    for (let i = 0; i < l; i++) {
                        const detection = frame.detections[i];
                        if (detection.bbox) {
                            const polygon = [
                                [detection.bbox[0], detection.bbox[1]],
                                [detection.bbox[2], detection.bbox[1]],
                                [detection.bbox[2], detection.bbox[3]],
                                [detection.bbox[0], detection.bbox[3]],
                                [detection.bbox[0], detection.bbox[1]],
                            ];
                            if (this.isBBoxInZones(polygon, this.state.aggregator.zones)) {
                                detection.collides = true;
                                collisions = collisions + 1;
                            } else {
                                detection.collides = false;
                            }
                        }
                        detections = detections + 1;
                    }
                    this.setState({
                        frame: frame,
                        collisions: collisions,
                        detections: detections
                    });
                }
                if (frame.hasOwnProperty("image_name")) {
                    this.updateImage(frame.image_name);
                }
            }
        }
    }

    // collisions
    isBBoxInZones = (bbox, zones) => {
        const l = zones.length;
        for (let i = 0; i < l; i++) {
            const zone = zones[i];
            if (this.isBBoxInZone(bbox, zone)) {
                return true;
            }
        }
        return false;
    }

    isBBoxInZone = (bbox, zone) => {
        const polygon = [];
        let l = zone.polygon.length;
        if (l > 0) {
            for (let i = 0; i < l; i++) {
                polygon.push({ x: zone.polygon[i][0], y: zone.polygon[i][1] });
            }
            l = bbox.length;
            for (let i = 1; i < l; i++) {
                const point = { x: bbox[i][0], y: bbox[0][1] };
                if (this.isPointInPolygon(point, polygon)) {
                    return true;
                }
            }
            if (bbox.length > 1 && polygon.length > 1 && this.doAnyLinesIntersect(bbox, polygon)) {
                return true;
            }
        }
        return false;
    }

    doAnyLinesIntersect = (bbox, polygon) => {
        let l = polygon.length;
        for (let i = 1; i < l; i++) {
            const from1 = polygon[i - 1];
            const to1 = polygon[i];
            let l2 = bbox.length;
            for (let j = 1; j < l2; j++) {
                const from2 = { x: bbox[j - 1][0], y: bbox[j - 1][1] };
                const to2 = { x: bbox[j][0], y: bbox[j][1] };
                if (this.doLinesIntersect(from1, to1, from2, to2) !== undefined) {
                    return true;
                }
            }
        }

        return false;
    }

    doLinesIntersect = (from1, to1, from2, to2) => {
        const dX = to1.x - from1.x;
        const dY = to1.y - from1.y;

        const determinant = dX * (to2.y - from2.y) - (to2.x - from2.x) * dY;
        if (determinant === 0) return undefined; // parallel lines

        const lambda = ((to2.y - from2.y) * (to2.x - from1.x) + (from2.x - to2.x) * (to2.y - from1.y)) / determinant;
        const gamma = ((from1.y - to1.y) * (to2.x - from1.x) + dX * (to2.y - from1.y)) / determinant;

        // check if there is an intersection
        if (!(0 <= lambda && lambda <= 1) || !(0 <= gamma && gamma <= 1)) return undefined;

        return {
            x: from1.x + lambda * dX,
            y: from1.y + lambda * dY,
        };
    }

    isPointInPolygon(p, polygon) {
        let isInside = false;
        let minX = polygon[0].x;
        let maxX = polygon[0].x;
        let minY = polygon[0].y;
        let maxY = polygon[0].y;
        for (let n = 1; n < polygon.length; n++) {
            const q = polygon[n];
            minX = Math.min(q.x, minX);
            maxX = Math.max(q.x, maxX);
            minY = Math.min(q.y, minY);
            maxY = Math.max(q.y, maxY);
        }

        if (p.x < minX || p.x > maxX || p.y < minY || p.y > maxY) {
            return false;
        }

        let i = 0, j = polygon.length - 1;
        for (i, j; i < polygon.length; j = i++) {
            if ((polygon[i].y > p.y) !== (polygon[j].y > p.y) &&
                p.x < (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x) {
                isInside = !isInside;
            }
        }

        return isInside;
    }
}

export default App;
