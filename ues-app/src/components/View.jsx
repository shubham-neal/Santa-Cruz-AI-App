import React from 'react';

export class View extends React.Component {
    static defaultProps = {
        border: '2px solid black',
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
        image: new Image()
    }
    constructor(props) {
        super(props);
        this.state = {
            
        };
        this.canvasRef = React.createRef();
    }

    componentDidMount() {
        setInterval(() => {
            this.draw();
        }, 1000/this.props.fps);
    }

    render() {
        return (
            <React.Fragment>
                <div style={{
                    margin: 10,
                    textAlign: 'center',
                    border: this.props.border,
                    width: this.props.width,
                    height: this.props.height
                }}>
                    <canvas
                        ref={this.canvasRef}
                        width={this.props.width}
                        height={this.props.height}
                        tabIndex={1}
                    />
                </div>
            </React.Fragment>
        );
    }

    draw() {
        const canvasContext = this.canvasRef.current?.getContext("2d");
        if (canvasContext) {
            canvasContext.clearRect(0, 0, this.props.width, this.props.height);
            canvasContext.drawImage(this.props.image, 0, 0, this.props.width, this.props.height);
            this.drawZones(canvasContext, this.props.aggregator.zones);
            this.drawLines(canvasContext, this.props.aggregator.lines);
            this.drawDetections(canvasContext, this.props.frame.detections);
        }
    }

    drawLines(canvasContext, lines) {
        let l = lines.length;
        for (let i = 0; i < l; i++) {
            const line = lines[i];
            this.drawLine(canvasContext, line);
        }
    }

    drawLine(canvasContext, line) {
        canvasContext.strokeStyle = 'violet';
        canvasContext.lineWidth = 3;

        let l = line.length;
        for (let i = 0; i < l; i++) {
            const point = {
                x: this.props.width * line[i][0],
                y: this.props.height * line[i][1]
            };
            if (i === 0) {
                canvasContext.moveTo(point.x, point.y);
            } else {
                canvasContext.lineTo(point.x, point.y);
            }
        }
        canvasContext.closePath();
        canvasContext.stroke();
    }

    drawZones(canvasContext, zones) {
        let l = zones.length;
        for (let i = 0; i < l; i++) {
            const zone = zones[i];
            this.drawZone(canvasContext, zone);
        }
    }

    drawZone(canvasContext, zone) {
        canvasContext.strokeStyle = 'violet';
        canvasContext.lineWidth = 3;

        let l = zone.polygon.length;
        for (let i = 0; i < l; i++) {
            const point = {
                x: this.props.width * zone.polygon[i][0],
                y: this.props.height * zone.polygon[i][1]
            };
            if (i === 0) {
                canvasContext.beginPath();
                canvasContext.moveTo(point.x, point.y);
            } else {
                canvasContext.lineTo(point.x, point.y);
            }
        }
        canvasContext.closePath();
        canvasContext.stroke();
    }

    drawDetections(canvasContext, detections) {
        const l = detections.length;
        for (let i = 0; i < l; i++) {
            const detection = detections[i];
            this.drawDetection(canvasContext, detection);
        }
    }

    drawDetection(canvasContext, detection) {
        canvasContext.strokeStyle = 'yellow';
        canvasContext.lineWidth = 2;
        const x = this.props.width * detection.rectangle.left;
        const y = this.props.height * detection.rectangle.top;
        const w = this.props.width * detection.rectangle.width;
        const h = this.props.height * detection.rectangle.height;
        canvasContext.strokeRect(x, y, w, h);
    }
}