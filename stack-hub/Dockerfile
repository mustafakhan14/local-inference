FROM python:3.11-alpine
WORKDIR /app
RUN apk add --no-cache nginx && pip install --no-cache-dir pyyaml
COPY app.py start.sh nginx.conf /app/
COPY static/ /app/static/
RUN chmod +x /app/start.sh && cp /app/nginx.conf /etc/nginx/nginx.conf
EXPOSE 3080 8780
CMD ["/app/start.sh"]
