import React from 'react';
import { Label } from 'office-ui-fabric-react/lib/Label';
import { TextField } from 'office-ui-fabric-react/lib/TextField';

export class EditZones extends React.Component {
    static defaultProps = {
        aggregator: {
            lines: [],
            zones: []
        }
    }

    constructor(props) {
        super(props);
        this.state = {
            aggregator: JSON.parse(JSON.stringify(this.props.aggregator)),
            selectedZoneIndex: 0
        }
    }

    componentDidUpdate(prevProps) {
        if (prevProps.aggregator !== this.props.aggregator) {
            this.setState({
                aggregator: this.props.aggregator
            })
        }
    }

    render() {
        return (
            <React.Fragment>
                <div
                    style={{
                        margin: 10
                    }}
                >
                    <div>
                        <Label style={{ fontWeight: 'bold' }}>Zones</Label>
                    </div>
                    <form>
                        <TextField
                            defaultValue={this.state.aggregator.zones[this.state.selectedZoneIndex].name}
                            onChange={(e) => {
                                this.state.aggregator.zones[this.state.selectedZoneIndex].name = e.target.value;
                            }}
                        />
                    </form>
                </div>
            </React.Fragment>
        );
    }
}