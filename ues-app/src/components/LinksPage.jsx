import React from 'react';
import { PrimaryButton } from '@fluentui/react/lib/Button';
import { Stack } from 'office-ui-fabric-react/lib/Stack';
import 'office-ui-fabric-react/dist/css/fabric.css';

export class LinksPage extends React.Component {
    static defaultProps = {
        updateShowLinksPage: (e) => { }
    }

    constructor(props) {
        super(props);
        this.state = {

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
                            flexDirection: 'row'
                        }}
                    >
                        <Stack>
                            <PrimaryButton
                                style={{
                                    margin: 5
                                }}
                                onClick={(e) => {
                                    window.open('./deployment_bundle.zip');
                                }}
                            >
                                Download Deployment Bundle
                            </PrimaryButton>
                            <PrimaryButton
                                style={{
                                    margin: 5
                                }}
                                onClick={this.props.updateShowLinksPage}
                            >
                                Start App
                            </PrimaryButton>
                        </Stack>
                    </div>
                </div>
            </React.Fragment>
        );
    }
}