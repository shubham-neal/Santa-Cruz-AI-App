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
        }, 1000 / this.props.fps);
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

    isBBoxInZones(bbox, zones) {
        const l = zones.length;
        for (let i = 0; i < l; i++) {
            const zone = zones[i];
            if (this.isBBoxInZone(bbox, zone)) {
                return true;
            }
        }
        return false;
    }

    isBBoxInZone(bbox, zone) {
        const polygon = [];
        let l = zone.polygon.length;
        for (let i = 0; i < l; i++) {
            polygon.push({ x: zone.polygon[i][0], y: zone.polygon[i][1] });
        }
        l = bbox.length;
        for (let i = 1; i < l; i++) {
            const point = { x: bbox[0], y: bbox[1] };
            if (this.isPointInPolygon(point, polygon)) {
                return true;
            }
        }
        return false;
    }

    isPointInPolygon(p, polygon) {
        let isInside = false;
        let minX = polygon.x, maxX = polygon.x;
        let minY = polygon.y, maxY = polygon.y;
        for (let n = 1; n < polygon.length; n++) {
            const q = polygon[n];
            minX = Math.min(q.x, minX);
            maxX = Math.max(q.x, maxX);
            minY = Math.min(q.y, minY);
            maxY = Math.max(q.y, maxY);
        }

        if (p.x < minX || p.x > maxX || p.y < minY || p.y > maxY) {
            return false;
        }

        var i = 0, j = polygon.length - 1;
        for (i, j; i < polygon.length; j = i++) {
            if ((polygon[i].y > p.y) !== (polygon[j].y > p.y) &&
                p.x < (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x) {
                isInside = !isInside;
            }
        }

        return isInside;
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
        if (detection.bbox) {
            if(this.isBBoxInZones(detection.bbox, this.props.aggregator.zones)) {
                canvasContext.strokeStyle = 'yellow';
                canvasContext.lineWidth = 4;
            } else {
                canvasContext.strokeStyle = 'lightblue';
                canvasContext.lineWidth = 2;
            }
            const x = this.props.width * detection.bbox[0];
            const y = this.props.height * detection.bbox[1];
            const w = this.props.width * Math.abs(detection.bbox[2] - detection.bbox[0]);
            const h = this.props.height * Math.abs(detection.bbox[3] - detection.bbox[1]);
            canvasContext.strokeRect(x, y, w, h);
        } else if (detection.rectangle) {
            canvasContext.strokeStyle = 'yellow';
            canvasContext.lineWidth = 2;
            const x = this.props.width * detection.rectangle.left;
            const y = this.props.height * detection.rectangle.top;
            const w = this.props.width * detection.rectangle.width;
            const h = this.props.height * detection.rectangle.height;
            canvasContext.strokeRect(x, y, w, h);
        }
    }
}