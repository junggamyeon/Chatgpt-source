let recordRTC;
let photos = [];
let finalVideoBlob = null;

function log(msg) {
    console.log(msg);
    const box = document.getElementById('logBox');
    if (box) box.textContent += msg + "\n";
}

async function initCamera() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({
            video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 } },
            audio: false
        });
        document.getElementById('video').srcObject = stream;
    } catch (err) {
        alert("Không thể truy cập camera: " + err.message);
    }
}

function capturePhoto() {
    const video = document.getElementById('video');
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    const imgURL = canvas.toDataURL('image/jpeg');
    photos.push({ url: imgURL });
    const img = document.createElement('img');
    img.src = imgURL;
    img.width = 100;
    document.getElementById('photos').appendChild(img);
}

function startRecording() {
    const stream = document.getElementById('video').srcObject;
    recordRTC = new RecordRTC(stream, {
        type: 'video',
        mimeType: 'video/webm',
        bitsPerSecond: 2500000
    });
    recordRTC.startRecording();
    finalVideoBlob = null;
    document.getElementById('recordingStatus').textContent = '🔴 Đang ghi...';
}

function stopRecording() {
    recordRTC.stopRecording(() => {
        finalVideoBlob = recordRTC.getBlob();
        console.log("📹 Video đã lưu:", finalVideoBlob);
        document.getElementById('recordingStatus').textContent = '🟢 Đã ghi xong';
    });
}

function dataURLtoBlob(dataurl) {
    const arr = dataurl.split(',');
    const mime = arr[0].match(/:(.*?);/)[1];
    const bstr = atob(arr[1]);
    let n = bstr.length;
    const u8arr = new Uint8Array(n);
    while (n--) {
        u8arr[n] = bstr.charCodeAt(n);
    }
    return new Blob([u8arr], { type: mime });
}

async function downloadVideo() {
    const btn = document.getElementById('downloadVideoBtn');

    if (!finalVideoBlob || photos.length < 4) {
        alert("Bạn cần quay video và chụp ít nhất 4 ảnh!");
        return;
    }

    btn.disabled = true;
    btn.textContent = '🎞 Đang xử lý...';

    const formData = new FormData();

    photos.slice(0, 4).forEach((p, i) => {
        const blob = dataURLtoBlob(p.url);
        formData.append('images', blob, `photo${i}.jpg`);
    });

    formData.append('video', finalVideoBlob);
    formData.append('layout', '2x2');

    try {
        const response = await fetch('/api/render-video', {
            method: 'POST',
            body: formData
        });
        if (!response.ok) throw new Error("Lỗi từ server: " + response.statusText);
        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'photobooth_final.mp4';
        a.click();
    } catch (err) {
        alert("Lỗi khi gửi video lên server: " + err.message);
    } finally {
        btn.disabled = false;
        btn.textContent = '🎞 Tải video';
    }
}

window.onload = initCamera;

document.getElementById("downloadVideoBtn").addEventListener("click", downloadVideo);
