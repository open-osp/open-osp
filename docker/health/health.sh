#!/bin/sh

ping -c 1 faxws
ping -c 1 expedius
ping -c 1 db
ping -c 1 oscar

curl -Ik -u faxws:abc123 https://faxws/faxWs
#HTTP/1.1 404 Not Found
#Server: Apache-Coyote/1.1
#Cache-Control: private
#Expires: Thu, 01 Jan 1970 00:00:00 GMT
#Allow: DELETE,POST,GET,PUT,OPTIONS,HEAD
#Date: Wed, 20 May 2020 06:46:09 GMT
#Content-Length: 0

# create bash script to check for HTTP Status code if 404 and Allow contains DELETE, POST, etc.
# if not OK, exit 1

curl -Ik http://expedius:8081/Expedius/
#HTTP/1.1 200 OK
#Server: Apache-Coyote/1.1
#Set-Cookie: JSESSIONID=E9239BC9439A32A9F6AB6E3BB19BED4E; Path=/Expedius; HttpOnly
#Content-Type: text/html;charset=ISO-8859-1
#Content-Length: 3870
#Date: Wed, 20 May 2020 06:49:10 GMT

# create bash script to check for HTTP Status code if OK
# if not OK, exit 1

# add another curl for drugref

curl -Ik http://oscar:8080/oscar/ws/LabUploadService


curl -Ik https://oscar:443/oscar/ws/LabUploadService

# curl -Ik http://oscar:8080/drugref
# verify if HTTP is 200
# if not OK, exit 1
