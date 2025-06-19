FROM node:18

# Cài ffmpeg
RUN apt-get update && apt-get install -y ffmpeg

# Tạo thư mục làm việc
WORKDIR /app

# Copy toàn bộ project
COPY . .

# Cài thư viện Node.js
RUN npm install

# Mở cổng server
EXPOSE 3000

# Lệnh khởi chạy
CMD ["node", "server.js"]
