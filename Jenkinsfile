pipeline {
    agent { label 'ec2-agent' }

    environment {
        REGION          = 'ap-south-1'
        DYNAMO_TABLE    = 'jenkins-resource-tracker'
        RESOURCE_PREFIX = 'jenkins-auto'
    }

    stages {

        // ─────────────────────────────────────────
        // STAGE 1 — CLONE REPOSITORY
        // ─────────────────────────────────────────
        stage('Clone Repository') {
            steps {
                checkout scm
            }
        }

        // ─────────────────────────────────────────
        // STAGE 2 — CREATE DYNAMODB TABLE
        // ─────────────────────────────────────────
        stage('Create DynamoDB Table') {
            steps {
                echo "============================================"
                echo " STAGE 2 — Creating DynamoDB Table"
                echo "============================================"
                sh '''
                    TABLE_EXISTS=$(aws dynamodb list-tables \
                        --region $REGION \
                        --query "TableNames[?@=='$DYNAMO_TABLE']" \
                        --output text)

                    if [ -z "$TABLE_EXISTS" ]; then
                        echo "Creating DynamoDB table: $DYNAMO_TABLE"

                        aws dynamodb create-table \
                            --table-name $DYNAMO_TABLE \
                            --attribute-definitions \
                                AttributeName=ResourceId,AttributeType=S \
                            --key-schema \
                                AttributeName=ResourceId,KeyType=HASH \
                            --billing-mode PAY_PER_REQUEST \
                            --region $REGION

                        echo "Waiting for table to become ACTIVE..."

                        aws dynamodb wait table-exists \
                            --table-name $DYNAMO_TABLE \
                            --region $REGION

                        echo "DynamoDB Table ACTIVE: $DYNAMO_TABLE"
                    else
                        echo "Table already exists: $DYNAMO_TABLE — skipping"
                    fi
                '''
            }
        }

        // ─────────────────────────────────────────
        // STAGE 3 — TERRAFORM INIT
        // ─────────────────────────────────────────
        stage('Terraform Init') {
            steps {
                echo "============================================"
                echo " STAGE 3 — Terraform Init"
                echo "============================================"
                sh 'terraform init'
            }
        }

        stage('Terraform Format Check') {
    steps {
        echo "============================================"
        echo " STAGE 4 — Terraform Format Check"
        echo "============================================"
        sh 'terraform fmt'               // ← auto fixes and continues
    }
}

        // ─────────────────────────────────────────
        // STAGE 5 — TERRAFORM VALIDATE
        // ─────────────────────────────────────────
        stage('Terraform Validate') {
            steps {
                echo "============================================"
                echo " STAGE 5 — Terraform Validate"
                echo "============================================"
                sh 'terraform validate'
            }
        }

        // ─────────────────────────────────────────
        // STAGE 6 — TERRAFORM PLAN
        // ─────────────────────────────────────────
        stage('Terraform Plan') {
            steps {
                echo "============================================"
                echo " STAGE 6 — Terraform Plan"
                echo "============================================"
                sh 'terraform plan -out=tfplan'
            }
        }

        // ─────────────────────────────────────────
        // STAGE 7 — TERRAFORM APPLY
        // ─────────────────────────────────────────
        stage('Terraform Apply') {
            steps {
                echo "============================================"
                echo " STAGE 7 — Terraform Apply"
                echo "============================================"
                sh 'terraform apply -auto-approve tfplan'
            }
        }

        // ─────────────────────────────────────────
        // STAGE 8 — SAVE RESOURCES TO DYNAMODB
        // ─────────────────────────────────────────
        stage('Save Resources to DynamoDB') {
            steps {
                echo "============================================"
                echo " STAGE 8 — Saving Resources to DynamoDB"
                echo "============================================"
                sh '''
                    # Get VPC ID from terraform output
                    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "N/A")
                    SUBNET_ID=$(terraform output -raw subnet_id 2>/dev/null || echo "N/A")
                    IGW_ID=$(terraform output -raw igw_id 2>/dev/null || echo "N/A")
                    SG_ID=$(terraform output -raw security_group_id 2>/dev/null || echo "N/A")
                    INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "N/A")
                    PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "N/A")
                    PRIVATE_IP=$(terraform output -raw private_ip 2>/dev/null || echo "N/A")

                    echo "Saving VPC to DynamoDB..."
                    if [ "$VPC_ID" != "N/A" ]; then
                        aws dynamodb put-item \
                            --table-name $DYNAMO_TABLE \
                            --item "{
                                \"ResourceId\":   {\"S\": \"$VPC_ID\"},
                                \"ResourceType\": {\"S\": \"VPC\"},
                                \"ResourceName\": {\"S\": \"$RESOURCE_PREFIX-vpc\"},
                                \"Region\":       {\"S\": \"$REGION\"},
                                \"CreatedAt\":    {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
                            }" \
                            --region $REGION
                        echo "VPC saved: $VPC_ID"
                    fi

                    echo "Saving Subnet to DynamoDB..."
                    if [ "$SUBNET_ID" != "N/A" ]; then
                        aws dynamodb put-item \
                            --table-name $DYNAMO_TABLE \
                            --item "{
                                \"ResourceId\":   {\"S\": \"$SUBNET_ID\"},
                                \"ResourceType\": {\"S\": \"Subnet\"},
                                \"ResourceName\": {\"S\": \"$RESOURCE_PREFIX-subnet\"},
                                \"VpcId\":        {\"S\": \"$VPC_ID\"},
                                \"Region\":       {\"S\": \"$REGION\"},
                                \"CreatedAt\":    {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
                            }" \
                            --region $REGION
                        echo "Subnet saved: $SUBNET_ID"
                    fi

                    echo "Saving Internet Gateway to DynamoDB..."
                    if [ "$IGW_ID" != "N/A" ]; then
                        aws dynamodb put-item \
                            --table-name $DYNAMO_TABLE \
                            --item "{
                                \"ResourceId\":   {\"S\": \"$IGW_ID\"},
                                \"ResourceType\": {\"S\": \"InternetGateway\"},
                                \"ResourceName\": {\"S\": \"$RESOURCE_PREFIX-igw\"},
                                \"VpcId\":        {\"S\": \"$VPC_ID\"},
                                \"Region\":       {\"S\": \"$REGION\"},
                                \"CreatedAt\":    {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
                            }" \
                            --region $REGION
                        echo "Internet Gateway saved: $IGW_ID"
                    fi

                    echo "Saving Security Group to DynamoDB..."
                    if [ "$SG_ID" != "N/A" ]; then
                        aws dynamodb put-item \
                            --table-name $DYNAMO_TABLE \
                            --item "{
                                \"ResourceId\":   {\"S\": \"$SG_ID\"},
                                \"ResourceType\": {\"S\": \"SecurityGroup\"},
                                \"ResourceName\": {\"S\": \"$RESOURCE_PREFIX-sg\"},
                                \"VpcId\":        {\"S\": \"$VPC_ID\"},
                                \"Region\":       {\"S\": \"$REGION\"},
                                \"CreatedAt\":    {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
                            }" \
                            --region $REGION
                        echo "Security Group saved: $SG_ID"
                    fi

                    echo "Saving EC2 Instance to DynamoDB..."
                    if [ "$INSTANCE_ID" != "N/A" ]; then
                        aws dynamodb put-item \
                            --table-name $DYNAMO_TABLE \
                            --item "{
                                \"ResourceId\":   {\"S\": \"$INSTANCE_ID\"},
                                \"ResourceType\": {\"S\": \"EC2Instance\"},
                                \"ResourceName\": {\"S\": \"$RESOURCE_PREFIX-ec2\"},
                                \"PublicIp\":     {\"S\": \"$PUBLIC_IP\"},
                                \"PrivateIp\":    {\"S\": \"$PRIVATE_IP\"},
                                \"SubnetId\":     {\"S\": \"$SUBNET_ID\"},
                                \"Region\":       {\"S\": \"$REGION\"},
                                \"CreatedAt\":    {\"S\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}
                            }" \
                            --region $REGION
                        echo "EC2 Instance saved: $INSTANCE_ID"
                    fi

                    # Save IPs to temp files for post section
                    echo $PUBLIC_IP  > /tmp/public_ip.txt
                    echo $PRIVATE_IP > /tmp/private_ip.txt
                    echo $INSTANCE_ID > /tmp/instance_id.txt
                '''
            }
        }

        // ─────────────────────────────────────────
        // STAGE 9 — PRINT ALL FROM DYNAMODB
        // ─────────────────────────────────────────
        stage('Print All Resources from DynamoDB') {
            steps {
                echo "============================================"
                echo " STAGE 9 — Reading All Resources from DynamoDB"
                echo "============================================"
                sh '''
                    aws dynamodb scan \
                        --table-name $DYNAMO_TABLE \
                        --region $REGION \
                        --output json | python3 -c "
import json, sys

data = json.load(sys.stdin)
items = data[\"Items\"]

print()
print(\"*\" * 60)
print(\"    ALL AWS RESOURCES CREATED BY JENKINS + TERRAFORM\")
print(\"*\" * 60)
print(f\"  Total Resources : {len(items)}\")
print(\"*\" * 60)

order = [\"VPC\",\"Subnet\",\"InternetGateway\",\"SecurityGroup\",\"EC2Instance\"]
sorted_items = sorted(
    items,
    key=lambda x: order.index(x.get(\"ResourceType\",{}).get(\"S\",\"\"))
    if x.get(\"ResourceType\",{}).get(\"S\",\"\") in order else 99
)

for item in sorted_items:
    rtype = item.get(\"ResourceType\", {}).get(\"S\", \"Unknown\")
    rid   = item.get(\"ResourceId\",   {}).get(\"S\", \"N/A\")
    rname = item.get(\"ResourceName\", {}).get(\"S\", \"N/A\")
    pub   = item.get(\"PublicIp\",     {}).get(\"S\", \"\")
    priv  = item.get(\"PrivateIp\",    {}).get(\"S\", \"\")
    vpc   = item.get(\"VpcId\",        {}).get(\"S\", \"\")
    ts    = item.get(\"CreatedAt\",    {}).get(\"S\", \"\")

    print()
    print(f\"  Resource Type  : {rtype}\")
    print(f\"  Resource ID    : {rid}\")
    print(f\"  Resource Name  : {rname}\")
    if vpc:  print(f\"  VPC ID         : {vpc}\")
    if pub:  print(f\"  Public IP      : {pub}  <--- EC2 PUBLIC IP\")
    if priv: print(f\"  Private IP     : {priv}  <--- EC2 PRIVATE IP\")
    print(f\"  Created At     : {ts}\")
    print(\"-\" * 60)

print()
print(\"*\" * 60)
print(\"            END OF RESOURCE SUMMARY\")
print(\"*\" * 60)
print()
"
                '''
            }
        }
    }

    // ─────────────────────────────────────────
    // POST — FINAL SUMMARY + CLEANUP
    // ─────────────────────────────────────────
    post {
        success {
            sh '''
                echo ""
                echo "================================================="
                echo "       PIPELINE COMPLETED SUCCESSFULLY"
                echo "================================================="
                echo "  EC2 Public IP  : $(cat /tmp/public_ip.txt)"
                echo "  EC2 Private IP : $(cat /tmp/private_ip.txt)"
                echo "  EC2 Instance   : $(cat /tmp/instance_id.txt)"
                echo "  DynamoDB Table : $DYNAMO_TABLE"
                echo "  Region         : $REGION"
                echo "================================================="
            '''
        }
        failure {
            echo "Pipeline FAILED — check the stage that errored above"
        }
        always {
            cleanWs()
        }
    }
}

