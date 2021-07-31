source ../../setenv.sh
#!/bin/bash
srcFolder=$1
keyStore=$1/$2
password=$3
alias=$4
outputFolder=$5

echo ${cyn}Generating CARoot.pem with:${end}
GENERATE_CAROOT="keytool -exportcert -alias $alias -keystore $keyStore -rfc -file $outputFolder/CARoot.pem -storepass $password"
echo ${grn}$GENERATE_CAROOT${end}
$GENERATE_CAROOT

echo ${cyn}Generating key.pem with keytool ...${end}
GENERATE_CERTIFICATE_AND_KEY="keytool -v -importkeystore -srckeystore $keyStore -srcalias $alias -destkeystore $outputFolder/cert_and_key.p12 -deststoretype PKCS12 -storepass $password -srcstorepass $password"
echo ${grn}$GENERATE_CERTIFICATE_AND_KEY${end}
$GENERATE_CERTIFICATE_AND_KEY
echo ${cyn}... and openssl${end}
GENERATE_KEY="openssl pkcs12 -in $outputFolder/cert_and_key.p12 -nodes -nocerts -out $outputFolder/key.pem -passin pass:$password"
echo ${grn}$GENERATE_KEY${end}
$GENERATE_KEY