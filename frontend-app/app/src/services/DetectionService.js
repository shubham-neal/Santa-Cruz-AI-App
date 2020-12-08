// real time - last 60 seconds
// aggregate - datetime begin to datetime end
export class DetectionService {
    constructor(blobServiceClient, iotHubName, containerName) {
        this.blobServiceClient = blobServiceClient;
        this.iotHubName = iotHubName;
        this.containerName = containerName;
    }

    getDetections(time, minutesBefore, minutesAfter) {
        const detections = [];
        const dates = this.calculateDateRange(time, minutesBefore, minutesAfter);
        for(const date in dates) {
            const inferences = this.getInferences(date);
            for(const inference in inferences) {
                detections.push(inference);
            }
        }
    }

    // TODO: account for daylight saving
    // TODO: optimize finding partition
    getInferences(date) {
        const inferences = [];

        let hours = date.getUTCHours();
        if(hours.length === 1) {
            hours = `0${hours}`;
        }
        let minutes = date.getUTCMinutes();
        if(minutes.length === 1) {
            minutes = `0${minutes}`;
        }
        let blobName = `${this.iotHubName}/0${this.findPartition()}/${date.toLocaleDateString('fr-CA', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit'
        }).replace(/-/g, '/')}/${hours}/${minutes}`;

        const exists = await this.blobExists(this.containerName, blobName);
        if(exists) {
            const containerClient = this.blobServiceClient.getContainerClient(this.containerName);
            let iter = containerClient.listBlobsByHierarchy("/", { prefix: blobName });
            for await (const item of iter) {
                const blobs = await this.downloadBlob(this.containerName, item.name);
                for (const blob in blobs) {
                    const inferences = blob.inferences;
                    for (const inference in inferences) {
                        inference.in = blob.in === 0 ? true : false;
                        inference.out = blob.out === 0 ? true: false;
                        inferences.push(inference);
                    }
                }
            }
        }

        return inferences;
    }


    calculateDateRange(time, minutesBefore, minutesAfter) {
        const dates = [];
        for(let i = -minutesBefore; i <= minutesAfter; i++) {
            const date = new Date(time);
            date.setMinutes(date.getMinutes() + i);
            dates.push(date);
        }
        return dates;
    }

    findPartition() {
        for (let i = 0; i < 4; i++) {
            const exists = await this.blobExists(`${this.iotHubName}/0${i}`);
            if (exists) {
                return i;
            }
        }
    }

    async blobExists(blobName) {
        const containerClient = this.blobServiceClient.getContainerClient(this.containerName);
        const blobClient = containerClient.getBlobClient(blobName);
        const exists = blobClient.exists();
        return exists;
    }
    
    async downloadBlob(containerName, blobName) {
        const containerClient = this.blobServiceClient.getContainerClient(containerName);
        const blobClient = containerClient.getBlobClient(blobName);
        const downloadBlockBlobResponse = await blobClient.download();

        const downloaded = await this.blobToString(await downloadBlockBlobResponse.blobBody);
        const views = downloaded.replace(/\\"/g, /'/).split('\r\n');

        const frames = [];
        const l = views.length;
        for (let i = 0; i < l; i++) {
            const view = views[i];
            if (view && view !== undefined && view !== "") {
                let parsedView = JSON.parse(view);
                if (parsedView.hasOwnProperty('Body')) {
                    let body = parsedView.Body;
                    if (body && body !== undefined && body !== "") {
                        let decodedBody = atob(body);
                        if (decodedBody && decodedBody !== undefined && decodedBody !== "") {
                            try {
                                let parsedBody = JSON.parse(decodedBody.replace(/bbox:/g, '"bbox:"'));
                                if (parsedBody && parsedBody !== undefined && parsedBody !== "") {
                                    if (parsedBody.hasOwnProperty('inferences')) {
                                        if (parsedBody.inferences.length > 0) {
                                            frames.push(parsedBody);
                                        }
                                    }
                                }
                            } catch (e) {
                                console.log(e);
                            }
                        }
                    }
                }
            }
        }

        return frames;
    }

    async blobToString(blob) {
        const fileReader = new FileReader();
        return new Promise((resolve, reject) => {
            fileReader.onloadend = (ev) => {
                resolve(ev.target.result);
            };
            fileReader.onerror = reject;
            fileReader.readAsText(blob);
        });
    }
}