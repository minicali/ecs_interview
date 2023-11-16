FROM golang:1.21-alpine as builder
WORKDIR /app
COPY ./go.*  ./
RUN go mod download
COPY ./main.go ./main.go
RUN CGO_ENABLED=0 GOOS=linux go build -o epoch-api .

FROM scratch
COPY --from=builder /app/epoch-api .
EXPOSE 8080
CMD ["./epoch-api"]
