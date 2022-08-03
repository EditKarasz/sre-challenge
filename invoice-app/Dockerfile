FROM golang:1.18-alpine3.15

WORKDIR /build/
COPY . .
RUN apk add build-base
ENV PAYMENT_URL='http://payment-provider.payment-provider.svc.cluster.local:8082/payments/pay'
RUN GOOS=linux
RUN go build -o app .

ENTRYPOINT ["./app"]
