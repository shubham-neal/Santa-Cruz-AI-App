import React from 'react';

export class Password extends React.Component {
    static defaultProps = {
        updatePassword: () => { }
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
                            <input type="text" placeholder="Enter password" onChange={this.props.updatePassword} />
                        </div>
                    </div>
                </div>
            </React.Fragment>
        );
    }
}