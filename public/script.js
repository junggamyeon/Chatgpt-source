// Các biến toàn cục
const video = document.getElementById('video');
const canvas = document.getElementById('canvas');
const editCanvas = document.getElementById('editCanvas');
const countdownElement = document.getElementById('countdown');
const startBtn = document.getElementById('startBtn');
const retakeBtn = document.getElementById('retakeBtn');
const editBtn = document.getElementById('editBtn');
const downloadBtn = document.getElementById('downloadBtn');
const downloadVideoBtn = document.getElementById('downloadVideoBtn');
const closeEditBtn = document.getElementById('closeEditBtn');
const saveEditBtn = document.getElementById('saveEditBtn');
const clearStickersBtn = document.getElementById('clearStickersBtn');
const thumbnailsContainer = document.getElementById('thumbnails');
const thumbnailsEdit = document.getElementById('thumbnailsEdit');
const editPanel = document.getElementById('editPanel');
const editStickerContainer = document.getElementById('editStickerContainer');
const settingsPanel = document.getElementById('settingsPanel');
const cameraView = document.getElementById('cameraView');
const controls = document.getElementById('controls');
const confirmSettingsBtn = document.getElementById('confirmSettingsBtn');
const photoCountSelect = document.getElementById('photoCountSelect');
const countdownSlider = document.getElementById('countdownSlider');
const intervalSlider = document.getElementById('intervalSlider');
const countdownValue = document.getElementById('countdownValue');
const intervalValue = document.getElementById('intervalValue');
const imageFormatSelect = document.getElementById('imageFormatSelect');
const videoFormatSelect = document.getElementById('videoFormatSelect');
const qualitySlider = document.getElementById('qualitySlider');
const qualityValue = document.getElementById('qualityValue');
const spacingSlider = document.getElementById('spacingSlider');
const frameColorGroup = document.getElementById('frameColorGroup');

let photos = [];
let recordRTC;
let videoStream;
let countdownInterval;
let photoCount = 0;
let totalPhotos = 4;
let countdownDuration = 3;
let photoInterval = 4000;
let imageQuality = 0.9;
let currentFrameColor = '#FFFFFF';
let selectedPhotoIndex = 0;

// Sticker và frame hiện tại
let currentStickers = [];
let currentColor = '#FF6B6B';
let currentFrame = 'none';
let currentLayout = 'horizontal';
let currentSpacing = 10;

// Khởi động camera
async function initCamera() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ 
            video: { 
                facingMode: 'user',
                width: { ideal: 1280 },
                height: { ideal: 720 }
            }, 
            audio: false 
        });
        video.srcObject = stream;
        videoStream = stream;
        
    } catch (err) {
        console.error("Lỗi khi truy cập camera:", err);
        alert("Không thể truy cập camera. Vui lòng kiểm tra quyền truy cập.");
    }
}

// Xác nhận cài đặt
function confirmSettings() {
    totalPhotos = parseInt(photoCountSelect.value);
    countdownDuration = parseInt(countdownSlider.value);
    photoInterval = parseInt(intervalSlider.value) * 1000;
    
    settingsPanel.style.display = 'none';
    cameraView.style.display = 'block';
    controls.style.display = 'flex';
    
    initCamera();
}

// Bắt đầu quá trình photobooth
function startPhotobooth() {
    photos = [];
    thumbnailsContainer.innerHTML = '';
    startBtn.disabled = true;
    retakeBtn.disabled = false;
    editBtn.disabled = true;
    photoCount = 0;
    
    // Bắt đầu ghi video với RecordRTC
    const options = {
        type: 'video',
        mimeType: videoFormatSelect.value === 'mp4' ? 'video/mp4' : 'video/webm',
        bitsPerSecond: 2500000 // 2.5Mbps
    };
    recordRTC = RecordRTC(videoStream, options);
    recordRTC.startRecording();
    
    takeNextPhoto();
}

// Chụp ảnh tiếp theo
function takeNextPhoto() {
    if (photoCount >= totalPhotos) {
        finishPhotobooth();
        return;
    }
    
    photoCount++;
    startCountdown();
}

// Bắt đầu đếm ngược
function startCountdown() {
    let count = countdownDuration;
    countdownElement.textContent = count;
    countdownElement.style.display = 'block';
    
    countdownInterval = setInterval(() => {
        count--;
        countdownElement.textContent = count;
        
        if (count <= 0) {
            clearInterval(countdownInterval);
            countdownElement.style.display = 'none';
            capturePhoto();
            
            // Nếu chưa đủ số ảnh, tiếp tục chụp sau photoInterval
            if (photoCount < totalPhotos) {
                setTimeout(takeNextPhoto, photoInterval);
            }
        }
    }, 1000);
}

// Chụp ảnh
function capturePhoto() {
    const context = canvas.getContext('2d');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    context.drawImage(video, 0, 0, canvas.width, canvas.height);
    
    // Lưu ảnh vào mảng
    const photoUrl = canvas.toDataURL('image/png');
    photos.push({
        url: photoUrl,
        stickers: []
    });
    
    // Hiển thị thumbnail
    displayThumbnail(photoUrl, photoCount);
    
    // Cho phép chỉnh sửa khi có ít nhất 1 ảnh
    if (photos.length > 0) {
        editBtn.disabled = false;
    }
}

// Hiển thị thumbnail
function displayThumbnail(photoUrl, index) {
    const thumbnail = document.createElement('div');
    thumbnail.className = 'thumbnail';
    thumbnail.dataset.index = index - 1;
    
    const img = document.createElement('img');
    img.src = photoUrl;
    img.alt = `Ảnh ${index}`;
    
    const removeBtn = document.createElement('button');
    removeBtn.className = 'remove-btn';
    removeBtn.innerHTML = '&times;';
    removeBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        photos.splice(index - 1, 1);
        thumbnail.remove();
        updatePhotoIndexes();
        
        if (photos.length === 0) {
            editBtn.disabled = true;
        }
    });
    
    thumbnail.appendChild(img);
    thumbnail.appendChild(removeBtn);
    thumbnailsContainer.appendChild(thumbnail);
}

// Kết thúc photobooth
function finishPhotobooth() {
    // Dừng ghi video
    if (recordRTC) {
        recordRTC.stopRecording(function() {
            // Lưu video đã ghi
            const videoBlob = recordRTC.getBlob();
            const videoUrl = URL.createObjectURL(videoBlob);
            
            // Tạo video element để xem trước
            const videoPreview = document.createElement('video');
            videoPreview.controls = true;
            videoPreview.src = videoUrl;
            videoPreview.style.width = '100%';
            
            // Thêm vào thumbnail (tùy chọn)
            const thumbnail = document.createElement('div');
            thumbnail.className = 'thumbnail';
            thumbnail.appendChild(videoPreview);
            thumbnailsContainer.appendChild(thumbnail);
        });
    }
    
    startBtn.disabled = false;
}

// Mở panel chỉnh sửa
function openEditPanel() {
    editPanel.classList.add('active');
    renderEditThumbnails();
    renderEditPreview();
}

// Đóng panel chỉnh sửa
function closeEditPanel() {
    editPanel.classList.remove('active');
    editStickerContainer.innerHTML = '';
}

// Hiển thị thumbnails để chọn ảnh chỉnh sửa
function renderEditThumbnails() {
    thumbnailsEdit.innerHTML = '';
    
    photos.forEach((photo, index) => {
        const thumbnail = document.createElement('div');
        thumbnail.className = `thumbnail ${index === selectedPhotoIndex ? 'active' : ''}`;
        thumbnail.dataset.index = index;
        
        const img = document.createElement('img');
        img.src = photo.url;
        img.alt = `Ảnh ${index + 1}`;
        
        thumbnail.appendChild(img);
        thumbnail.addEventListener('click', () => {
            selectedPhotoIndex = index;
            renderEditThumbnails();
            renderEditPreview();
        });
        
        thumbnailsEdit.appendChild(thumbnail);
    });
}

// Render preview chỉnh sửa
function renderEditPreview() {
    const ctx = editCanvas.getContext('2d');
    editStickerContainer.innerHTML = '';
    
    if (photos.length === 0) return;
    
    // Lấy kích thước của ảnh đầu tiên làm tham chiếu
    const firstPhoto = new Image();
    firstPhoto.onload = function() {
        const singleWidth = firstPhoto.width;
        const singleHeight = firstPhoto.height;
        
        let canvasWidth, canvasHeight;
        let cols = 1, rows = 1;
        
        switch(currentLayout) {
            case 'horizontal':
                cols = photos.length;
                rows = 1;
                canvasWidth = (singleWidth * cols) + (currentSpacing * (cols - 1));
                canvasHeight = singleHeight;
                break;
                
            case 'vertical':
                cols = 1;
                rows = photos.length;
                canvasWidth = singleWidth;
                canvasHeight = (singleHeight * rows) + (currentSpacing * (rows - 1));
                break;
                
            case '2x2':
                cols = 2;
                rows = 2;
                canvasWidth = (singleWidth * cols) + (currentSpacing * (cols - 1));
                canvasHeight = (singleHeight * rows) + (currentSpacing * (rows - 1));
                break;
        }
        
        // Thêm padding cho khung
        const framePadding = currentFrame === 'none' ? 0 : 20;
        editCanvas.width = canvasWidth + (framePadding * 2);
        editCanvas.height = canvasHeight + (framePadding * 2);
        
        // Vẽ nền trước (cho khung màu)
        if (currentFrame === 'none') {
            ctx.fillStyle = currentFrameColor;
            ctx.fillRect(0, 0, editCanvas.width, editCanvas.height);
        } else {
            // Vẽ khung ảnh
            drawFrame(ctx, editCanvas.width, editCanvas.height);
        }
        
        // Vẽ từng ảnh vào canvas
        photos.forEach((photo, index) => {
            const img = new Image();
            img.src = photo.url;
            
            img.onload = function() {
                let x, y;
                let col, row;
                
                switch(currentLayout) {
                    case 'horizontal':
                        col = index;
                        row = 0;
                        x = col * (singleWidth + currentSpacing) + framePadding;
                        y = framePadding;
                        break;
                        
                    case 'vertical':
                        col = 0;
                        row = index;
                        x = framePadding;
                        y = row * (singleHeight + currentSpacing) + framePadding;
                        break;
                        
                    case '2x2':
                        col = index % cols;
                        row = Math.floor(index / cols);
                        x = col * (singleWidth + currentSpacing) + framePadding;
                        y = row * (singleHeight + currentSpacing) + framePadding;
                        break;
                }
                
                // Vẽ ảnh
                ctx.drawImage(img, x, y, singleWidth, singleHeight);
                
                // Vẽ sticker nếu có
                photo.stickers.forEach((sticker, stickerIndex) => {
                    drawStickerOnCanvas(ctx, sticker, singleWidth, singleHeight, x, y);
                    
                    // Tạo sticker có thể kéo thả cho ảnh đang chọn
                    if (index === selectedPhotoIndex) {
                        createDraggableSticker(sticker, stickerIndex, singleWidth, singleHeight, x, y);
                    }
                });
            };
        });
    };
    firstPhoto.src = photos[0].url;
}

// Vẽ khung ảnh
function drawFrame(ctx, width, height) {
    ctx.save();
    
    switch(currentFrame) {
        case 'polaroid':
            ctx.fillStyle = '#f5f5f5';
            ctx.fillRect(0, 0, width, height);
            ctx.strokeStyle = '#ddd';
            ctx.lineWidth = 10;
            ctx.strokeRect(5, 5, width - 10, height - 10);
            break;
            
        case 'vintage':
            ctx.fillStyle = '#8B4513';
            ctx.fillRect(0, 0, width, height);
            ctx.fillStyle = '#000';
            ctx.fillRect(10, 10, width - 20, height - 20);
            break;
            
        case 'modern':
            ctx.fillStyle = '#fff';
            ctx.fillRect(0, 0, width, height);
            ctx.strokeStyle = '#FF6B6B';
            ctx.lineWidth = 15;
            ctx.strokeRect(0, 0, width, height);
            break;
            
        case 'wooden':
            ctx.fillStyle = '#8B4513';
            ctx.fillRect(0, 0, width, height);
            
            // Vẽ vân gỗ
            ctx.strokeStyle = '#A0522D';
            ctx.lineWidth = 2;
            for (let i = 0; i < height; i += 5) {
                ctx.beginPath();
                ctx.moveTo(0, i);
                ctx.lineTo(width, i);
                ctx.stroke();
            }
            break;
            
        case 'fancy':
            ctx.fillStyle = '#FFD700';
            ctx.fillRect(0, 0, width, height);
            ctx.fillStyle = '#fff';
            ctx.fillRect(10, 10, width - 20, height - 20);
            break;
    }
    
    ctx.restore();
}

// Vẽ sticker lên canvas
function drawStickerOnCanvas(ctx, sticker, imgWidth, imgHeight, offsetX = 0, offsetY = 0) {
    const size = Math.min(imgWidth, imgHeight) * 0.15;
    const x = offsetX + (imgWidth * sticker.x / 100) - size / 2;
    const y = offsetY + (imgHeight * sticker.y / 100) - size / 2;
    
    ctx.save();
    
    if (sticker.type === 'text') {
        // Sticker emoji
        ctx.font = `bold ${size}px Arial`;
        ctx.fillStyle = sticker.color || currentColor;
        ctx.fillText(sticker.content, x, y + size);
    } else {
        // Sticker icon
        ctx.font = `normal ${size}px FontAwesome`;
        ctx.fillStyle = sticker.color || currentColor;
        
        let iconCode;
        switch(sticker.type) {
            case 'heart': iconCode = '\uf004'; break;
            case 'star': iconCode = '\uf005'; break;
            case 'camera': iconCode = '\uf030'; break;
            case 'music': iconCode = '\uf001'; break;
            case 'cat': iconCode = '\uf6be'; break;
            case 'dog': iconCode = '\uf6d3'; break;
            default: iconCode = '\uf005';
        }
        
        ctx.fillText(iconCode, x, y + size);
    }
    
    ctx.restore();
}

// Tạo sticker có thể kéo thả
function createDraggableSticker(sticker, index, imgWidth, imgHeight, offsetX = 0, offsetY = 0) {
    const stickerElement = document.createElement('div');
    stickerElement.className = 'sticker';
    stickerElement.dataset.index = index;
    
    const size = Math.min(imgWidth, imgHeight) * 0.15;
    const left = offsetX + (imgWidth * sticker.x / 100) - size / 2;
    const top = offsetY + (imgHeight * sticker.y / 100) - size / 2;
    
    stickerElement.style.width = `${size}px`;
    stickerElement.style.height = `${size}px`;
    stickerElement.style.left = `${left}px`;
    stickerElement.style.top = `${top}px`;
    
    if (sticker.type === 'text') {
        stickerElement.textContent = sticker.content;
        stickerElement.style.fontSize = `${size}px`;
        stickerElement.style.color = sticker.color || currentColor;
        stickerElement.style.textAlign = 'center';
        stickerElement.style.lineHeight = `${size}px`;
    } else {
        const icon = document.createElement('i');
        let iconClass;
        switch(sticker.type) {
            case 'heart': iconClass = 'fa-heart'; break;
            case 'star': iconClass = 'fa-star'; break;
            case 'camera': iconClass = 'fa-camera'; break;
            case 'music': iconClass = 'fa-music'; break;
            case 'cat': iconClass = 'fa-cat'; break;
            case 'dog': iconClass = 'fa-dog'; break;
            default: iconClass = 'fa-star';
        }
        icon.className = `fas ${iconClass}`;
        icon.style.color = sticker.color || currentColor;
        icon.style.fontSize = `${size * 0.6}px`;
        stickerElement.appendChild(icon);
    }
    
    // Thêm khả năng kéo thả
    makeDraggable(stickerElement, index, imgWidth, imgHeight, offsetX, offsetY);
    
    editStickerContainer.appendChild(stickerElement);
}

// Tạo khả năng kéo thả cho sticker
function makeDraggable(element, stickerIndex, imgWidth, imgHeight, offsetX = 0, offsetY = 0) {
    let isDragging = false;
    let startX, startY, initialX, initialY;
    
    element.addEventListener('mousedown', startDrag);
    element.addEventListener('touchstart', startDrag, { passive: false });
    
    function startDrag(e) {
        isDragging = true;
        
        if (e.type === 'mousedown') {
            startX = e.clientX;
            startY = e.clientY;
        } else {
            e.preventDefault();
            startX = e.touches[0].clientX;
            startY = e.touches[0].clientY;
        }
        
        initialX = element.offsetLeft;
        initialY = element.offsetTop;
        
        document.addEventListener('mousemove', drag);
        document.addEventListener('touchmove', drag, { passive: false });
        document.addEventListener('mouseup', endDrag);
        document.addEventListener('touchend', endDrag);
    }
    
    function drag(e) {
        if (!isDragging) return;
        e.preventDefault();
        
        let clientX, clientY;
        if (e.type === 'mousemove') {
            clientX = e.clientX;
            clientY = e.clientY;
        } else {
            clientX = e.touches[0].clientX;
            clientY = e.touches[0].clientY;
        }
        
        const dx = clientX - startX;
        const dy = clientY - startY;
        
        let newLeft = initialX + dx;
        let newTop = initialY + dy;
        
        // Giới hạn trong phạm vi ảnh
        newLeft = Math.max(offsetX, Math.min(offsetX + imgWidth - element.offsetWidth, newLeft));
        newTop = Math.max(offsetY, Math.min(offsetY + imgHeight - element.offsetHeight, newTop));
        
        element.style.left = `${newLeft}px`;
        element.style.top = `${newTop}px`;
        
        // Cập nhật vị trí sticker trong mảng
        const selectedPhoto = photos[selectedPhotoIndex];
        if (selectedPhoto && selectedPhoto.stickers[stickerIndex]) {
            selectedPhoto.stickers[stickerIndex].x = ((newLeft - offsetX) + element.offsetWidth / 2) / imgWidth * 100;
            selectedPhoto.stickers[stickerIndex].y = ((newTop - offsetY) + element.offsetHeight / 2) / imgHeight * 100;
        }
    }
    
    function endDrag() {
        isDragging = false;
        document.removeEventListener('mousemove', drag);
        document.removeEventListener('touchmove', drag);
        document.removeEventListener('mouseup', endDrag);
        document.removeEventListener('touchend', endDrag);
        
        // Render lại preview sau khi kéo thả
        renderEditPreview();
    }
}

// Thêm sticker vào ảnh đang chọn
function addStickerToPhoto(type) {
    if (!photos.length) return;
    
    const selectedPhoto = photos[selectedPhotoIndex];
    
    const sticker = {
        type: type,
        x: 50, // Vị trí mặc định giữa ảnh
        y: 50,
        color: currentColor
    };
    
    selectedPhoto.stickers.push(sticker);
    renderEditPreview();
}

// Xóa tất cả sticker khỏi ảnh đang chọn
function clearStickers() {
    if (!photos.length) return;
    
    const selectedPhoto = photos[selectedPhotoIndex];
    selectedPhoto.stickers = [];
    renderEditPreview();
}

// Tải ảnh về
function downloadImage() {
    const format = imageFormatSelect.value;
    const quality = parseFloat(qualitySlider.value);
    
    let mimeType, fileName;
    if (format === 'jpeg') {
        mimeType = 'image/jpeg';
        fileName = `photobooth_${new Date().getTime()}.jpg`;
    } else {
        mimeType = 'image/png';
        fileName = `photobooth_${new Date().getTime()}.png`;
    }
    
    // Tạo canvas tổng hợp nếu có nhiều ảnh
    const finalCanvas = document.createElement('canvas');
    const finalCtx = finalCanvas.getContext('2d');
    
    if (photos.length > 1) {
        // Tính toán kích thước canvas dựa trên bố cục
        const firstPhoto = new Image();
        firstPhoto.onload = function() {
            const singleWidth = firstPhoto.width;
            const singleHeight = firstPhoto.height;
            
            let canvasWidth, canvasHeight;
            let cols = 1, rows = 1;
            
            switch(currentLayout) {
                case 'horizontal':
                    cols = photos.length;
                    rows = 1;
                    canvasWidth = (singleWidth * cols) + (currentSpacing * (cols - 1));
                    canvasHeight = singleHeight;
                    break;
                    
                case 'vertical':
                    cols = 1;
                    rows = photos.length;
                    canvasWidth = singleWidth;
                    canvasHeight = (singleHeight * rows) + (currentSpacing * (rows - 1));
                    break;
                    
                case '2x2':
                    cols = 2;
                    rows = 2;
                    canvasWidth = (singleWidth * cols) + (currentSpacing * (cols - 1));
                    canvasHeight = (singleHeight * rows) + (currentSpacing * (rows - 1));
                    break;
            }
            
            // Thêm padding cho khung
            const framePadding = currentFrame === 'none' ? 0 : 20;
            finalCanvas.width = canvasWidth + (framePadding * 2);
            finalCanvas.height = canvasHeight + (framePadding * 2);
            
            // Vẽ nền trước (cho khung màu)
            if (currentFrame === 'none') {
                finalCtx.fillStyle = currentFrameColor;
                finalCtx.fillRect(0, 0, finalCanvas.width, finalCanvas.height);
            } else {
                // Vẽ khung ảnh
                drawFrame(finalCtx, finalCanvas.width, finalCanvas.height);
            }
            
            // Vẽ từng ảnh vào canvas
            photos.forEach((photo, index) => {
                const img = new Image();
                img.src = photo.url;
                
                img.onload = function() {
                    let x, y;
                    let col, row;
                    
                    switch(currentLayout) {
                        case 'horizontal':
                            col = index;
                            row = 0;
                            x = col * (singleWidth + currentSpacing) + framePadding;
                            y = framePadding;
                            break;
                            
                        case 'vertical':
                            col = 0;
                            row = index;
                            x = framePadding;
                            y = row * (singleHeight + currentSpacing) + framePadding;
                            break;
                            
                        case '2x2':
                            col = index % cols;
                            row = Math.floor(index / cols);
                            x = col * (singleWidth + currentSpacing) + framePadding;
                            y = row * (singleHeight + currentSpacing) + framePadding;
                            break;
                    }
                    
                    // Vẽ ảnh
                    finalCtx.drawImage(img, x, y, singleWidth, singleHeight);
                    
                    // Vẽ sticker nếu có
                    photo.stickers.forEach(sticker => {
                        drawStickerOnCanvas(finalCtx, sticker, singleWidth, singleHeight, x, y);
                    });
                    
                    // Nếu là ảnh cuối cùng, tạo link tải về
                    if (index === photos.length - 1) {
                        const link = document.createElement('a');
                        link.download = fileName;
                        link.href = finalCanvas.toDataURL(mimeType, quality);
                        link.click();
                    }
                };
            });
        };
        firstPhoto.src = photos[0].url;
    } else {
        // Nếu chỉ có 1 ảnh, tải về trực tiếp
        const link = document.createElement('a');
        link.download = fileName;
        link.href = editCanvas.toDataURL(mimeType, quality);
        link.click();
    }
}

// Tải video về
function downloadVideo() {
    if (!recordRTC) {
        alert('Không có video để tải về. Vui lòng chụp ít nhất một ảnh trước.');
        return;
    }
    
    // Tạo video element từ dữ liệu đã ghi
    const videoBlob = recordRTC.getBlob();
    const videoUrl = URL.createObjectURL(videoBlob);
    const videoElement = document.createElement('video');
    
    videoElement.onloadedmetadata = function() {
        // Tạo canvas để ghép video theo bố cục
        const comboCanvas = document.createElement('canvas');
        const comboCtx = comboCanvas.getContext('2d');
        
        const singleWidth = videoElement.videoWidth;
        const singleHeight = videoElement.videoHeight;
        
        let canvasWidth, canvasHeight;
        let cols = 1, rows = 1;
        
        switch(currentLayout) {
            case 'horizontal':
                cols = totalPhotos;
                rows = 1;
                canvasWidth = (singleWidth * cols) + (currentSpacing * (cols - 1));
                canvasHeight = singleHeight;
                break;
                
            case 'vertical':
                cols = 1;
                rows = totalPhotos;
                canvasWidth = singleWidth;
                canvasHeight = (singleHeight * rows) + (currentSpacing * (rows - 1));
                break;
                
            case '2x2':
                cols = 2;
                rows = 2;
                canvasWidth = (singleWidth * cols) + (currentSpacing * (cols - 1));
                canvasHeight = (singleHeight * rows) + (currentSpacing * (rows - 1));
                break;
        }
        
        // Thêm padding cho khung
        const framePadding = currentFrame === 'none' ? 0 : 20;
        comboCanvas.width = canvasWidth + (framePadding * 2);
        comboCanvas.height = canvasHeight + (framePadding * 2);
        
        // Ghi video vào canvas
        const stream = comboCanvas.captureStream(30);
        const mediaRecorder = new MediaRecorder(stream, {
            mimeType: videoFormatSelect.value === 'mp4' ? 'video/mp4' : 'video/webm',
            bitsPerSecond: 2500000
        });
        
        const chunks = [];
        mediaRecorder.ondataavailable = function(e) {
            chunks.push(e.data);
        };
        
        mediaRecorder.onstop = function() {
            const finalBlob = new Blob(chunks, {
                type: videoFormatSelect.value === 'mp4' ? 'video/mp4' : 'video/webm'
            });
            
            const link = document.createElement('a');
            link.href = URL.createObjectURL(finalBlob);
            link.download = `photobooth_video_${new Date().getTime()}.${videoFormatSelect.value}`;
            link.click();

            downloadVideoBtn.textContent = "🎥 Tải video";
            downloadVideoBtn.disabled = false;
        };
        
        mediaRecorder.start();
        
        // Vẽ từng khung hình
        function drawVideoFrame() {
            // Vẽ nền
            if (currentFrame === 'none') {
                comboCtx.fillStyle = currentFrameColor;
                comboCtx.fillRect(0, 0, comboCanvas.width, comboCanvas.height);
            } else {
                drawFrame(comboCtx, comboCanvas.width, comboCanvas.height);
            }
            
            // Vẽ các video con theo bố cục
            for (let i = 0; i < totalPhotos; i++) {
                let x, y;
                let col, row;
                
                switch(currentLayout) {
                    case 'horizontal':
                        col = i;
                        row = 0;
                        x = col * (singleWidth + currentSpacing) + framePadding;
                        y = framePadding;
                        break;
                        
                    case 'vertical':
                        col = 0;
                        row = i;
                        x = framePadding;
                        y = row * (singleHeight + currentSpacing) + framePadding;
                        break;
                        
                    case '2x2':
                        col = i % cols;
                        row = Math.floor(i / cols);
                        x = col * (singleWidth + currentSpacing) + framePadding;
                        y = row * (singleHeight + currentSpacing) + framePadding;
                        break;
                }
                
                comboCtx.drawImage(videoElement, x, y, singleWidth, singleHeight);
            }
            
            // Tiếp tục vẽ cho đến khi đủ thời lượng
            if (mediaRecorder.state === 'recording') {
                requestAnimationFrame(drawVideoFrame);
            }
        }
        
        // Bắt đầu vẽ
        videoElement.onloadeddata = function () {
            downloadVideoBtn.textContent = "🎥 Đang xử lý video...";
            downloadVideoBtn.disabled = true;

            const duration = videoElement.duration;
            videoElement.currentTime = 0;

            videoElement.ontimeupdate = function () {
                drawVideoFrame();

                if (videoElement.currentTime >= duration) {
                    mediaRecorder.stop();
                    videoElement.ontimeupdate = null;
                }
            };
        };
    };
    
    videoElement.src = videoUrl;
}

// Lưu thay đổi chỉnh sửa
function saveChanges() {
    renderEditPreview();
    closeEditPanel();
}

// Xử lý sự kiện tab
function setupTabs() {
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');
    
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const tabId = btn.dataset.tab;
            
            // Xóa active class từ tất cả các tab và nội dung
            tabBtns.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));
            
            // Thêm active class vào tab được chọn
            btn.classList.add('active');
            document.getElementById(tabId).classList.add('active');
        });
    });
}

// Cập nhật chỉ số ảnh sau khi xóa
function updatePhotoIndexes() {
    document.querySelectorAll('.thumbnail').forEach((thumb, index) => {
        thumb.dataset.index = index;
    });
}

// Xử lý sự kiện
confirmSettingsBtn.addEventListener('click', confirmSettings);
startBtn.addEventListener('click', startPhotobooth);
retakeBtn.addEventListener('click', () => {
    if (confirm('Bạn có chắc muốn chụp lại từ đầu? Tất cả ảnh đã chụp sẽ bị xóa.')) {
        photos = [];
        thumbnailsContainer.innerHTML = '';
        editBtn.disabled = true;
        retakeBtn.disabled = true;
        
        // Hủy ghi video nếu đang thực hiện
        if (recordRTC) {
            recordRTC.stopRecording();
            recordRTC = null;
        }
    }
});
editBtn.addEventListener('click', openEditPanel);
downloadBtn.addEventListener('click', downloadImage);
downloadVideoBtn.addEventListener('click', downloadVideo);
closeEditBtn.addEventListener('click', closeEditPanel);
saveEditBtn.addEventListener('click', saveChanges);
clearStickersBtn.addEventListener('click', clearStickers);

// Sự kiện chọn sticker
document.querySelectorAll('.sticker-option').forEach(option => {
    option.addEventListener('click', () => {
        const type = option.dataset.sticker;
        addStickerToPhoto(type);
    });
});

// Sự kiện chọn màu
document.querySelectorAll('.color-option').forEach(option => {
    option.addEventListener('click', () => {
        document.querySelectorAll('.color-option').forEach(opt => opt.classList.remove('active'));
        option.classList.add('active');
        currentColor = option.dataset.color;
    });
});

// Sự kiện chọn frame
document.querySelectorAll('.frame-option').forEach(option => {
    option.addEventListener('click', () => {
        document.querySelectorAll('.frame-option').forEach(opt => opt.classList.remove('active'));
        option.classList.add('active');
        currentFrame = option.dataset.frame;
        
        // Hiển thị/ẩn phần chọn màu khung
        frameColorGroup.style.display = currentFrame === 'none' ? 'block' : 'none';
        
        renderEditPreview();
    });
});

// Sự kiện chọn màu khung
document.querySelectorAll('[data-bgcolor]').forEach(option => {
    option.addEventListener('click', () => {
        document.querySelectorAll('[data-bgcolor]').forEach(opt => opt.classList.remove('active'));
        option.classList.add('active');
        currentFrameColor = option.dataset.bgcolor;
        renderEditPreview();
    });
});

// Sự kiện chọn layout
document.querySelectorAll('.layout-option').forEach(option => {
    option.addEventListener('click', () => {
        document.querySelectorAll('.layout-option').forEach(opt => opt.classList.remove('active'));
        option.classList.add('active');
        currentLayout = option.dataset.layout;
        renderEditPreview();
    });
});

// Sự kiện thay đổi slider
countdownSlider.addEventListener('input', () => {
    countdownValue.textContent = `${countdownSlider.value} giây`;
});

intervalSlider.addEventListener('input', () => {
    intervalValue.textContent = `${intervalSlider.value} giây`;
});

qualitySlider.addEventListener('input', () => {
    qualityValue.textContent = `${Math.round(qualitySlider.value * 100)}%`;
});

spacingSlider.addEventListener('input', () => {
    currentSpacing = parseInt(spacingSlider.value);
    renderEditPreview();
});

// Khởi động khi trang được tải
window.addEventListener('DOMContentLoaded', () => {
    setupTabs();
    
    // Kích hoạt tab đầu tiên
    document.querySelector('.tab-btn').click();
    document.querySelector('.color-option').click();
    document.querySelector('.frame-option[data-frame="none"]').click();
    document.querySelector('[data-bgcolor="#FFFFFF"]').click();
    document.querySelector('.layout-option[data-layout="horizontal"]').click();
    
    // Hiển thị panel cài đặt ban đầu
    settingsPanel.style.display = 'block';
    cameraView.style.display = 'none';
    controls.style.display = 'none';
    
    // Cập nhật giá trị slider ban đầu
    countdownValue.textContent = `${countdownSlider.value} giây`;
    intervalValue.textContent = `${intervalSlider.value} giây`;
    qualityValue.textContent = `${Math.round(qualitySlider.value * 100)}%`;
});

// Thêm hiệu ứng khi nhấn nút
document.querySelectorAll('.btn').forEach(btn => {
    btn.addEventListener('mousedown', () => {
        btn.style.transform = 'scale(0.95)';
    });
    
    btn.addEventListener('mouseup', () => {
        btn.style.transform = 'scale(1)';
    });
    
    btn.addEventListener('mouseleave', () => {
        btn.style.transform = 'scale(1)';
    });
});
downloadVideoBtn.addEventListener('click', async () => {
    if (!recordRTC || photos.length < 4) {
        alert("Bạn cần quay video và chụp ít nhất 4 ảnh!");
        return;
    }

    downloadVideoBtn.textContent = "🎞 Đang xử lý...";
    downloadVideoBtn.disabled = true;

    const formData = new FormData();

    // Gửi 4 ảnh đầu tiên
    photos.slice(0, 4).forEach((p, i) => {
        const blob = dataURLtoBlob(p.url);
        formData.append('images', blob, `photo${i}.jpg`);
    });

    // Gửi video đã quay
    formData.append('video', recordRTC.getBlob());
    formData.append('layout', '2x2');

    try {
        const response = await fetch('/api/render-video', {
            method: 'POST',
            body: formData
        });

        if (!response.ok) throw new Error("Lỗi từ server");

        const blob = await response.blob();
        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = 'photobooth_final.mp4';
        a.click();
    } catch (err) {
        alert("Lỗi khi xử lý video: " + err.message);
    } finally {
        downloadVideoBtn.textContent = "🎞 Tải video";
        downloadVideoBtn.disabled = false;
    }
});

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
