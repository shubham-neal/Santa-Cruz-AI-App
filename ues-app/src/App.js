import React from 'react';
import './App.css';
import { View } from './components/View';
import { Edit } from './components/Edit';

class App extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            aggregator: {
                lines: [],
                zones: [{
                    name: "queue",
                    polygon: [[0.5, 0.25], [0.58, 0.25], [0.58, 0.5], [0.5, 0.5], [0.5, 0.25]],
                    threshold: 10.0
                }]
            },
            fps: 30
        }
    }

    componentDidMount() {
        // const url = 'ws://localhost:8080';
        // const connection = new WebSocket(url);
        // connection.onopen = () => {
        //     connection.send('Client connecting...');
        // }
        // connection.onmessage = (e) => {
        //     const data = JSON.parse(e.data);
        //     if (data && data.hasOwnProperty('body') && data.body.hasOwnProperty('detections')) {

        //     }
        // }
        // connection.onerror = (error) => {
        //     console.log(`WebSocket error: ${error}`);
        // }
    }

    render() {
        return (
            <React.Fragment>
                <View
                    aggregator={this.state.aggregator} 
                    fps={this.fps}
                />
                {/* <Edit
                    aggregator={this.state.aggregator}
                    fps={this.fps}
                    handleUpdateAggregator={this.handleUpdateAggregator}
                /> */}
            </React.Fragment>
        );
    }

    handleUpdateAggregator = (aggregator) => {
        this.setState({
            aggregator: aggregator
        });
    }
}

export default App;
