import React from 'react';

export class LinksPage extends React.Component {
    static defaultProps = {
        updateShowLinksPage: (e) => {}
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
                            <input 
                                type="button" 
                                value="Download Deployment Bundle"
                                onClick={(e) => {
                                    window.open('./deployment_bundle.zip');
                                }}
                            /><br/>
                            <input 
                                type="button" 
                                value="Start App"
                                onClick={this.props.updateShowLinksPage}
                            />
                        </div>
                    </div>
                </div>
            </React.Fragment>
        );
    }
}