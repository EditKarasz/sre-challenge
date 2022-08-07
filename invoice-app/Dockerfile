FROM golang:1.18-alpine3.15

WORKDIR /build/
COPY . .
RUN apk add build-base
ENV PAYMENT_URL='http://payment-provider.payment-provider.svc.cluster.local:8082/payments/pay'
RUN GOOS=linux
RUN go build -o app .

## This is for testing
ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools

ENTRYPOINT ["./app"]
