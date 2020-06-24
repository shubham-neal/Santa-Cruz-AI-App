import React from 'react';

export class Edit extends React.Component {
    static defaultProps = {
        border: '2px solid #ee82ee',
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
            selectedZoneIndex: 0,
            selectedPointIndex: -1,
            selectedPointRadius: 0.01
        };

        this.canvasRef = React.createRef();
        this.mousePos = { x: 0, y: 0 }
        this.mouseInside = false;
        this.dragging = false;
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
                        onKeyUp={this.handleKeyUp}
                        onClick={this.addPoint}
                        onMouseDown={(e) => this.dragging = true}
                        onMouseUp={(e) => this.dragging = false}
                        onMouseMove={(e) => { this.updateMousePos(e); this.movePoint(e); }}
                        onMouseOver={this.handleMouseOver}
                        onMouseOut={this.handleMouseOut}
                    />
                    {
                        this.props.aggregator.zones.map((zone, index) => {
                            return (
                                <div
                                    key={index}
                                    style={index === this.state.selectedZoneIndex ? {
                                        cursor: 'pointer',
                                        backgroundColor: '#ee82ee',
                                        color: 'white'
                                    } : {
                                            cursor: 'pointer',
                                            color: '#ee82ee'
                                        }}
                                    onClick={(e) => {
                                        this.setState({
                                            selectedZoneIndex: index,
                                            selectedPointIndex: -1
                                        })
                                    }}>
                                        {zone.name}
                                        {zone.threshold}
                                </div>
                            )
                        })
                    }
                </div>
            </React.Fragment>
        );
    }

    updateMousePos = (e) => {
        this.mousePos = { x: e.clientX, y: e.clientY };
    }

    handleMouseOver = (e) => {
        this.dragging = false;
        this.mouseInside = true;
        this.setState({
            selectedPointIndex: -1
        });
    }

    handleMouseOut = (e) => {
        this.dragging = false;
        this.mouseInside = false;
        this.setState({
            selectedPointIndex: -1
        });
    }

    handleKeyUp = (e) => {
        if (e.keyCode === 45) {
            this.insertPoint();
        } else if (e.keyCode === 46) {
            this.removePoint();
        }
    }

    addPoint = (e) => {
        if (this.canvasRef.current && this.state.selectedPointIndex === -1) {
            const rect = this.canvasRef.current?.getBoundingClientRect();
            const x = this.clamp((e.clientX - rect.left) / this.state.width, 0, 1);
            const y = this.clamp((e.clientY - rect.top) / this.state.height, 0, 1);
            this.state.zones[this.state.selectedZoneIndex].polygon.push([x, y]);
        }
    }

    insertPoint = () => {
        if (
            this.canvasRef.current &&
            this.state.selectedZoneIndex !== -1 &&
            this.state.selectedPointIndex !== -1 &&
            this.state.zones[this.state.selectedZoneIndex].polygon.length > 1
        ) {
            const point = this.state.zones[this.state.selectedZoneIndex].polygon[this.state.selectedPointIndex];

            this.state.zones[this.state.selectedZoneIndex].polygon.splice(this.state.selectedPointIndex, 0, [point[0], point[1]]);

            this.setState({
                selectedPointIndex: -1
            });
        }
    }

    movePoint = (e) => {
        if (
            this.dragging &&
            this.canvasRef.current &&
            this.state.selectedZoneIndex !== -1 &&
            this.state.selectedPointIndex !== -1 &&
            this.state.zones[this.state.selectedZoneIndex].polygon.length > this.state.selectedPointIndex
        ) {
            const rect = this.canvasRef.current?.getBoundingClientRect();
            const x = this.clamp((e.clientX - rect.left) / this.state.width, 0, 1);
            const y = this.clamp((e.clientY - rect.top) / this.state.height, 0, 1);
            // eslint-disable-next-line react/no-direct-mutation-state
            this.state.zones[this.state.selectedZoneIndex].polygon[this.state.selectedPointIndex] = [x, y];
        }
    }

    removePoint = () => {
        if (
            this.state.selectedZoneIndex !== -1 &&
            this.state.selectedPointIndex !== -1 &&
            this.state.zones[this.state.selectedZoneIndex].polygon.length > this.state.selectedPointIndex
        ) {
            this.state.zones[this.state.selectedZoneIndex].polygon.splice(this.state.selectedPointIndex, 1);
            this.setState({
                selectedPointIndex: -1
            });
        }
    }

    selectPoint = () => {
        if (this.canvasRef.current && this.state.selectedZoneIndex !== -1) {
            const rect = this.canvasRef.current?.getBoundingClientRect();
            const x = this.clamp((this.mousePos.x - rect.left) / this.state.width, 0, 1);
            const y = this.clamp((this.mousePos.y - rect.top) / this.state.height, 0, 1);
            const nearestPointIndex = this.findNearestPoint({ x: x, y: y });

            if (nearestPointIndex !== this.state.selectedPointIndex) {
                this.setState({
                    selectedPointIndex: nearestPointIndex
                });
            }
        }
    }

    clamp = (value, min, max) => {
        return Math.min(Math.max(value, min), max);
    }

    findNearestPoint = (point) => {
        let nearestPointIndex = -1;
        let nearestPointDistance = -1;
        const l = this.state.zones[this.state.selectedZoneIndex].polygon.length;
        for (let i = 0; i < l; i++) {
            const p = this.state.zones[this.state.selectedZoneIndex].polygon[i];
            const distance = Math.hypot(point.x - p[0], point.y - p[1]);
            if (distance <= nearestPointDistance || nearestPointDistance === -1) {
                nearestPointDistance = distance;
                nearestPointIndex = i;
            }
        }
        return nearestPointDistance < this.state.selectedPointRadius ? nearestPointIndex : -1;
    }

    draw = () => {
        setInterval(() => {
            const ctx = this.canvasRef.current?.getContext("2d");
            if (ctx) {
                ctx.clearRect(0, 0, this.state.width, this.state.height);
                this.drawZones(ctx);
                this.selectPoint();
                this.drawSelectedPoint(ctx);
            }
        }, 1000 / this.state.fps);
    }

    drawZones = (ctx) => {
        ctx.strokeStyle = 'violet';
        ctx.lineWidth = 3;

        const zl = this.state.zones.length;
        for (let z = 0; z < zl; z++) {
            const zone = this.state.zones[z];
            const pl = zone.polygon.length;
            for (let p = 0; p < pl; p++) {
                if (p > 0) {
                    const start = {
                        x: this.state.width * zone.polygon[p - 1][0],
                        y: this.state.height * zone.polygon[p - 1][1]
                    };
                    const end = {
                        x: this.state.width * zone.polygon[p][0],
                        y: this.state.height * zone.polygon[p][1]
                    };
                    ctx.setLineDash([]);
                    ctx.beginPath();
                    ctx.moveTo(start.x, start.y);
                    ctx.lineTo(end.x, end.y);
                    ctx.closePath();
                    ctx.stroke();
                }
            }
            if (pl > 2) {
                const first = {
                    x: this.state.width * zone.polygon[0][0],
                    y: this.state.height * zone.polygon[0][1]
                };
                const last = {
                    x: this.state.width * zone.polygon[pl - 1][0],
                    y: this.state.height * zone.polygon[pl - 1][1]
                };
                if (this.state.selectedZoneIndex === z && this.mouseInside) {
                    ctx.setLineDash([3, 5]);
                } else {
                    ctx.setLineDash([]);
                }
                ctx.beginPath();
                ctx.moveTo(last.x, last.y);
                ctx.lineTo(first.x, first.y);
                ctx.closePath();
                ctx.stroke();
            }
            if (this.state.selectedZoneIndex === z && this.mouseInside) {
                for (let p = 0; p < pl; p++) {
                    const point = {
                        x: this.state.width * zone.polygon[p][0],
                        y: this.state.height * zone.polygon[p][1]
                    };
                    ctx.setLineDash([]);
                    ctx.beginPath();
                    ctx.arc(point.x, point.y, 5, 0, 2 * Math.PI);
                    ctx.closePath();
                    ctx.stroke();
                }
            }
        }
    }

    drawSelectedPoint = (ctx) => {
        if (this.state.selectedZoneIndex !== -1 && this.state.selectedPointIndex !== -1) {
            ctx.strokeStyle = 'yellow';
            ctx.lineWidth = 3;

            const point = {
                x: this.state.width * this.state.zones[this.state.selectedZoneIndex].polygon[this.state.selectedPointIndex][0],
                y: this.state.height * this.state.zones[this.state.selectedZoneIndex].polygon[this.state.selectedPointIndex][1]
            };
            ctx.beginPath();
            ctx.arc(point.x, point.y, 5, 0, 2 * Math.PI);
            ctx.stroke();
        }
    }
}
