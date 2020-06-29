import React from 'react';

export class AggregateStatsInTimeWindow extends React.Component {
    static defaultProps = {
        aggregator: {
            lines: [],
            zones: [{
                name: "queue",
                polygon: [],
                threshold: 10.0
            }]
        },
    }

    constructor(props) {
        super(props);
        this.state = {
            totalCollisions: 0,
            totalDetections: 0,
            maxCollisionsPerSecond: 0,
            maxDetectionsPerSecond: 0
        }
        this.dateTimeRef = React.createRef();
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
                        Start: 
                        <input
                            ref={this.dateTimeRef}
                            type="datetime-local"
                            style={{
                                margin: 5
                            }}
                            onChange={(e) => {
                                this.calculate();
                            }}
                        />
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
        // parse the start datetime to get a list of all the blobs
        const startDateTime = new Date(this.dateTimeRef.current.value);
        const endDateTime = new Date(startDateTime); 
        endDateTime.setMinutes(endDateTime.getMinutes() + 60);

        const containerNames = [];
        
        while(startDateTime < endDateTime) {
            containerNames.push({
                hour: `${startDateTime.toLocaleDateString('fr-CA', {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit' 
                }).replace(/-/g, '/')}/${startDateTime.toLocaleTimeString([], { hour: '2-digit' }).replace(/:/g, '/').split(' ')[0]}`,
                minute: `${startDateTime.toLocaleDateString('fr-CA', {
                    year: 'numeric',
                    month: '2-digit',
                    day: '2-digit' 
                }).replace(/-/g, '/')}/${startDateTime.toLocaleTimeString({ hour: '2-digit', minute: '2-digit' }).replace(/:/g, '/').split(' ')[0]}`
            });
            startDateTime.setMinutes(startDateTime.getMinutes() + 1);
        }
        
        console.log(containerNames);

        return;

        // calculate the frames for all of the blobs
        let frames = [];
        const cl = containerNames.length;
        for (let i = 0; i < cl; i++) {
            const containerNameHour = `iot-unifiededge-001/00/${containerNames[i].hour}`;
            const containerNameMinute = `iot-unifiededge-001/00/${containerNames[i].minute}`;
            const exists = await this.blobExists("detectoroutput", containerNameHour);
            if (exists) {
                const containerClient = this.props.blobServiceClient.getContainerClient("detectoroutput");
                let iter = containerClient.listBlobsByHierarchy("/", { prefix: containerNameMinute });
                console.log(containerNameMinute);
                const blobs = [];
                for await (const item of iter) {
                    const blob = await this.downloadBlob("detectoroutput", item.name);
                    blobs.push(blob);
                }

                frames = [...frames, ...this.calculateFrames(blobs)];
            }
        }

        // calculate the max per second and total max per second metrics
        let totalDetections = 0;
        let maxDetections = 0;

        const fl = frames.length;
        for (let i = 0; i < fl; i++) {
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
            for (let i = 0; i < l; i++) {
                const item = blob[i];
                const t = new Date(item.image_name).getTime();
                if (time === null) {
                    time = t;
                    frame.detections = item.detections;
                    frame.maxDetections = item.detections.length;
                    if (i + 1 == l) {
                        frames.push(frame);
                    }
                } else if (Math.abs(t - time) >= 1000) {
                    frames.push(frame);
                    time = t;
                    frame = {
                        detections: item.detections,
                        maxDetections: item.detections.length
                    }
                    if (i + 1 == l) {
                        frames.push(frame);
                    }
                } else {
                    frame.detections = [...frame.detections, ...item.detections];
                    frame.maxDetections = item.detections.length > frame.maxDetections ? item.detections.length : frame.maxDetections;
                    if (i + 1 == l) {
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
        return dt.toUTCString();
    }

    calculate15MinutesAhead = () => {
        const dt = new Date();
        dt.setMinutes(dt.minutes + 15);
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