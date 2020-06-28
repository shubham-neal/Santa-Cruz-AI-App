import React from 'react';

export class Dashboard extends React.Component {
    static defaultProps = {
        width: 300,
        height: 300,
        fps: 30,
        aggregator: {
            lines: [],
            zones: []
        },
        frame: {
            detections: []
        },
        image: new Image(),
        chartData: {
            labels: [],
            datasets: []
        },
        updateAggregator: (aggregator) => {}
    }

    constructor(props) {
        super(props);
        this.state = {
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
            chartData: {
                labels: [],
                datasets: []
            }
        }
    }

    componentDidMount() {

    }

    componentDidUpdate() {

    }

    render() {
        return (
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
                                fps={this.props.fps}
                                width={this.props.width}
                                height={this.props.height}
                                aggregator={this.props.aggregator}
                                frame={this.props.frame}
                                image={this.props.image}
                                updateAggregator={this.props.updateAggregator}
                            />
                            <div
                                style={{
                                    width: this.state.width,
                                    height: this.state.height,
                                    padding: 10
                                }}
                            >
                                <Line redraw
                                    data={this.props.chartData}
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
                                <b>{this.props.detections}</b>
                            </div>
                            <div>
                                People detections in <b>{this.props.aggregator.zones[0].name}</b>:
                            </div>
                            <div>
                                <b>{this.props.collisions}</b>
                            </div>
                            <div>
                                Max people detections in frame per second:
                            </div>
                            <div>
                                <b>{this.props.maxDetectionsPerSecond}</b>
                            </div>
                            <div>
                                Max people detections in <b>{this.props.aggregator.zones[0].name}</b> per second:
                            </div>
                            <div>
                                <b>{this.props.maxCollisionsPerSecond}</b>
                            </div>
                            <div>
                                Total max people detections in frame per second:
                            </div>
                            <div>
                                <b>{this.props.totalDetections}</b>
                            </div>
                            <div>
                                Total max people detections in <b>{this.props.aggregator.zones[0].name}</b> per second:
                            </div>
                            <div>
                                <b>{this.props.totalCollisions}</b>
                            </div>
                        </div>
                    </div>
                </div>
            </React.Fragment>
        );
    }
}