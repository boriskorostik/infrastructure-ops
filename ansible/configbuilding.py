import cv2
import time
import logging
from flask import Flask, Response

RTSP_URL = "rtsp://admin:RIUPZT@89.113.8.238:554/Streaming/channels/101"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

app = Flask(__name__)
def gen_frames():
    while True:
        logging.info("Попытка подключения к RTSP...")
        cap = cv2.VideoCapture(RTSP_URL, cv2.CAP_FFMPEG)

        if not cap.isOpened():
            logging.error("RTSP поток недоступен, повтор через 5 секунд")
            time.sleep(5)
            continue

        logging.info("RTSP поток открыт")

        while True:
            ret, frame = cap.read()
            if not ret:
                logging.warning("Поток оборвался")
                break

            ok, jpeg = cv2.imencode('.jpg', frame)
            if not ok:
                continue

            yield (
                b'--frame\r\n'
                b'Content-Type: image/jpeg\r\n\r\n' +
                jpeg.tobytes() +
                b'\r\n'
            )

        cap.release()
        time.sleep(2)

@app.route('/')
def video_feed():
    return Response(
        gen_frames(),
        mimetype='multipart/x-mixed-replace; boundary=frame'
    )

if __name__ == '__main__':
    logging.info("Запуск Flask MJPEG сервера")
    app.run(host='0.0.0.0', port=8000, threaded=True)
