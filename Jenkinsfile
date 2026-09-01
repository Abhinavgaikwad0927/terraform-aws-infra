pipeline {
    agent { label 'ec2-agent' }

    parameters {
        booleanParam(
            name: 'DESTROY_INFRASTRUCTURE',
            defaultValue: false,
            description: 'Set to TRUE to destroy all infrastructure. FALSE to create.'
        )
    }

    environment {

        AWS_REGION = "ap-south-1"

        ECR_REPOSITORY = "project-ecr"


        IMAGE_NAME = "latest"

        IMAGE_TAG = "${env.BUILD_NUMBER}"

        SSH_KEY = "/var/lib/jenkins/.ssh/jenkins.pem"

        SSH_USER = "ubuntu"
    }

    stages {

        // ─────────────────────────────────────────
        // STAGE 1 — CLONE
        // ─────────────────────────────────────────
        stage('Clone Repository') {
            steps {
                checkout scm
            }
        }

        // ─────────────────────────────────────────
// STAGE 2 — DYNAMODB TABLES
// ─────────────────────────────────────────
stage('Create DynamoDB Tables') {
    when {
        expression { return params.DESTROY_INFRASTRUCTURE == false }
    }
    steps {
        echo "============================================"
        echo " STAGE 2 — Creating DynamoDB Tables"
        echo "============================================"

        sh '''
            # ─────────────────────────────────
            # TABLE 1 — Jenkins Resource Tracker
            # ─────────────────────────────────

            TABLE_EXISTS=$(aws dynamodb list-tables \
                --region ap-south-1 \
                --query "TableNames[?@=='jenkins-resource-tracker']" \
                --output text)

            if [ -z "$TABLE_EXISTS" ]; then

                echo "Creating jenkins-resource-tracker..."

                aws dynamodb create-table \
                    --table-name jenkins-resource-tracker \
                    --attribute-definitions AttributeName=ResourceId,AttributeType=S \
                    --key-schema AttributeName=ResourceId,KeyType=HASH \
                    --billing-mode PAY_PER_REQUEST \
                    --region ap-south-1

                aws dynamodb wait table-exists \
                    --table-name jenkins-resource-tracker \
                    --region ap-south-1

                echo "jenkins-resource-tracker is ACTIVE"

            else
                echo "jenkins-resource-tracker already exists — skipping"
            fi


            # ─────────────────────────────────
            # TABLE 2 — Terraform State Lock
            # ─────────────────────────────────

            LOCK_TABLE_EXISTS=$(aws dynamodb list-tables \
                --region ap-south-1 \
                --query "TableNames[?@=='terraform-locks']" \
                --output text)

            if [ -z "$LOCK_TABLE_EXISTS" ]; then

                echo "Creating terraform-locks..."

                aws dynamodb create-table \
                    --table-name terraform-locks \
                    --attribute-definitions AttributeName=LockID,AttributeType=S \
                    --key-schema AttributeName=LockID,KeyType=HASH \
                    --billing-mode PAY_PER_REQUEST \
                    --region ap-south-1

                aws dynamodb wait table-exists \
                    --table-name terraform-locks \
                    --region ap-south-1

                echo "terraform-locks is ACTIVE"

            else
                echo "terraform-locks already exists — skipping"
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
                sh 'terraform init -reconfigure'
            }
        }

        // ─────────────────────────────────────────
        // STAGE 4 — TERRAFORM FORMAT
        // ─────────────────────────────────────────
        stage('Terraform Format Check') {
            steps {
                echo "============================================"
                echo " STAGE 4 — Terraform Format Check"
                echo "============================================"
                sh 'terraform fmt'
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
        // STAGE 7 — TERRAFORM APPLY (only if false)
        // ─────────────────────────────────────────
        stage('Terraform Apply') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
            steps {
                echo "============================================"
                echo " STAGE 7 — Terraform Apply"
                echo "============================================"
                sh 'terraform apply -auto-approve tfplan'
            }
        }
      // ─────────────────────────────────────────
        // STAGE 8 — Generate Ansible Inventory
        // ─────────────────────────────────────────
        stage('Generate Ansible Inventory') {
    when {
        expression { return params.DESTROY_INFRASTRUCTURE == false }
    }
    steps {
        sh '''
        PUBLIC_IP=$(terraform output -raw public_ip)

        cat > inventory.ini <<EOF
[servers]
$PUBLIC_IP ansible_user=ubuntu
EOF

        cat inventory.ini
        '''
    }
}
stage('Wait for EC2 SSH') {
    steps {
        sshagent(credentials: ['jenkins-ec2-ssh']) {
            sh '''
                export ANSIBLE_HOST_KEY_CHECKING=False

                echo "============================================"
                echo "Waiting for EC2 to become SSH ready"
                echo "============================================"

                for i in $(seq 1 30); do

                    echo "SSH attempt $i/30"

                    if ansible all -i inventory.ini -m ping -o; then
                        echo "============================================"
                        echo "EC2 is ready!"
                        echo "============================================"
                        exit 0
                    fi

                    echo "Waiting 10 seconds..."
                    sleep 10
                done

                echo "ERROR: EC2 did not become reachable after 5 minutes"
                exit 1
            '''
        }
    }
}

      // ─────────────────────────────────────────
        // STAGE 9 — Configure EC2 using Ansible
        // ─────────────────────────────────────────
stage('Configure EC2 using Ansible') {
    when {
        expression { return params.DESTROY_INFRASTRUCTURE == false }
    }
    steps {
        echo "============================================"
        echo " STAGE 8 — Configure EC2 using Ansible"
        echo "============================================"

        sshagent(credentials: ['jenkins-ec2-ssh']) {

            sh '''
                export ANSIBLE_HOST_KEY_CHECKING=False

                echo "Testing SSH connection..."

                ansible all \
                    -i inventory.ini \
                    -m ping

                echo "Running Ansible playbook..."

                ansible-playbook \
                    -i inventory.ini \
                    ansible/playbook.yml
            '''
        }
    }
}
stage('Get AWS Account ID') {
    steps {
        script {
            env.ACCOUNT_ID = sh(
                script: "aws sts get-caller-identity --query Account --output text",
                returnStdout: true
            ).trim()

            echo "AWS Account ID: ${env.ACCOUNT_ID}"
        }
    }
}
      
stage('Login to Amazon ECR') {

            steps {

                sh '''

                aws ecr get-login-password \
                --region ${AWS_REGION} \
                | docker login \
                --username AWS \
                --password-stdin \
                ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                '''

            }

        }
stage('Deploy Application via Ansible') {
    steps {
        sh '''
        export ANSIBLE_HOST_KEY_CHECKING=False

        ansible-playbook \
            -i inventory.ini \
            --private-key /home/ubuntu/.ssh/jenkins.pem \
            -u ubuntu \
            ansible/deploy.yml
        '''
    }
}
        stage('Get Terraform EC2 Public IP') {

            steps {

                script {

                    env.PUBLIC_IP = sh(
                        script: "terraform output -raw public_ip",
                        returnStdout: true
                    ).trim()

                    echo "Application EC2 IP : ${env.PUBLIC_IP}"

                }

            }

        }

                // ─────────────────────────────────────────
        // STAGE 10 — SAVE TO DYNAMODB (only if false)
        // ─────────────────────────────────────────
        stage('Save Resources to DynamoDB') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
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
                    echo "CREATED_AT  = $CREATED_AT"

                    python3 << PYEOF
import subprocess, json, sys

vpc_id      = "$VPC_ID"
subnet_id   = "$SUBNET_ID"
sg_id       = "$SG_ID"
instance_id = "$INSTANCE_ID"
public_ip   = "$PUBLIC_IP"
created_at  = "$CREATED_AT"
region      = "ap-south-1"
table       = "jenkins-resource-tracker"

def save(item):
    result = subprocess.run(
        ["aws", "dynamodb", "put-item",
         "--table-name", table,
         "--region", region,
         "--item", json.dumps(item)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("ERROR:", result.stderr)
        sys.exit(1)
    else:
        print("Saved:", list(item["ResourceId"].values())[0])

if vpc_id != "N/A":
    print("Saving VPC...")
    save({"ResourceId":{"S":vpc_id},"ResourceType":{"S":"VPC"},"ResourceName":{"S":"jenkins-auto-vpc"},"Region":{"S":region},"CreatedAt":{"S":created_at}})

if subnet_id != "N/A":
    print("Saving Subnet...")
    save({"ResourceId":{"S":subnet_id},"ResourceType":{"S":"Subnet"},"ResourceName":{"S":"jenkins-auto-subnet"},"VpcId":{"S":vpc_id},"Region":{"S":region},"CreatedAt":{"S":created_at}})

if sg_id != "N/A":
    print("Saving Security Group...")
    save({"ResourceId":{"S":sg_id},"ResourceType":{"S":"SecurityGroup"},"ResourceName":{"S":"jenkins-auto-sg"},"VpcId":{"S":vpc_id},"Region":{"S":region},"CreatedAt":{"S":created_at}})

if instance_id != "N/A":
    print("Saving EC2 Instance...")
    save({"ResourceId":{"S":instance_id},"ResourceType":{"S":"EC2Instance"},"ResourceName":{"S":"jenkins-auto-ec2"},"PublicIp":{"S":public_ip},"SubnetId":{"S":subnet_id},"Region":{"S":region},"CreatedAt":{"S":created_at}})

print("All resources saved to DynamoDB successfully!")
PYEOF

                    echo $PUBLIC_IP   > /tmp/public_ip.txt
                    echo $INSTANCE_ID > /tmp/instance_id.txt
                '''
            }
        }

        // ─────────────────────────────────────────
// STAGE 11 — PRINT FROM DYNAMODB (only if false)
// ─────────────────────────────────────────
stage('Print All Resources from DynamoDB') {
    when {
        expression { return params.DESTROY_INFRASTRUCTURE == false }
    }
    steps {
        echo "============================================"
        echo " STAGE 9 — Reading All Resources from DynamoDB"
        echo "============================================"

        sh '''
python3 << 'PYEOF'
import subprocess
import json
import sys

table = "jenkins-resource-tracker"
region = "ap-south-1"

result = subprocess.run(
    [
        "aws",
        "dynamodb",
        "scan",
        "--table-name",
        table,
        "--region",
        region,
        "--output",
        "json"
    ],
    capture_output=True,
    text=True
)

if result.returncode != 0:
    print(result.stderr)
    sys.exit(1)

data = json.loads(result.stdout)
items = data.get("Items", [])

print()
print("=" * 70)
print("      ALL AWS RESOURCES CREATED BY JENKINS + TERRAFORM")
print("=" * 70)
print("Total Resources :", len(items))
print("=" * 70)

order = {
    "VPC": 1,
    "Subnet": 2,
    "SecurityGroup": 3,
    "EC2Instance": 4
}

items.sort(
    key=lambda x: order.get(
        x.get("ResourceType", {}).get("S", ""),
        99
    )
)

for item in items:

    rtype = item.get("ResourceType", {}).get("S", "")
    rid = item.get("ResourceId", {}).get("S", "")
    rname = item.get("ResourceName", {}).get("S", "")
    vpc = item.get("VpcId", {}).get("S", "")
    subnet = item.get("SubnetId", {}).get("S", "")
    public = item.get("PublicIp", {}).get("S", "")
    created = item.get("CreatedAt", {}).get("S", "")

    print("-" * 70)
    print("Resource Type :", rtype)
    print("Resource ID   :", rid)
    print("Name          :", rname)

    if vpc:
        print("VPC ID        :", vpc)

    if subnet:
        print("Subnet ID     :", subnet)

    if public:
        print("Public IP     :", public)

    print("Created At    :", created)

print("-" * 70)
print("End of Resource Summary")
print("=" * 70)

PYEOF
'''
    }
}
        // ─────────────────────────────────────────
        // STAGE 12 — TERRAFORM DESTROY (only if true)
        // ─────────────────────────────────────────
        stage('Terraform Destroy') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == true }
            }
            steps {
                echo "============================================"
                echo " STAGE 10 — Destroying All Infrastructure"
                echo "============================================"
                sh '''
                    echo "DESTROY_INFRASTRUCTURE = true"
                    echo "Starting terraform destroy..."
                    terraform destroy -auto-approve
                    echo "All infrastructure destroyed successfully!"
                '''
            }
        }

        // ─────────────────────────────────────────
        // STAGE 13 — CLEAN DYNAMODB (only if true)
        // ─────────────────────────────────────────
        stage('Clean DynamoDB Records') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == true }
            }
            steps {
                echo "============================================"
                echo " STAGE 11 — Cleaning DynamoDB Records"
                echo "============================================"
                sh '''
                    python3 << PYEOF
import subprocess, json

table  = "jenkins-resource-tracker"
region = "ap-south-1"

result = subprocess.run(
    ["aws", "dynamodb", "scan",
     "--table-name", table,
     "--region", region,
     "--output", "json"],
    capture_output=True, text=True
)

data  = json.loads(result.stdout)
items = data.get("Items", [])

print(f"Found {len(items)} records to delete...")

for item in items:
    resource_id = item["ResourceId"]["S"]
    subprocess.run(
        ["aws", "dynamodb", "delete-item",
         "--table-name", table,
         "--region", region,
         "--key", json.dumps({"ResourceId": {"S": resource_id}})],
        capture_output=True, text=True
    )
    print(f"Deleted: {resource_id}")

print("DynamoDB records cleaned successfully!")
PYEOF
                '''
            }
        }
    }

    // ─────────────────────────────────────────
    // POST
    // ─────────────────────────────────────────
    post {
        success {
            script {
                if (params.DESTROY_INFRASTRUCTURE) {
                    echo "================================================="
                    echo " INFRASTRUCTURE DESTROYED SUCCESSFULLY"
                    echo " All DynamoDB records cleaned"
                    echo "================================================="
                } else {
                    sh '''
                        echo ""
                        echo "================================================="
                        echo "       PIPELINE COMPLETED SUCCESSFULLY"
                        echo "================================================="
                        echo "  EC2 Public IP  : $(cat /tmp/public_ip.txt 2>/dev/null || echo N/A)"
                        echo "  EC2 Instance   : $(cat /tmp/instance_id.txt 2>/dev/null || echo N/A)"
                        echo "  DynamoDB Table : jenkins-resource-tracker"
                        echo "  Region         : ap-south-1"
                        echo "================================================="
                    '''
                }
            }
        }
        failure {
            echo "Pipeline FAILED — check the stage that errored above"
        }
    }
}
