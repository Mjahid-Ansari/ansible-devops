0. Create one Folder
0. Inside that folder create one file (main.tf)

0. Create IAM User and also Create Access-Key
0. Copy Access-id and Secret-id 
0.Configure AWS CLI Using
        aws configure
        paste Access-id
        paste Secret-id
        paste region-name
        paste Json

1. Command for initializing the project -->
 
        terrform init

2. Commmand for formatting the main.tf code -->

        terraform fmt

3. Command for validating our code --> 

        terraform validate

4. Command for checking plan --> 

        terraform plan

5. Command for applying valid plan --> 

        terraform apply

6. Command for showing result of applying --> 

        terraform show (public-ip:- 3.231.206.20/2137_barista_cafe/)

7. Command for removing the provisioned infrastructure --> 

        terraform destroy
