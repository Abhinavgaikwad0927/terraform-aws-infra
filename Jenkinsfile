pipeline {

    agent any

    stages {

        stage('Clone') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Format Check') {
            steps {
                sh 'terraform fmt -check'
            }
        }

        stage('Plan') {
            steps {
                sh 'terraform plan'
            }
        }

        stage('Apply') {
            steps {
                input "Deploy Infrastructure?"
                sh 'terraform apply -auto-approve'
            }
        }
	stage('Destroy') {
   	    steps {
        	input "Destroy Infrastructure?"
       		 sh 'terraform destroy -auto-approve'
    	   }
	}

    }

}
