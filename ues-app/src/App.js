import React from 'react';
import './App.css';
import { View } from './components/View';
import { Edit } from './components/Edit';

const { BlobServiceClient } = require("@azure/storage-blob");

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
                    name: "queue",
                    polygon: [],//[[0.5, 0.25], [0.58, 0.25], [0.58, 0.5], [0.5, 0.5], [0.5, 0.25]],
                    threshold: 10.0
                }]
            },
            frame: {
                detections: []
            },
            image: new Image()
        }
        this.account = 'adlsunifiededgedev001';
        this.containerName = 'still-images';
        this.blobPath = 'Office/cam001';
        this.sharedAccessSignature = "?sv=2019-10-10&ss=bfqt&srt=sco&sp=rwdlacupx&se=2021-06-17T08:40:10Z&st=2020-06-17T00:40:10Z&spr=https&sig=rOA0RnsukPtfqNfqa7STBNtEG7LPwTP4aZcD2h0et%2B0%3D";
        this.blobServiceClient = new BlobServiceClient(`https://${this.account}.blob.core.windows.net?${this.sharedAccessSignature}`, this.defaultAzureCredential);
    }

    componentDidMount() {
        const url = 'ws://localhost:8080';
        const connection = new WebSocket(url);
        connection.onopen = () => {
            connection.send('Client connected...');
        }
        connection.onmessage = (e) => {
            const data = JSON.parse(e.data);
            if (data && data.hasOwnProperty('body')) {
                if (data.body.hasOwnProperty('detections')) {
                    this.setState({
                        frame: data.body
                    });
                }
                if (data.body.hasOwnProperty("image_name")) {
                    this.updateImage(data.body.image_name);
                }
            }
        }
        connection.onerror = (error) => {
            console.log(`WebSocket error: ${error}`);
        }
    }

    render() {
        return (
            <React.Fragment>
                <View
                    fps={this.state.fps}
                    width={this.state.width}
                    height={this.state.height}
                    aggregator={this.state.aggregator}
                    frame={this.state.frame}
                    image={this.state.image}
                />
                <Edit
                    fps={this.state.fps}
                    width={this.state.width}
                    height={this.state.height}
                    aggregator={this.state.aggregator}
                    updateAggregator={this.updateAggregator}
                />
            </React.Fragment>
        );
    }

    formatDate = (date) => {
        // Note: en-EN won't return in year-month-day order
        return date.toLocaleDateString('fr-CA', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        });
    }

    async updateImage(imageName) {
        const blobName = `${this.blobPath}/${imageName.split('T')[0]}/${imageName}.jpg`;
        const containerClient = this.blobServiceClient.getContainerClient(this.containerName);
        const blobClient = containerClient.getBlobClient(blobName);

        const downloadBlockBlobResponse = await blobClient.download();
        const downloaded = await this.blobToBinaryString(await downloadBlockBlobResponse.blobBody);
        const image = new Image();
        image.src = `data:image/jpeg;base64,${btoa(downloaded)}`;
        this.setState({
            image: image
        });
    }

    async blobToBinaryString(blob) {
        const fileReader = new FileReader();
        return new Promise((resolve, reject) => {
            fileReader.onloadend = (ev) => {
                resolve(ev.target.result);
            };
            fileReader.onerror = reject;
            fileReader.readAsBinaryString(blob);
        });
    }

    updateAggregator = (aggregator) => {
        this.setState({
            aggregator: aggregator
        });
    }
}

export default App;
