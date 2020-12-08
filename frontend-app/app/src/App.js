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
import { Collision } from './models/Collision';
import { BlobImage } from './models/BlobImage';
import { initializeIcons } from 'office-ui-fabric-react/lib/Icons';

initializeIcons(/* optional base url */);

const collision = new Collision(false);
const blobImage = new BlobImage();

const { BlobServiceClient } = require("@azure/storage-blob");
const isAdmin = false;

let storageBlobAccount = null;
let storageBlobSharedAccessSignature = null;
let blobServiceClient = null;
let socket = null;
let socketUrl = null;

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
            selectedZoneIndex: 0,
            frame: {
                detections: []
            },
            frames: [],
            collisions: 0,
            detections: 0,
            metrics: {inside: 0, outside: 0 },
            ampStreamingUrl: null,
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
        if(process.env.NODE_ENV === 'development') {
            this.setup({
                ampStreamingUrl: process.env.REACT_APP_ampStreamingUrl,
                iotHubName: process.env.REACT_APP_iotHubName,
                storageBlobAccount: process.env.REACT_APP_storageBlobAccount,
                storageBlobSharedAccessSignature: process.env.REACT_APP_storageBlobSharedAccessSignature,
                socketUrl: process.env.REACT_APP_socketUrl
            });
        } else {
            axios.get(`./settings`)
                .then((response) => {
                    const data = response.data;
                    this.setup({
                        ...data,
                        socketUrl: window.location.host
                    });
                })
                .catch((e) => {
                    this.setup({
                        ampStreamingUrl: process.env.REACT_APP_amp_streaming_url,
                        iotHubName: process.env.REACT_APP_iotHubName,
                        storageBlobAccount: process.env.REACT_APP_storageBlobAccount,
                        storageBlobSharedAccessSignature: process.env.REACT_APP_storageBlobSharedAccessSignature,
                        socketUrl: process.env.REACT_APP_socketUrl,
                    });
                });
        }
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
                                selectedZoneIndex={this.state.selectedZoneIndex}
                                updateSelectedZoneIndex={this.updateSelectedZoneIndex}
                                frame={this.state.frame}
                                updateAggregator={this.updateAggregator}
                                collision={collision}
                                iotHubName={this.state.iotHubName}
                                ampStreamingUrl={this.state.ampStreamingUrl}
                                blobServiceClient={blobServiceClient}
                                updateRealTimeMetrics={this.updateRealTimeMetrics}
                            />
                            {/* <Pivot
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
                            } */}
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
                                metrics={this.state.metrics}
                            />
                            {/* <AggregateStatsInTimeWindow
                                aggregator={this.state.aggregator}
                                isBBoxInZones={collision.isBBoxInZones}
                                iotHubName={this.state.iotHubName}
                                blobServiceClient={blobServiceClient}
                                updateAggregateChartMetrics={this.updateAggregateChartMetrics}
                            /> */}
                            {/* <EditZones
                                aggregator={this.state.aggregator}
                                selectedZoneIndex={this.state.selectedZoneIndex}
                                updateAggregator={this.updateAggregator}
                                updateSelectedZoneIndex={this.updateSelectedZoneIndex}
                            /> */}
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

    setup(data) {
        storageBlobAccount = data.storageBlobAccount;
        storageBlobSharedAccessSignature = data.storageBlobSharedAccessSignature;
        blobServiceClient = new BlobServiceClient(`https://${storageBlobAccount}.blob.core.windows.net?${storageBlobSharedAccessSignature}`);
        socketUrl = data.socketUrl;

        this.setState({
            ampStreamingUrl: data.ampStreamingUrl,
            iotHubName: data.iotHubName
        });

        // messages
        socket = io(`wss://${socketUrl}`, { transports: ['websocket'] });

        socket.on('connect', function () {
            console.log('connected!');
        });
        
        socket.on('passwordchecked', (message) => {
            const data = JSON.parse(message);
            if (data.success) {
                localStorage.setItem("UES-APP-PASSWORD", btoa(data.value));
                this.setState({
                    accessGranted: true
                });
            }
        });

        // password
        let password = "";
        const passwordEncoded = localStorage.getItem("UES-APP-PASSWORD") || "";
        if (passwordEncoded !== "") {
            const passwordDecoded = atob(passwordEncoded);
            this.checkPassword(passwordDecoded);
        } else {
            this.checkPassword("");
        }

        // aggregator
        // let aggregator = this.state.aggregator;
        // const aggregatorEncoded = localStorage.getItem("UES-APP-AGGREGATOR") || "";
        // if (aggregatorEncoded !== "") {
        //     const aggregatorDecoded = atob(aggregatorEncoded);
        //     aggregator = JSON.parse(aggregatorDecoded);
        //     this.setState({
        //         aggregator: aggregator
        //     });
        // }
    }

    updateRealTimeMetrics = (metrics) => {
        this.setState({
            metrics: metrics
        });
    }

    updateAggregateChartMetrics = (metrics) => {
        this.setState({
            aggregateChartMetrics: metrics
        });
    }

    updateAggregator = (aggregator) => {
        localStorage.setItem("UES-APP-AGGREGATOR", btoa(JSON.stringify(aggregator)));
        this.setState({
            aggregator: aggregator
        });
    }

    updateSelectedZoneIndex = (index) => {
        this.setState({
            selectedZoneIndex: index
        });
    }

    updatePassword = (e) => {
        const value = e.target.value;
        this.checkPassword(value);
    }

    checkPassword = (value) => {
        socket.emit("checkpassword", value);
    }
}

export default App;
