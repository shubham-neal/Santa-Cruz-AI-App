import React from 'react';

export class CountOfPeopleVsTime extends React.Component {
    static defaultProps = {
        aggregator: {
            lines: [],
            zones: []
        },
        frame: {
            detections: []
        },
        collisions: 0,
        detections: 0
    }

    constructor(props) {
        super(props);
        this.state = {
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
        setInterval(() => {
            const maxCollisionsPerSecond = this.state.maxCollisionsPerSecond;
            const maxDetectionsPerSecond = this.state.maxDetectionsPerSecond;

            // track per second
            this.state.maxPerSecond.times.push(new Date().toLocaleTimeString('it-IT'));
            this.state.maxPerSecond.collisions.push(maxCollisionsPerSecond);
            this.state.maxPerSecond.detections.push(maxDetectionsPerSecond);
            if (this.state.maxPerSecond.times.length > 10) {
                this.state.maxPerSecond.times.shift();
                this.state.maxPerSecond.collisions.shift();
                this.state.maxPerSecond.detections.shift();
            }

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
                        Real time metrics
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
}