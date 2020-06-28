import React from 'react';

export class AggregateStatsInTimeWindow extends React.Component {
    static defaultProps = {
        aggregator: {
            lines: [],
            zones: []
        },
        frame: {
            detections: []
        },
        collisions: 0,
        detections: 0,
        blobExists: (containerName, blobName) => { },
        downloadBlob: (containerName, blobName) => { }
    }

    constructor(props) {
        super(props);
        this.state = {
            totalCollisions: 0,
            totalDetections: 0,
            maxCollisionsPerSecond: 0,
            maxDetectionsPerSecond: 0
        }
    }

    componentDidMount() {
        setInterval(() => {
            const maxCollisionsPerSecond = this.state.maxCollisionsPerSecond;
            const maxDetectionsPerSecond = this.state.maxDetectionsPerSecond;

            this.setState({
                totalCollisions: this.state.totalCollisions + maxCollisionsPerSecond,
                totalDetections: this.state.totalDetections + maxDetectionsPerSecond
            }, () => {
                this.setState({
                    maxCollisionsPerSecond: 0,
                    maxDetectionsPerSecond: 0
                })
            });
        }, 1000);
    }

    componentDidUpdate(prevProps) {
        // update the metrics
        if (this.props.frame !== prevProps.frame) {
            const maxCollisionsPerSecond = this.state.maxCollisionsPerSecond;
            const maxDetectionsPerSecond = this.state.maxDetectionsPerSecond;
            this.setState({
                maxCollisionsPerSecond: this.props.collisions > maxCollisionsPerSecond ? this.props.collisions : maxCollisionsPerSecond,
                maxDetectionsPerSecond: this.props.detections > maxDetectionsPerSecond ? this.props.detections : maxDetectionsPerSecond
            });
        }
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
                                    <td><input type="date" /> <input type="time" /></td>
                                </tr>
                                <tr>
                                    <td>End</td>
                                    <td><input type="date" /> <input type="time" /></td>
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
                        People detections in frame
                    </div>
                    <div>
                        <b>{this.props.detections}</b>
                    </div>
                    <div>
                        People detections in zones ({names})
                    </div>
                    <div>
                        <b>{this.props.collisions}</b>
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
        const exists = await this.blobExists("detectoroutput", "iot-unifiededge-001/00/2020/06/28/23");
        if (exists) {
            const containerClient = this.props.blobServiceClient.getContainerClient("detectoroutput");
            console.log("Listing blobs by hierarchy");
            let itr = containerClient.listBlobsFlat()
            let iter = containerClient.listBlobsByHierarchy("/", { prefix: "iot-unifiededge-001/00/2020/06/28/23/0"});
            const blobs = [];
            for await (const item of iter) {
                console.log(`\tBlobItem: name - ${item.name}, last modified - ${item.properties.lastModified}`);
                const blob = await this.downloadBlob("detectoroutput", item.name);
                blobs.push(blob);
            }
            console.log(blobs);
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

        return views;
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