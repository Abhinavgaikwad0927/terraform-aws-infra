pipeline {
    agent { label 'ec2-agent' }

    environment {
        REGION          = 'ap-south-1'
        DYNAMO_TABLE    = 'jenkins-resource-tracker'
        RESOURCE_PREFIX = 'jenkins-auto'
    }

    stages {

        stage('Clone Repository') {
            steps {
                checkout scm
            }
        }

        stage('Create DynamoDB Table') {
            steps {
                echo "============================================"
                echo " STAGE 2 — Creating DynamoDB Table"
                echo "============================================"
                sh '''
                    TABLE_EXISTS=$(aws dynamodb list-tables \
                        --region ap-south-1 \
                        --query "TableNames[?@=='jenkins-resource-tracker']" \
                        --output text)

                    if [ -z "$TABLE_EXISTS" ]; then
                        echo "Creating DynamoDB table..."
                        aws dynamodb create-table \
                            --table-name jenkins-resource-tracker \
                            --attribute-definitions AttributeName=ResourceId,AttributeType=S \
                            --key-schema AttributeName=ResourceId,KeyType=HASH \
                            --billing-mode PAY_PER_REQUEST \
                            --region ap-south-1

                        aws dynamodb wait table-exists \
                            --table-name jenkins-resource-tracker \
                            --region ap-south-1

                        echo "DynamoDB Table ACTIVE"
                    else
                        echo "Table already exists — skipping"
                    fi
                '''
            }
        }

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
                sh 'terraform fmt'
            }
        }

        stage('Terraform Validate') {
            steps {
                echo "============================================"
                echo " STAGE 5 — Terraform Validate"
                echo "============================================"
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                echo "============================================"
                echo " STAGE 6 — Terraform Plan"
                echo "============================================"
                sh 'terraform plan -out=tfplan'
            }
        }

        stage('Terraform Apply') {
            steps {
                echo "============================================"
                echo " STAGE 7 — Terraform Apply"
                echo "============================================"
                sh 'terraform apply -auto-approve tfplan'
            }
        }

        stage('Save Resources to DynamoDB') {
            steps {
                echo "============================================"
                echo " STAGE 8 — Saving Resources to DynamoDB"
                echo "============================================"
                sh '''
                    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "N/A")
                    SUBNET_ID=$(terraform output -raw subnet_id 2>/dev/null || echo "N/A")
                    SG_ID=$(terraform output -raw security_group_id 2>/dev/null || echo "N/A")
                    INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "N/A")
                    PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "N/A")
                    CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

                    echo "VPC_ID      = $VPC_ID"
                    echo "SUBNET_ID   = $SUBNET_ID"
                    echo "SG_ID       = $SG_ID"
                    echo "INSTANCE_ID = $INSTANCE_ID"
                    echo "PUBLIC_IP   = $PUBLIC_IP"

                    if [ "$VPC_ID" != "N/A" ]; then
                        echo "Saving VPC to DynamoDB..."
                        aws dynamodb put-item \
                            --table-name jenkins-resource-tracker \
                            --region ap-south-1 \
                            --item "{\"ResourceId\":{\"S\":\"$VPC_ID\"},\"ResourceType\":{\"S\":\"VPC\"},\"ResourceName\":{\"S\":\"jenkins-auto-vpc\"},\"Region\":{\"S\":\"ap-south-1\"},\"CreatedAt\":{\"S\":\"$CREATED_AT\"}}"
                        echo "VPC saved: $VPC_ID"
                    fi

                    if [ "$SUBNET_ID" != "N/A" ]; then
                        echo "Saving Subnet to DynamoDB..."
                        aws dynamodb put-item \
                            --table-name jenkins-resource-tracker \
                            --region ap-south-1 \
                            --item "{\"ResourceId\":{\"S\":\"$SUBNET_ID\"},\"ResourceType\":{\"S\":\"Subnet\"},\"ResourceName\":{\"S\":\"jenkins-auto-subnet\"},\"VpcId\":{\"S\":\"$VPC_ID\"},\"Region\":{\"S\":\"ap-south-1\"},\"CreatedAt\":{\"S\":\"$CREATED_AT\"}}"
                        echo "Subnet saved: $SUBNET_ID"
                    fi

                    if [ "$SG_ID" != "N/A" ]; then
                        echo "Saving Security Group to DynamoDB..."
                        aws dynamodb put-item \
                            --table-name jenkins-resource-tracker \
                            --region ap-south-1 \
                            --item "{\"ResourceId\":{\"S\":\"$SG_ID\"},\"ResourceType\":{\"S\":\"SecurityGroup\"},\"ResourceName\":{\"S\":\"jenkins-auto-sg\"},\"VpcId\":{\"S\":\"$VPC_ID\"},\"Region\":{\"S\":\"ap-south-1\"},\"CreatedAt\":{\"S\":\"$CREATED_AT\"}}"
                        echo "Security Group saved: $SG_ID"
                    fi

                    if [ "$INSTANCE_ID" != "N/A" ]; then
                        echo "Saving EC2 Instance to DynamoDB..."
                        aws dynamodb put-item \
                            --table-name jenkins-resource-tracker \
                            --region ap-south-1 \
                            --item "{\"ResourceId\":{\"S\":\"$INSTANCE_ID\"},\"ResourceType\":{\"S\":\"EC2Instance\"},\"ResourceName\":{\"S\":\"jenkins-auto-ec2\"},\"PublicIp\":{\"S\":\"$PUBLIC_IP\"},\"SubnetId\":{\"S\":\"$SUBNET_ID\"},\"Region\":{\"S\":\"ap-south-1\"},\"CreatedAt\":{\"S\":\"$CREATED_AT\"}}"
                        echo "EC2 saved: $INSTANCE_ID"
                    fi

                    echo $PUBLIC_IP   > /tmp/public_ip.txt
                    echo $INSTANCE_ID > /tmp/instance_id.txt
                    echo "All resources saved to DynamoDB successfully!"
                '''
            }
        }

        stage('Print All Resources from DynamoDB') {
            steps {
                echo "============================================"
                echo " STAGE 9 — Reading All Resources from DynamoDB"
                echo "============================================"
                sh '''
                    aws dynamodb scan \
                        --table-name jenkins-resource-tracker \
                        --region ap-south-1 \
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
    if priv: print(f\"  Private IP     : {priv}\")
    print(f\"  Created At     : {ts}\")
    print(\"-\" * 60)

print()
print(\"*\" * 60)
print(\"         END OF RESOURCE SUMMARY\")
print(\"*\" * 60)
print()
"
                '''
            }
        }
    }

    post {
        success {
            sh '''
                echo ""
                echo "================================================="
                echo "       PIPELINE COMPLETED SUCCESSFULLY"
                echo "================================================="
                echo "  EC2 Public IP  : $(cat /tmp/public_ip.txt)"
                echo "  EC2 Instance   : $(cat /tmp/instance_id.txt)"
                echo "  DynamoDB Table : jenkins-resource-tracker"
                echo "  Region         : ap-south-1"
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
