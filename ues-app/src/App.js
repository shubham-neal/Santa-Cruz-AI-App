import React from 'react';
import './App.css';
import io from 'socket.io-client';
import { defaults } from 'react-chartjs-2';
import { Line } from 'react-chartjs-2';
import { Camera } from './components/Camera';

const { BlobServiceClient } = require("@azure/storage-blob");

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
            collisions: 0,
            detections: 0,
            totalCollisions: 0,
            totalDetections: 0,
            maxCollisionsPerSecond: 0,
            maxDetectionsPerSecond: 0,
            maxPerSecond: {
                times: [],
                collisions: [],
                detections: []
            },
            image: new Image(),
            chartData: {
                labels: [],
                datasets: []
            },
            signedIn: false
        }
        defaults.global.animation = false;
        this.account = 'adlsunifiededgedev001';
        this.containerName = 'still-images';
        this.blobPath = 'Office/cam001';
        this.sharedAccessSignature = "?sv=2019-10-10&ss=bfqt&srt=sco&sp=rwdlacupx&se=2021-06-17T08:40:10Z&st=2020-06-17T00:40:10Z&spr=https&sig=rOA0RnsukPtfqNfqa7STBNtEG7LPwTP4aZcD2h0et%2B0%3D";
        this.blobServiceClient = new BlobServiceClient(`https://${this.account}.blob.core.windows.net?${this.sharedAccessSignature}`, this.defaultAzureCredential);
    }

    componentDidMount() {
        var socket = io('ws://ues-messages-app.azurewebsites.net', { transports: ['websocket'] });
        socket.on('connect', function () {
            console.log('connected!');
        });
        socket.on('message', (message) => {
            const data = JSON.parse(message);
            if (data && data.hasOwnProperty('body')) {
                if (data.body.hasOwnProperty('detections')) {
                    let collisions = 0;
                    let detections = 0;
                    const l = data.body.detections.length;
                    for (let i = 0; i < l; i++) {
                        const detection = data.body.detections[i];
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
                    const maxCollisionsPerSecond = this.state.maxCollisionsPerSecond;
                    const maxDetectionsPerSecond = this.state.maxDetectionsPerSecond;
                    this.setState({
                        frame: data.body,
                        collisions: collisions,
                        detections: detections,
                        maxCollisionsPerSecond: collisions > maxCollisionsPerSecond ? collisions : maxCollisionsPerSecond,
                        maxDetectionsPerSecond: detections > maxDetectionsPerSecond ? detections : maxDetectionsPerSecond
                    });
                }
                if (data.body.hasOwnProperty("image_name")) {
                    this.updateImage(data.body.image_name);
                }
            }
        });

        // const url = 'ws://ues-messages-app.azurewebsites.net:8080';
        // const connection = new WebSocket(url);
        // connection.onopen = () => {
        //     connection.send('Client connected...');
        // }
        // connection.onmessage = (e) => {
        //     const data = JSON.parse(e.data);
        //     if (data && data.hasOwnProperty('body')) {
        //         if (data.body.hasOwnProperty('detections')) {
        //             let collisions = 0;
        //             let detections = 0;
        //             const l = data.body.detections.length;
        //             for (let i = 0; i < l; i++) {
        //                 const detection = data.body.detections[i];
        //                 if (detection.bbox) {
        //                     const polygon = [
        //                         [detection.bbox[0], detection.bbox[1]],
        //                         [detection.bbox[2], detection.bbox[1]],
        //                         [detection.bbox[2], detection.bbox[3]],
        //                         [detection.bbox[0], detection.bbox[3]],
        //                         [detection.bbox[0], detection.bbox[1]],
        //                     ];
        //                     if (this.isBBoxInZones(polygon, this.state.aggregator.zones)) {
        //                         detection.collides = true;
        //                         collisions = collisions + 1;
        //                     } else {
        //                         detection.collides = false;
        //                     }
        //                 }
        //                 detections = detections + 1;
        //             }
        //             const maxCollisionsPerSecond = this.state.maxCollisionsPerSecond;
        //             const maxDetectionsPerSecond = this.state.maxDetectionsPerSecond;
        //             this.setState({
        //                 frame: data.body,
        //                 collisions: collisions,
        //                 detections: detections,
        //                 maxCollisionsPerSecond: collisions > maxCollisionsPerSecond ? collisions : maxCollisionsPerSecond,
        //                 maxDetectionsPerSecond: detections > maxDetectionsPerSecond ? detections : maxDetectionsPerSecond
        //             });
        //         }
        //         if (data.body.hasOwnProperty("image_name")) {
        //             this.updateImage(data.body.image_name);
        //         }
        //     }
        // }
        // connection.onerror = (error) => {
        //     console.log(`WebSocket error: ${error}`);
        // }

        setInterval(() => {
            if (this.state.signedIn) {
                const maxCollisionsPerSecond = this.state.maxCollisionsPerSecond;
                const maxDetectionsPerSecond = this.state.maxDetectionsPerSecond;

                // track per second
                this.state.maxPerSecond.times.push(this.formatTime(new Date()));
                this.state.maxPerSecond.collisions.push(maxCollisionsPerSecond);
                this.state.maxPerSecond.detections.push(maxDetectionsPerSecond);
                if (this.state.maxPerSecond.times.length > 10) {
                    this.state.maxPerSecond.times.shift();
                    this.state.maxPerSecond.collisions.shift();
                    this.state.maxPerSecond.detections.shift();
                }
                this.updateChart();

                this.setState({
                    totalCollisions: this.state.totalCollisions + maxCollisionsPerSecond,
                    totalDetections: this.state.totalDetections + maxDetectionsPerSecond
                }, () => {
                    this.setState({
                        maxCollisionsPerSecond: 0,
                        maxDetectionsPerSecond: 0
                    })
                });
            }
        }, 1000);
    }

    render() {
        return this.state.signedIn ? (
            <React.Fragment>
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
                            <div>
                                <span
                                    style={{
                                        margin: 5,
                                        fontWeight: 'bold',
                                        borderBottom: '1px solid black'
                                    }}
                                >
                                    Demo
                                </span>
                                <span
                                    style={{
                                        margin: 5
                                    }}
                                >
                                    Live
                                </span>
                            </div>
                            <Camera
                                fps={this.state.fps}
                                width={this.state.width}
                                height={this.state.height}
                                aggregator={this.state.aggregator}
                                frame={this.state.frame}
                                image={this.state.image}
                                updateAggregator={this.updateAggregator}
                            />
                            <div
                                style={{
                                    width: this.state.width,
                                    height: this.state.height,
                                    padding: 10
                                }}
                            >
                                <Line redraw
                                    data={this.state.chartData}
                                    options={{
                                        maintainAspectRatio: true,
                                        legend: {
                                            display: true,
                                            position: 'bottom'
                                        },
                                        layout: {
                                            padding: {
                                                left: 10,
                                                right: 0,
                                                top: 0,
                                                bottom: 0
                                            }
                                        },
                                        title: {
                                            display: true,
                                            text: 'Count of people vs Time'
                                        }
                                    }}
                                />
                            </div>
                        </div>
                        <div
                            style={{
                                margin: 10
                            }}
                        >
                            <div
                                style={{
                                    marginBottom: 10,
                                    fontWeight: 'bold'
                                }}
                            >
                                Real time metrics
                            </div>
                            <div>
                                People detections in frame:
                            </div>
                            <div>
                                <b>{this.state.detections}</b>
                            </div>
                            <div>
                                People detections in zone:
                            </div>
                            <div>
                                <b>{this.state.collisions}</b>
                            </div>
                            <div>
                                Max people detections in frame per second:
                            </div>
                            <div>
                                <b>{this.state.maxDetectionsPerSecond}</b>
                            </div>
                            <div>
                                Max people detections in zone per second:
                            </div>
                            <div>
                                <b>{this.state.maxCollisionsPerSecond}</b>
                            </div>
                            <div>
                                Total max people detections in frame per second:
                            </div>
                            <div>
                                <b>{this.state.totalDetections}</b>
                            </div>
                            <div>
                                Total max people detections in zone per second:
                            </div>
                            <div>
                                <b>{this.state.totalCollisions}</b>
                            </div>
                        </div>
                    </div>
                </div>
            </React.Fragment>
        ) : (
                <React.Fragment>
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
                                <input type="text" placeholder="Enter password" onChange={(e) => {
                                    const value = e.target.value;
                                    if (value === "8675309") {
                                        this.setState({
                                            signedIn: true
                                        })
                                    }
                                }} />
                            </div>
                        </div>
                    </div>
                </React.Fragment>
            );
    }

    updateChart = () => {
        if (this.state.maxPerSecond.times.length > 0) {
            const chartData = {
                labels: this.state.maxPerSecond.times,
                datasets: [{
                    label: 'Max people detections in frame per second',
                    data: this.state.maxPerSecond.detections,
                    backgroundColor: [
                        'transparent'
                    ],
                    borderColor: [
                        'lightblue'
                    ],
                    borderWidth: 1
                }, {
                    label: 'Max people detections in zone per second',
                    data: this.state.maxPerSecond.collisions,
                    backgroundColor: [
                        'transparent'
                    ],
                    borderColor: [
                        'yellow'
                    ],
                    borderWidth: 2
                }]
            };
            this.setState({
                chartData: chartData
            });
        }
    }

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

    async updateImage(imageName) {
        const blobName = `${this.blobPath}/${imageName.split('T')[0]}/${imageName}.jpg`;
        const containerClient = this.blobServiceClient.getContainerClient(this.containerName);
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
        this.setState({
            aggregator: aggregator
        }, () => {
            // console.log(JSON.stringify(aggregator));
        });
    }

    // collisions
    isBBoxInZones(bbox, zones) {
        const l = zones.length;
        for (let i = 0; i < l; i++) {
            const zone = zones[i];
            if (this.isBBoxInZone(bbox, zone)) {
                return true;
            }
        }
        return false;
    }

    isBBoxInZone(bbox, zone) {
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

        var i = 0, j = polygon.length - 1;
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
