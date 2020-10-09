package main

import (
	"flag"
	"log"
	"net/http"
)

func main() {
	var (
		addr string
		cert string
		key  string
	)
	flag.StringVar(&addr, "addr", "", "")
	flag.StringVar(&cert, "cert", "", "")
	flag.StringVar(&key, "key", "", "")
	flag.Parse()

	http.HandleFunc("/", func(writer http.ResponseWriter, request *http.Request) {
		log.Printf("handing request: %+v", request)
		_, err := writer.Write([]byte("Hello, world!\n"))
		if err != nil {
			log.Fatal(err)
		}
		writer.WriteHeader(200)
	})
	if err := http.ListenAndServeTLS(addr, cert, key, nil); err != nil {
		log.Fatal(err)
	}
}
