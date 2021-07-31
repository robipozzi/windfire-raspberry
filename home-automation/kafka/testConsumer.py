from kafka import KafkaConsumer
from colorama import init, Fore, Back, Style
import os
import sys
import json

# ***** Initializes Colorama
init(autoreset=True)

# ***** Declare variables
kafkaBrokers = None
consumer = None
topic = None
caRootLocation='tls/CARoot.pem'
password='password'

# ***** Get environment variables
kafkaBrokers = os.getenv('KAFKA_BROKER')
SSL = os.getenv('SSL')
topic = os.getenv('TOPIC')

# ***** Program execution
if __name__ == '__main__':
    # ***** Initialize Kafka consumer
    if (kafkaBrokers == None) :
        print(Style.BRIGHT + 'No KAFKA_BROKER environment variable set, exiting ... ')
        sys.exit();
    if (SSL == None) | (SSL == "false"):
        print(Style.BRIGHT + 'Connecting to Kafka Broker without SSL')
        consumer = KafkaConsumer(topic, bootstrap_servers=kafkaBrokers, value_deserializer=lambda m: json.loads(m.decode('ascii')))
    else:
        consumer = KafkaConsumer(topic, bootstrap_servers=kafkaBrokers, value_deserializer=lambda m: json.loads(m.decode('ascii')),
                                security_protocol='SSL',
                                ssl_check_hostname=False,
                                ssl_cafile=caRootLocation,
                                ssl_password=password)
    # ***** Read messages from Kafka topic
    print(Style.BRIGHT + 'Reading messages from topic : ' + Fore.GREEN + topic)
    for message in consumer:
        # message value and key are raw bytes -- decode if necessary!
        # e.g., for unicode: `message.value.decode('utf-8')`
        print(message)
        print(Style.BRIGHT + "topic=%s partition=%d offeset=%d: key=%s value=%s" % (message.topic,message.partition,message.offset,message.key,message.value))