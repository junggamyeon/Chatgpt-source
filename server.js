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
    // Kiểm tra dữ liệu gửi lên
    if (!req.files || !req.files['video'] || !req.files['images'] || req.files['images'].length < 4) {
        console.log('Lỗi: thiếu video hoặc không đủ ảnh.');
        return res.status(400).send("Thiếu video hoặc không đủ ảnh (cần ít nhất 4)");
    }

    console.log('📦 Đã nhận files:', Object.keys(req.files));

    const videoFile = req.files['video'][0];
    const imageFiles = req.files['images'];
    const outputId = uuidv4();
    const compositePath = `output/${outputId}_composite.jpg`;
    const outputFile = `output/${outputId}.mp4`;

    let inputs = imageFiles.slice(0, 4).map(f => `-i ${f.path}`).join(' ');
    let layoutCmd = '"[0:v][1:v][2:v][3:v]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0[out]"';

    const imageLayoutCommand = `ffmpeg ${inputs} -filter_complex ${layoutCmd} -map "[out]" -y ${compositePath}`;
    const videoCommand = `ffmpeg -i ${compositePath} -i ${videoFile.path} -filter_complex "[0:v][1:v]overlay=0:0" -y ${outputFile}`;

    exec(imageLayoutCommand, (err) => {
        if (err) {
            console.error("Lỗi khi ghép ảnh:", err);
            return res.status(500).send("Lỗi khi ghép ảnh.");
        }

        exec(videoCommand, (err2) => {
            if (err2) {
                console.error("Lỗi khi ghép video:", err2);
                return res.status(500).send("Lỗi khi ghép video.");
            }

            res.download(outputFile, () => {
                // Xóa file tạm sau khi gửi
                fs.unlinkSync(outputFile);
                fs.unlinkSync(compositePath);
                imageFiles.forEach(f => fs.unlinkSync(f.path));
                fs.unlinkSync(videoFile.path);
            });
        });
    });
});

app.listen(port, () => {
    console.log(`Photobooth server running at http://localhost:${port}`);
});
