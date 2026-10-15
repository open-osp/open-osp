
## Description
 
The tool allows to update Java with specific tzdata (timezone data).

It compiles tzdata source information into files in binary format and puts these files into Java installation directory.

For Java 8, the source data is compiled into single file placed at <java.home>/lib/tzdb.dat.

For Java 7, the source data is compiled into multiple files placed at <java.home>/lib/zi folder.

## Usage examples

Print tzdata version in Java

```sh
$JAVA_HOME/bin/java -jar ziupdater.jar -V
ziupdater version 1.0.1.2
JRE tzdata version: 2016i
```

Install tzdata from provided bundle

```sh
$JAVA_HOME/bin/java -jar ziupdater.jar -l file://[path]/tzdata.tar.gz
```

## Known limitations
 
  * the only supported URL protocol: file://
  * no support for URL protocols: http://, https://
  * no support for automatic installs of latest IANA tzdata
  * no support for SHA-512 checks
  * no support for IANA tzdata vanguard format
  * upgrading to tzdata2018i or tzdata2019a may lead to various failures if version of Java does not include patch for [JDK-8224560](https://bugs.openjdk.java.net/browse/JDK-8224560).
    Make sure that this patch is included in version you use prior to upgrading.

## Licensing
 
This project is licensed under the terms of the GPLv2 with Classpath Exception

## Building notes

Building this tool requires Java 7 as JAVA_HOME as
it depends on some internal API (ZoneInfoFile) available in Java 7 but removed in Java 8

Use the following command to build it:

```sh
% mvn clean package
```

## Testing
 
Tests expect some environment variables to be set.

Use the following command to test:

```sh
export TEST_JAVA=[path]
export TEST_TZDATA=[path]/tzdata.tar.gz
export TEST_JAR=[path]/ziupdater.jar
mvn test
```

The tool will update TEST_JAVA. Be aware of it.

## Changelog

1.1.3.1

 * upgraded Commons-IO dependency from version 2.4 to version 2.18.0

1.1.2.1

 * this version supports tzdata2024b (with full month/day names)

1.1.1.1

 * added support for the vanguard format for Java 8 and higher

1.0.3.1

 * this version supports tzdata2020b (where obsolete file pacificnew was removed)

1.0.2.2

 * added support for Java 11

1.0.1.2

 * initial release
