import React from 'react';

export class AggregateStatsInTimeWindow extends React.Component {
    static defaultProps = {

    }

    constructor(props) {
        super(props);
        this.state = {
            totalCollisions: 0,
            totalDetections: 0,
            maxCollisionsPerSecond: 0,
            maxDetectionsPerSecond: 0
        }
        this.startDateRef = React.createRef();
        this.startTimeRef = React.createRef();
        this.endDateRef = React.createRef();
        this.endTimeRef = React.createRef();
    }

    render() {
        const names = this.props.aggregator.zones.map((zone, index) => {
            return (
                <span key={index}>{index > 0 ? ',' : null}{zone.name}</span>
            )
        });
        return (
            <React.Fragment>
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
                        Aggregate stats in time window
                    </div>
                    <div>
                        <table>
                            <tbody>
                                <tr>
                                    <td>Start</td>
                                    <td>
                                        <input
                                            ref={this.startDateRef}
                                            type="date"
                                            min={this.formatDate(new Date())}
                                            max={this.formatDate(new Date())}
                                            defaultValue={this.formatDate(new Date())}
                                            onChange={(e) => {
                                                console.log(e.target.value);
                                            }}
                                        />
                                        <input
                                            ref={this.startTimeRef}
                                            type="time"
                                            min={this.formatTime(new Date())}
                                            max={this.formatTime(new Date())}
                                            defaultValue={this.formatTime(this.calculateNow())}
                                            onChange={(e) => {
                                                console.log(e.target.value);
                                            }}
                                        />
                                    </td>
                                </tr>
                                <tr>
                                    <td>End</td>
                                    <td>
                                        <input
                                            ref={this.endDateRef}
                                            type="date"
                                            min={this.formatDate(new Date())}
                                            max={this.formatDate(new Date())}
                                            defaultValue={this.formatDate(new Date())}
                                            onChange={(e) => {

                                                console.log(e.target.value);
                                            }}
                                        />
                                        <input
                                            ref={this.endTimeRef}
                                            type="time"
                                            min={this.formatTime(new Date())}
                                            max={this.formatTime(new Date())}
                                            defaultValue={this.formatTime(this.calculate15MinutesAgo())}
                                            onChange={(e) => {
                                                console.log(e.target.value);
                                            }}
                                        />
                                    </td>
                                </tr>
                                <tr>
                                    <td colSpan={2}>
                                        <input
                                            type="button"
                                            value="Calculate"
                                            onClick={(e) => {
                                                this.calculate();
                                            }}
                                        />
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                    <div>
                        Max people detections in frame per second
                    </div>
                    <div>
                        <b>{this.state.maxDetectionsPerSecond}</b>
                    </div>
                    <div>
                        Max people detections in zones ({names}) per second
                    </div>
                    <div>
                        <b>{this.state.maxCollisionsPerSecond}</b>
                    </div>
                    <div>
                        Total max people detections in frame per second
                    </div>
                    <div>
                        <b>{this.state.totalDetections}</b>
                    </div>
                    <div>
                        Total max people detections in zones ({names}) per second
                    </div>
                    <div>
                        <b>{this.state.totalCollisions}</b>
                    </div>
                </div>
            </React.Fragment>
        );
    }

    async calculate() {
        // format the date range to get a list of all the blobs
        const startDate = this.startDateRef.current.value;
        const startTime = this.startTimeRef.current.value;
        const endDate = this.endDateRef.current.value;
        const endTime = this.endTimeRef.current.value;
        
        // first clamp the year range

        // then clamp the month range

        // then clamp the day range

        

        // calculate the frames for all of the blobs

        let frames = [];

        const exists = await this.blobExists("detectoroutput", "iot-unifiededge-001/00/2020/06/28/23");
        if (exists) {
            const containerClient = this.props.blobServiceClient.getContainerClient("detectoroutput");
            console.log("Listing blobs by hierarchy");
            let itr = containerClient.listBlobsFlat()
            let iter = containerClient.listBlobsByHierarchy("/", { prefix: "iot-unifiededge-001/00/2020/06/28/23/30" });
            const blobs = [];
            for await (const item of iter) {
                console.log(`\tBlobItem: name - ${item.name}, last modified - ${item.properties.lastModified}`);
                const blob = await this.downloadBlob("detectoroutput", item.name);
                blobs.push(blob);
            }

            frames = [...frames, ...this.calculateFrames(blobs)];
        }

        // calculate the max per second and total max per second metrics
        let totalDetections = 0;
        let maxDetections = 0;

        const l = frames.length;
        for (let i = 0; i < l; i++) {
            const frame = frames[i];
            totalDetections = totalDetections + frame.maxDetections;
            if (maxDetections < frame.maxDetections) {
                maxDetections = frame.maxDetections;
            }
        }

        this.setState({
            totalDetections: totalDetections,
            maxDetectionsPerSecond: maxDetections
        });
    }

    calculateFrames = (blobs) => {
        const frames = [];
        let time = null;
        let frame = {
            detections: [],
            maxDetections: 0
        }
        for (const blob of blobs) {
            const l = blob.length;
            for (let i=0; i<l; i++) {
                const item = blob[i];
                const t = new Date(item.image_name).getTime();
                if (time === null) {
                    time = t;
                    frame.detections = item.detections;
                    frame.maxDetections = item.detections.length;
                    if(i+1 == l) {
                        frames.push(frame);
                    }
                } else if (Math.abs(t - time) >= 1000) {
                    frames.push(frame);
                    time = t;
                    frame = {
                        detections: item.detections,
                        maxDetections: item.detections.length 
                    }
                    if(i+1 == l) {
                        frames.push(frame);
                    }
                } else {
                    frame.detections = [...frame.detections, ...item.detections];
                    frame.maxDetections = item.detections.length > frame.maxDetections ? item.detections.length : frame.maxDetections;
                    if(i+1 == l) {
                        frames.push(frame);
                    }
                }
            }
        }
        return frames;
    }

    formatDate = (date) => {
        // Note: en-EN won't return in year-month-day order
        return date.toLocaleDateString('fr-CA', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        });
    }

    calculateNow = () => {
        const dt = new Date();
        return dt;
    }

    calculate15MinutesAgo = () => {
        const dt = new Date();
        dt.setMinutes(-15);
        return dt;
    }

    formatTime = (date) => {
        // Note: en-EN won't return in without the AM/PM
        return date.toLocaleTimeString('it-IT');
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
                let body = parsedView.Body;
                let decodedBody = atob(body);
                let parsedBody = JSON.parse(decodedBody);
                frames.push(parsedBody);
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
}