###########
# BUILDER #
###########

# pull official base image
FROM python:3.8.3-alpine as builder

# set work directory
RUN mkdir /usr/src/app
WORKDIR /usr/src/app

# set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# install psycopg2 dependencies
RUN apk update \
    && apk add postgresql-dev gcc python3-dev musl-dev \
    # install Pillow dependencies
    && apk add jpeg-dev zlib-dev libjpeg \
    # install Cryptography dependencies
    && apk add libressl-dev libffi-dev openssl-dev cargo

# lint
RUN pip install --upgrade pip
RUN pip install flake8
COPY . .

# install dependencies
COPY ./prod.requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r prod.requirements.txt


#########
# FINAL #
#########

# pull official base image
FROM python:3.8.3-alpine

# create directory for the app user
RUN mkdir -p /home/app

# create the app user
RUN addgroup -S app && adduser -S app -G app

# create the appropriate directories
ENV HOME=/home/app
ENV APP_HOME=/home/app/web
RUN mkdir $APP_HOME
RUN mkdir $APP_HOME/static
RUN mkdir $APP_HOME/media
WORKDIR $APP_HOME

# install Pillow dependencies
RUN apk update \
    && apk add --no-cache postgresql-dev gcc python3-dev musl-dev \
    && apk add --no-cache jpeg-dev zlib-dev \
    && apk add --no-cache libressl-dev libffi-dev openssl-dev cargo\
    && apk add --no-cache --virtual .build-deps build-base linux-headers

# install dependencies
RUN pip install --upgrade pip
RUN apk update && apk add libpq
COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/prod.requirements.txt .
RUN pip install --no-cache /wheels/*

# copy entrypoint-prod.sh
#COPY ./config/docker/entrypoint.local.sh ./config/docker/
#RUN sed -i 's/\r$//g' $APP_HOME/config/docker/entrypoint.prod.sh
#RUN chmod +x $APP_HOME/config/docker/entrypoint.prod.sh

# copy project
COPY . $APP_HOME

# chown all the files to the app user
RUN chown -R app:app $APP_HOME

# change to the app user
USER app

# run entrypoint.prod.sh
ENTRYPOINT ["/home/app/web/config/docker/entrypoint.prod.sh"]
