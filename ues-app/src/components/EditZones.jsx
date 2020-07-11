import React from 'react';
import { Label } from 'office-ui-fabric-react/lib/Label';
import { TextField } from 'office-ui-fabric-react/lib/TextField';
import { DefaultButton } from '@fluentui/react/lib/Button';

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
                        <table>
                            <tr>
                                <td>
                                    <TextField
                                        defaultValue={this.state.aggregator.zones[this.state.selectedZoneIndex].name}
                                        onChange={(e) => {
                                            this.state.aggregator.zones[this.state.selectedZoneIndex].name = e.target.value;
                                            this.props.updateAggregator(this.state.aggregator);
                                        }}
                                    />
                                </td>
                                <td>
                                    <DefaultButton
                                        onClick={(e) => {
                                            this.state.aggregator.zones[this.state.selectedZoneIndex].polygon = [];
                                            this.props.updateAggregator(this.state.aggregator);
                                        }}
                                    >
                                        Clear
                                    </DefaultButton>
                                </td>
                            </tr>
                        </table>
                    </form>
                </div>
            </React.Fragment>
        );
    }
}