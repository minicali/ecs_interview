package main

import (
    "encoding/json"
    "net/http"
    "time"
)

type Epoch struct {
    EpochTime int64 `json:"The current epoch time"`
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
    response := Epoch{
        EpochTime: time.Now().Unix(),
    }
    json.NewEncoder(w).Encode(response)
}

func main() {
    http.HandleFunc("/", handleRequest)
    http.ListenAndServe(":8080", nil)
}
