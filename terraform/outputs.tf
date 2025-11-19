output "ecr_repository_url" {
  value = module.ecr.repository_url
  description = "Full repository URI (account.dkr.ecr.<region>.amazonaws.com/repo)"
}


output "jenkins_output_file" {
  value = local_file.jenkins_outputs.filename
  description = "Path to the generated JSON file containing ECR details for Jenkins"
}