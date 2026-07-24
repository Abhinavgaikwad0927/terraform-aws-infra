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
        REGION          = 'ap-south-1'
        DYNAMO_TABLE    = 'jenkins-resource-tracker'
        RESOURCE_PREFIX = 'jenkins-auto'
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
        // STAGE 2 — DYNAMODB TABLE
        // ─────────────────────────────────────────
        stage('Create DynamoDB Table') {
            when {
                expression { return params.DESTROY_INFRASTRUCTURE == false }
            }
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
stage('Debug Pipeline Environment') {
    steps {
        sh '''
        echo "===== USER ====="
        whoami
        id

        echo "===== HOME ====="
        echo $HOME

        echo "===== SSH ====="
        which ssh

        echo "===== KEY ====="
        ls -l /home/ubuntu/.ssh/
        ls -l /home/ubuntu/.ssh/jenkins.pem

        echo "===== PUBLIC IP ====="
        terraform output -raw public_ip

        PUBLIC_IP=$(terraform output -raw public_ip)

        echo "===== SSH TEST ====="
        ssh -vvv \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -i /home/ubuntu/.ssh/jenkins.pem \
          ubuntu@$PUBLIC_IP "hostname"

        echo "Exit Code: $?"
        '''
    }
}
stage('Wait for SSH') {
    when {
        expression { return params.DESTROY_INFRASTRUCTURE == false }
    }
    steps {
        sh '''
        PUBLIC_IP=$(terraform output -raw public_ip)

        echo "Waiting for SSH on $PUBLIC_IP..."

        i=1
        while [ $i -le 30 ]
        do
            if ssh \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -i /home/ubuntu/.ssh/jenkins.pem \
                ubuntu@$PUBLIC_IP "echo SSH Ready" >/dev/null 2>&1
            then
                echo "SSH is ready!"
                exit 0
            fi

            echo "Attempt $i/30 - SSH not ready yet..."
            sleep 10
            i=$((i+1))
        done

        echo "SSH did not become available after 5 minutes."
        exit 1
        '''
    }
}
stage('Debug SSH Environment') {
    steps {
        sh '''
        whoami
        pwd
        ls -l /home/ubuntu/.ssh/
        which ssh
        ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -i /home/ubuntu/.ssh/jenkins.pem \
            ubuntu@$(terraform output -raw public_ip) "hostname"
        '''
    }
}
stage('Configure EC2 using Ansible') {
    when {
        expression { return params.DESTROY_INFRASTRUCTURE == false }
    }
    steps {
        sh '''
        export ANSIBLE_HOST_KEY_CHECKING=False

        ansible-playbook \
          -i inventory.ini \
          --private-key /home/ubuntu/.ssh/jenkins.pem \
          -u ubuntu \
          ansible/playbook.yml
        '''
    }
}
        // ─────────────────────────────────────────
        // STAGE 8 — SAVE TO DYNAMODB (only if false)
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
// STAGE 9 — PRINT FROM DYNAMODB (only if false)
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
        // STAGE 10 — TERRAFORM DESTROY (only if true)
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
        // STAGE 11 — CLEAN DYNAMODB (only if true)
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
