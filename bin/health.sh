#!/bin/sh

curl -Ik -u faxws:abc123 https://localhost:8084/faxWs
#HTTP/1.1 404 Not Found
#Server: Apache-Coyote/1.1
#Cache-Control: private
#Expires: Thu, 01 Jan 1970 00:00:00 GMT
#Allow: DELETE,POST,GET,PUT,OPTIONS,HEAD
#Date: Wed, 20 May 2020 06:46:09 GMT
#Content-Length: 0

curl -Ik localhost:8081/Expedius/
#HTTP/1.1 200 OK
#Server: Apache-Coyote/1.1
#Set-Cookie: JSESSIONID=E9239BC9439A32A9F6AB6E3BB19BED4E; Path=/Expedius; HttpOnly
#Content-Type: text/html;charset=ISO-8859-1
#Content-Length: 3870
#Date: Wed, 20 May 2020 06:49:10 GMT
