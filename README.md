
### Setting Up Kafka in AWS

1. **Create a Custom MSK Cluster Using the AWS UI**
   - Create cluster in private subnet
   - Provision a cluster with the following specifications:
     - Kafka version: 3.7.x
     - Storage: 50 GB
     - Broker size: t3.small 
     - Deploy across 3 availability zones with 1 broker per zone
     - Utilizes custom configurations within a VPC, with private subnets in 3 AZs and public access disabled
     - A new security group created
     - SASL/SCRAM authentication enabled
     - Data encrypted at rest using AWS-managed keys
     - Add Basic monitoring set up, including broker log delivery to Amazon CloudWatch Logs
     - Add Cluster tags 

2. **Enable Auto Scaling for Storage**
   - After cluster creation, edit the cluster properties to enable auto-scaling for storage.

3. **Create Users in AWS Secrets Manager**
   - Create a minimum of 3 users (select "Other type of secret") with key/value pairs as follows. Secret names should start with `AmazonMSK_*`:
     ```json
     {
         "username": "test-kafka-Admin",
         "password": "XXXXXX"
     }
     {
         "username": "test-kafka-producer",
         "password": "XXXXXX"
     }
     {
         "username": "test-kafka-consumer",
         "password": "XXXXXX"
     }
     ```
   - These credentials will be shared with applications for producing and consuming, while the Admin user is intended for Kafka administration only.

4. **Edit MSK Cluster and Associate Secrets**
   - Edit the MSK cluster to add the above 3 users from AWS Secrets Manager.

5. **Update MSK Security Group**
   - Modify the MSK security group to grant inbound access control list (ACL) from the specified source.

### For local machines, download right version form here : https://downloads.apache.org/kafka/

export KAFKA_HEAP_OPTS="-Xmx1G -Xms1G" export KAFKA_OPTS="$KAFKA_OPTS -Djava.security.manager=allow -Dadmin.request.timeout.ms=30000"

6. **Login to Bastion/Jump Server**
   - Using the Admin user, perform the following:
     - Run the script: `setup_kafka_topics.sh`
     - Create a file named `client.properties` and update with admin credentials:
       ```properties
       security.protocol=SASL_SSL
       sasl.mechanism=SCRAM-SHA-512
       sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="XXXXX" password="XXXXXX";
       ```

7. **Create a Topic**
   - Use the following command to create a topic:
     ```bash
     ./kafka_2.13-3.7.1/bin/kafka-topics.sh --create --topic topicName --bootstrap-server your_broker_address:port --partitions 2 --replication-factor 1 --command-config client.properties
     ```

8. **Grant ACL for Producer and Consumer Users**

  - ** Grant Admin access  ALL fro Admin user :
   ```
   sh bin/kafka-acls.sh --add \
  --allow-principal User:username \
  --operation All \
  --topic opn-dev-invoice-topic \
  --bootstrap-server your_broker_address:port \
  --command-config config/client.properties
   ```
   - **Producer ACL:**
     ```bash
     ./kafka_2.13-3.7.1/bin/kafka-acls.sh --add --allow-principal User:username --operation Write --topic topicName --bootstrap-server your_broker_address:port --command-config client.properties
     ```
   - **Consumer ACL:**
     ```bash
     ./kafka_2.13-3.7.1/bin/kafka-acls.sh --add --allow-principal User:username --operation Read --topic topicName --bootstrap-server your_broker_address:port --command-config client.properties
     ```

   - **To Remove an ACL:**
     ```bash
     ./kafka_2.13-3.7.1/bin/kafka-acls.sh --remove --allow-principal User:username --operation operation --topic your_topic_name --bootstrap-server your_broker_address:port --command-config client.properties
     ```

### Producer and Consumer Configurations

- **Producer Config:**
  ```properties
  bootstrap.servers=your_broker_address:port
  key.serializer=org.apache.kafka.common.serialization.StringSerializer
  value.serializer=org.apache.kafka.common.serialization.StringSerializer
  security.protocol=SASL_SSL
  sasl.mechanism=SCRAM-SHA-512
  sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="xxxx" password="xxxx";
  ```

- **Consumer Config:**
  ```properties
  bootstrap.servers=your_broker_address:port
  key.serializer=org.apache.kafka.common.serialization.StringSerializer
  value.serializer=org.apache.kafka.common.serialization.StringSerializer
  security.protocol=SASL_SSL
  sasl.mechanism=SCRAM-SHA-512
  sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="xxxx" password="xxxx";
  group.id=group1  # This can be any name but must be fixed for consumers
  ```

### Useful Commands

- **Describe Topic:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-topics.sh --describe --topic test-data --bootstrap-server your_broker_address:port --command-config client.properties
  ```

- **List All Topics:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-topics.sh --list --bootstrap-server your_broker_address:port --command-config client.properties
  ```

- **Delete Kafka Topic:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-topics.sh --delete --topic your_topic_name --bootstrap-server your_broker_address:port --command-config client.properties
  ```

- **Check LAG:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-consumer-groups.sh --bootstrap-server your_broker_address:port --describe --group your_consumer_group --command-config client.properties
  ```

- **Get Latest Offset:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-run-class.sh kafka.tools.GetOffsetShell --broker-list your_broker_address:port --topic your_topic_name --time -1
  ```

- **Publish Messages:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-console-producer.sh --topic test-data --bootstrap-server your_broker_address:port --producer.config producer.properties
  ```

- **Consume Messages:**
  ```bash
  ./kafka_2.13-3.7.1/bin/kafka-console-consumer.sh --topic test-data --bootstrap-server your_broker_address:port --from-beginning --consumer.config consumer.properties
  ```