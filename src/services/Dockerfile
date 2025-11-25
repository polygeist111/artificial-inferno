FROM python:3.14-alpine

# add bash, ffmpeg
RUN apk update && apk upgrade && apk add --update bash && apk add --update ffmpeg

WORKDIR /app

COPY requirements.txt ./
RUN pip install -r requirements.txt

# comment the next 3 lines for base image
COPY ./manager /manager
RUN chmod +x /manager/botscript
ENV PATH="/manager:$PATH"

COPY ./src . 

# Expose Flask port
EXPOSE 5000

# comment this line for reloadable image
# CMD ["python3.14", "flask run --debug"]

# comment this line for base image
ENTRYPOINT [ "/manager/lifespan.sh" ]