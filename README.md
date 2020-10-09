# curl / BoringSSL crash reproducer

tldr: Run `./repro.sh` (requires Docker).

Reproducer for a crash in `curl` when using BoringSSL as the TLS
implementation.

BoringSSL @ `a673d0245` (2020-08-26).

Curl @ `1101fbbf4` (2020-10-07).

Also tested with BoringSSL @ chromium-stable (`430a742`), and the latest
official release of `curl` (v`7.72.0`).

System:

```bash
$ uname -a
Linux nickt 5.4.0-48-generic #52-Ubuntu SMP Thu Sep 10 10:58:49 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
```

Testing with regular OpenSSL (1.1.1h) works fine.

## Background

A client (`curl`) issues an HTTP CONNECT to an intermediary proxy over a TLS
connection (I'm using Envoy @ `v1.16.0`). The proxy's next hop is a backend
exposing a second TLS endpoint.

I'm invoking curl as follows:

```bash
$ curl \
  -v \
  -x https://localhost:4433 \
  --proxy-cacert /etc/tls/ca.pem \
  --cacert /etc/tls/ca.pem \
  https://localhost:4444
```

The first handshake (`curl` -> proxy) succeeds. Upon initiation of the second
handshake (`curl` -> backend), occurring inside the CONNECT tunnel, I can
reliably reproduce the following crash:

```console
Program terminated with signal SIGSEGV, Segmentation fault.
#0  0x000055a7c9811692 in BIO_get_retry_flags (bio=0x0) at /build/boringssl/crypto/bio/bio.c:280
280     /build/boringssl/crypto/bio/bio.c: No such file or directory.
(gdb) bt
#0  0x000055a7c9811692 in BIO_get_retry_flags (bio=0x0) at /build/boringssl/crypto/bio/bio.c:280
#1  0x000055a7c9811706 in BIO_copy_next_retry (bio=0x55a7ca03a3c8) at /build/boringssl/crypto/bio/bio.c:292
#2  0x000055a7c97b293e in ssl_ctrl (bio=0x55a7ca03a3c8, cmd=11, num=0, ptr=0x0) at /build/boringssl/ssl/bio_ssl.cc:122
#3  0x000055a7c9811495 in BIO_ctrl (bio=0x55a7ca03a3c8, cmd=11, larg=0, parg=0x0) at /build/boringssl/crypto/bio/bio.c:212
#4  0x000055a7c981140c in BIO_flush (bio=0x55a7ca03a3c8) at /build/boringssl/crypto/bio/bio.c:199
#5  0x000055a7c97fa343 in bssl::tls_flush_flight (ssl=0x55a7ca039668) at /build/boringssl/ssl/s3_both.cc:339
#6  0x000055a7c97ee409 in bssl::ssl_run_handshake (hs=0x55a7ca01efc8, out_early_return=0x7fffa15637f3) at /build/boringssl/ssl/handshake.cc:561
#7  0x000055a7c97ba698 in SSL_do_handshake (ssl=0x55a7ca039668) at /build/boringssl/ssl/ssl_lib.cc:889
#8  0x000055a7c97ba73f in SSL_connect (ssl=0x55a7ca039668) at /build/boringssl/ssl/ssl_lib.cc:911
#9  0x000055a7c97aeac1 in ossl_connect_step2 (conn=0x55a7ca000608, sockindex=0) at vtls/openssl.c:3212
#10 0x000055a7c97b0ec6 in ossl_connect_common (conn=0x55a7ca000608, sockindex=0, nonblocking=true, done=0x7fffa1563bb5) at vtls/openssl.c:4025
#11 0x000055a7c97b0ffa in Curl_ossl_connect_nonblocking (conn=0x55a7ca000608, sockindex=0, done=0x7fffa1563bb5) at vtls/openssl.c:4059
#12 0x000055a7c978b7a5 in Curl_ssl_connect_nonblocking (conn=0x55a7ca000608, sockindex=0, done=0x7fffa1563bb5) at vtls/vtls.c:334
#13 0x000055a7c97406a6 in https_connecting (conn=0x55a7ca000608, done=0x7fffa1563bb5) at http.c:1497
#14 0x000055a7c97404ca in Curl_http_connect (conn=0x55a7ca000608, done=0x7fffa1563bb5) at http.c:1424
#15 0x000055a7c9757185 in multi_runsingle (multi=0x55a7ca000278, nowp=0x7fffa1563d00, data=0x55a7ca0015d8) at multi.c:1941
#16 0x000055a7c9758616 in curl_multi_perform (multi=0x55a7ca000278, running_handles=0x7fffa1563d54) at multi.c:2559
#17 0x000055a7c9731771 in easy_transfer (multi=0x55a7ca000278) at easy.c:592
#18 0x000055a7c973199a in easy_perform (data=0x55a7ca0015d8, events=false) at easy.c:682
#19 0x000055a7c97319e4 in curl_easy_perform (data=0x55a7ca0015d8) at easy.c:701
#20 0x000055a7c9726dda in serial_transfers (global=0x7fffa1563f70, share=0x55a7c9ffcc38) at tool_operate.c:2322
#21 0x000055a7c9727271 in run_all_transfers (global=0x7fffa1563f70, share=0x55a7c9ffcc38, result=CURLE_OK) at tool_operate.c:2500
#22 0x000055a7c972758d in operate (global=0x7fffa1563f70, argc=11, argv=0x7fffa15640d8) at tool_operate.c:2616
#23 0x000055a7c971d594 in main (argc=11, argv=0x7fffa15640d8) at tool_main.c:323
```

## Reproducer

Assuming one has access to Docker, run the following:

```bash
$ ./repro.sh
```

This will drop you into a shell inside the container running `curl` where you can reproduce the crash:

```console
root@nickt:/# ./run_curl.sh
* STATE: INIT => CONNECT handle 0x556f911205d8; line 1796 (connection #-5000)
* Added connection 0. The cache now contains 1 members
* STATE: CONNECT => WAITRESOLVE handle 0x556f911205d8; line 1842 (connection #0)
* family0 == v4, family1 == v6
*   Trying 127.0.0.1:4433...
* STATE: WAITRESOLVE => WAITCONNECT handle 0x556f911205d8; line 1924 (connection #0)
* Connected to localhost (127.0.0.1) port 4433 (#0)
* STATE: WAITCONNECT => WAITPROXYCONNECT handle 0x556f911205d8; line 1981 (connection #0)
* Marked for [keep alive]: HTTP default
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/tls/ca.pem
*  CApath: none
* TLSv1.2 (OUT), TLS handshake, Client hello (1):
* TLSv1.2 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server did not agree to a protocol
* Proxy certificate:
*  subject: O=mkcert development certificate; OU=mkcert@85df1eb77880
*  start date: Jun  1 00:00:00 2019 GMT
*  expire date: Oct  9 00:21:16 2030 GMT
*  subjectAltName: host "localhost" matched cert's "localhost"
*  issuer: O=mkcert development CA; OU=mkcert@956f2db3d752; CN=mkcert mkcert@956f2db3d752
*  SSL certificate verify ok.
* allocate connect buffer!
* Establish HTTP proxy tunnel to localhost:4444
> CONNECT localhost:4444 HTTP/1.1
> Host: localhost:4444
> User-Agent: curl/7.73.0-DEV
> Proxy-Connection: Keep-Alive
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
< HTTP/1.1 200 OK
< date: Fri, 09 Oct 2020 00:22:15 GMT
< server: envoy
<
* Proxy replied 200 to CONNECT request
* CONNECT phase completed!
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/tls/ca.pem
*  CApath: none
* SSL re-using session ID
* TLSv1.2 (OUT), TLS handshake, Client hello (1):
Segmentation fault (core dumped)
```

Building against openssl 1.1.1h I can reach the backend:

```console
root@nickt:/# ./run_curl.sh
*   Trying 127.0.0.1...
* TCP_NODELAY set
* Expire in 200 ms for 4 (transfer 0x559e6abea890)
* Connected to localhost (127.0.0.1) port 4433 (#0)
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/tls/ca.pem
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
* ALPN, server did not agree to a protocol
* Proxy certificate:
*  subject: O=mkcert development certificate; OU=mkcert@4e0118f2f05d
*  start date: Jun  1 00:00:00 2019 GMT
*  expire date: Oct  9 00:32:46 2030 GMT
*  subjectAltName: host "localhost" matched cert's "localhost"
*  issuer: O=mkcert development CA; OU=mkcert@f3f6c039a3d6; CN=mkcert mkcert@f3f6c039a3d6
*  SSL certificate verify ok.
* allocate connect buffer!
* Establish HTTP proxy tunnel to localhost:4444
> CONNECT localhost:4444 HTTP/1.1
> Host: localhost:4444
> User-Agent: curl/7.73.0-DEV
> Proxy-Connection: Keep-Alive
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
< HTTP/1.1 200 OK
< date: Fri, 09 Oct 2020 00:55:02 GMT
< server: envoy
<
* Proxy replied 200 to CONNECT request
* CONNECT phase completed!
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/tls/ca.pem
  CApath: /etc/ssl/certs
* SSL re-using session ID
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* CONNECT phase completed!
* CONNECT phase completed!
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.3 (IN), TLS handshake, Encrypted Extensions (8):
* TLSv1.3 (IN), TLS handshake, Certificate (11):
* TLSv1.3 (IN), TLS handshake, CERT verify (15):
* TLSv1.3 (IN), TLS handshake, Finished (20):
* TLSv1.3 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.3 (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
* ALPN, server accepted to use h2
* Server certificate:
*  subject: O=mkcert development certificate; OU=mkcert@4347a757a723
*  start date: Jun  1 00:00:00 2019 GMT
*  expire date: Oct  9 00:32:47 2030 GMT
*  subjectAltName: host "localhost" matched cert's "localhost"
*  issuer: O=mkcert development CA; OU=mkcert@f3f6c039a3d6; CN=mkcert mkcert@f3f6c039a3d6
*  SSL certificate verify ok.
* Using HTTP2, server supports multi-use
* Connection state changed (HTTP/2 confirmed)
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* Using Stream ID: 1 (easy handle 0x559e6abea890)
> GET / HTTP/2
> Host: localhost:4444
> User-Agent: curl/7.73.0-DEV
> Accept: */*
>
* TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
* old SSL session ID is stale, removing
* Connection state changed (MAX_CONCURRENT_STREAMS == 250)!
< HTTP/2 200
< content-type: text/plain; charset=utf-8
< content-length: 14
< date: Fri, 09 Oct 2020 00:55:02 GMT
<
Hello, world!
* Connection #0 to host localhost left intact
```
