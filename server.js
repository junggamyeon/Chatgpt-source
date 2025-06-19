const express = require('express');
const multer = require('multer');
const { exec } = require('child_process');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 3000;

const upload = multer({ dest: 'uploads/' });
app.use(express.static('public'));

app.post('/api/render-video', upload.fields([
    { name: 'images', maxCount: 6 },
    { name: 'video', maxCount: 1 }
]), async (req, res) => {
    const layout = req.body.layout || '2x2';
    const videoFile = req.files['video'][0];
    const imageFiles = req.files['images'];
    const outputId = uuidv4();
    const compositePath = `output/${outputId}_composite.jpg`;
    const outputFile = `output/${outputId}.mp4`;

    let inputs = "";
    let layoutCmd = "";
    if (layout === "2x2" && imageFiles.length >= 4) {
        inputs = imageFiles.slice(0, 4).map(f => `-i ${f.path}`).join(' ');
        layoutCmd = '"[0:v][1:v][2:v][3:v]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[out]"';
    } else {
        return res.status(400).send("Layout hoặc ảnh không hợp lệ");
    }

    const imageLayoutCommand = `ffmpeg ${inputs} -filter_complex ${layoutCmd} -map "[out]" -y ${compositePath}`;
    const videoCommand = `ffmpeg -i ${compositePath} -i ${videoFile.path} -filter_complex "[0:v][1:v]overlay=0:0" -y ${outputFile}`;

    exec(imageLayoutCommand, (err) => {
        if (err) return res.status(500).send("Lỗi ghép ảnh");

        exec(videoCommand, (err2) => {
            if (err2) return res.status(500).send("Lỗi ghép video");
            res.download(outputFile);
        });
    });
});

app.listen(port, () => {
    console.log(`Photobooth server running at http://localhost:${port}`);
});
