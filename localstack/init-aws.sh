#!/bin/sh

echo "⏳ Waiting for LocalStack..."

until aws --endpoint-url=http://localstack:4566 sqs list-queues >/dev/null 2>&1
do
  sleep 2
done

echo "✅ LocalStack Ready"

echo "📦 Creating SQS queue..."
aws --endpoint-url=http://localstack:4566 \
  sqs create-queue \
  --queue-name analytics-queue

echo "🗄 Creating DynamoDB table..."
aws --endpoint-url=http://localstack:4566 \
  dynamodb create-table \
  --table-name ToggleMasterAnalytics \
  --attribute-definitions AttributeName=event_id,AttributeType=S \
  --key-schema AttributeName=event_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

echo "🚀 AWS resources created successfully"