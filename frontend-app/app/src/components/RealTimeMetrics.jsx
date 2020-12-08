import React from 'react';
import { Label } from 'office-ui-fabric-react/lib/Label';
import { Text } from 'office-ui-fabric-react/lib/Text';

export class RealTimeMetrics extends React.Component {
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
            inside: 0, 
            outside: 0 ,
            totalInside: 0, 
            totalOutside: 0 
        };
        this.metrics = [];
    }

    componentDidMount() {
        setInterval(() => {
            // get metrics from last second
            
            // get metrics from last minute

        }, 1000);
    }

    componentDidUpdate(prevProps) {
        if (this.props.metrics !== prevProps.metrics) {
            this.metrics.push({
                inside: this.props.metrics.inside,
                outside: this.props.metrics.outside,
                date: new Date()   
            });
        }
    }

    render() {
        const names = this.props.aggregator.zones.map((zone, index) => {
            return (
                <span key={index}>{index > 0 ? ', ' : null}{zone.name}</span>
            )
        });
        return (
            <React.Fragment>
                <div
                    style={{
                        margin: 10
                    }}
                >
                    <div>
                        <Label style={{fontWeight: 'bold'}}>Real time metrics</Label>
                    </div>
                    <Text variant={'medium'} block>
                        People detected
                    </Text>
                    <Text variant={'medium'} block>
                        <b>{this.state.inside + this.state.outside}</b>
                    </Text>
                    <Text variant={'medium'} block>
                        People detected inside
                    </Text>
                    <Text variant={'medium'} block>
                        <b>{this.state.inside}</b>
                    </Text>
                    <Text variant={'medium'} block>
                        People detected outside
                    </Text>
                    <Text variant={'medium'} block>
                        <b>{this.state.outside}</b>
                    </Text>
                    
                    <Text variant={'medium'} block>
                        People detected in last 60 seconds
                    </Text>
                    <Text variant={'medium'} block>
                        <b>{this.state.totalInside + this.state.totalOutside}</b>
                    </Text>
                    <Text variant={'medium'} block>
                        People detected inside in last 60 seconds
                    </Text>
                    <Text variant={'medium'} block>
                        <b>{this.state.totalInside}</b>
                    </Text>
                    <Text variant={'medium'} block>
                        People detected outside in last 60 seconds
                    </Text>
                    <Text variant={'medium'} block>
                        <b>{this.state.totalOutside}</b>
                    </Text>
                </div>
            </React.Fragment>
        );
    }
}