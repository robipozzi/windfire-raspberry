from kafka import KafkaProducer
from colorama import init, Fore, Back, Style
import os
import sys
import json

# ***** Initializes Colorama
init(autoreset=True)

# ***** Declare variables
kafkaBrokers = None
producer = None
topic = None
caRootLocation='tls/CARoot.pem'
password='password'

# ***** Get environment variables
kafkaBrokers = os.getenv('KAFKA_BROKER')
SSL = os.getenv('SSL')
topic = os.getenv('TOPIC')

# ***** Program execution
if __name__ == '__main__':
    # ***** Initialize Kafka producer
    if (kafkaBrokers == None) :
        print(Style.BRIGHT + 'No KAFKA_BROKER environment variable set, exiting ... ')
        sys.exit();
    if (SSL == None) | (SSL == "false"):
        print(Style.BRIGHT + 'Connecting to Kafka Broker without SSL')
        producer = KafkaProducer(bootstrap_servers=kafkaBrokers, value_serializer=lambda v: json.dumps(v).encode('utf-8'))
    else:
        print(Style.BRIGHT + 'Connecting to Kafka Broker with SSL')
        producer = KafkaProducer(bootstrap_servers=kafkaBrokers, value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                                security_protocol='SSL',
                                ssl_check_hostname=False,
                                ssl_cafile=caRootLocation,
                                ssl_password=password)
    # ***** Write messages to Kafka topic
    print(Style.BRIGHT + 'Writing message to topic : ' + Fore.GREEN + topic)
    producer.send(topic, {'temperature': '25','humidity':'25%'})
    producer.flush()