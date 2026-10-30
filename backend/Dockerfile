FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      tesseract-ocr tesseract-ocr-ara tesseract-ocr-fra tesseract-ocr-eng \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY *.py ./

RUN useradd -m app && mkdir /data && chown app /data
USER app
ENV SOFYAN_DATA_DIR=/data
VOLUME /data
EXPOSE 8000

# التطبيق خلف Caddy فقط، لذلك نثق برؤوس X-Forwarded-* (لحدّ محاولات الدخول حسب IP).
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips=*"]
