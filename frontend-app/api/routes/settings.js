var express = require('express');
var router = express.Router();

/* GET settings. */
router.get('/', function (req, res, next) {
    const settings = {
        account: process.env.APPSETTING_STORAGE_BLOB_ACCOUNT ?? "",
        eventHub: process.env.CUSTOMCONNSTR_EventHub ?? "",
        containerName: process.env.APPSETTING_STORAGE_BLOB_CONTAINER_NAME ?? "",
        blobPath: process.env.APPSETTING_STORAGE_BLOB_PATH ?? "",
        sharedAccessSignature: process.env.APPSETTING_STORAGE_BLOB_SHARED_ACCESS_SIGNATURE ?? "",
        ampStreamingUrl: process.env.AMP_STREAMING_URL ?? ""
    };
    res.send(JSON.stringify(settings));
});

module.exports = router;