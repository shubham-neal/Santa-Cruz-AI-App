import React from 'react';

export class View extends React.Component {
    static defaultProps = {
        border: '2px solid black',
        width: 300,
        height: 300,
        aggregator: {
            lines: [],
            zones: []
        },
        frame: {
            detections: []
        },
        fps: 30
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
        return this.props.frame ? (
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
        ) : null;
    }

    draw() {
        const ctx = this.canvasRef.current?.getContext("2d");
        if (ctx) {
            ctx.clearRect(0, 0, this.state.width, this.state.height);
            this.drawZones(ctx, this.props.aggregator.zones);
            this.drawLines(ctx, this.props.aggregator.lines);
            this.drawDetections(ctx, this.props.frame.detections);
        }
    }

    drawLines(ctx, lines) {
        let l = lines.length;
        for (let i = 0; i < l; i++) {
            const line = lines[i];
            this.drawLine(ctx, line);
        }
    }

    drawLine(ctx, line) {
        ctx.strokeStyle = 'violet';
        ctx.lineWidth = 3;

        let l = line.length;
        for (let i = 0; i < l; i++) {
            const point = {
                x: this.props.width * line[i][0],
                y: this.props.height * line[i][1]
            };
            if (i === 0) {
                ctx.moveTo(point.x, point.y);
            } else {
                ctx.lineTo(point.x, point.y);
            }
        }
        ctx.closePath();
        ctx.stroke();
    }

    drawZones(ctx, zones) {
        let l = zones.length;
        for (let i = 0; i < l; i++) {
            const zone = zones[i];
            this.drawZone(ctx, zone);
        }
    }

    drawZone(ctx, zone) {
        ctx.strokeStyle = 'violet';
        ctx.lineWidth = 3;

        let l = zone.polygon.length;
        for (let i = 0; i < l; i++) {
            const point = {
                x: this.props.width * zone.polygon[i][0],
                y: this.props.height * zone.polygon[i][1]
            };
            if (i === 0) {
                ctx.moveTo(point.x, point.y);
            } else {
                ctx.lineTo(point.x, point.y);
            }
        }
        ctx.closePath();
        ctx.stroke();
    }

    drawDetections(ctx, detections) {
        const l = detections.length;
        for (let i = 0; i < l; i++) {
            const detection = detections[i];
            this.drawDetection(ctx, detection);
        }
    }

    drawDetection(ctx, detection) {
        ctx.strokeStyle = 'yellow';
        ctx.lineWidth = 2;
        const x = this.state.width * detection.rectangle.left;
        const y = this.state.height * detection.rectangle.top;
        const w = this.state.width * detection.rectangle.width;
        const h = this.state.height * detection.rectangle.height;
        ctx.strokeRect(x, y, w, h);
    }
}