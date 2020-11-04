output "created" {
  value = null_resource.ig.id
}

// ID of the AWS autoscaling group corresponding to this kops instance group
output "asg-name" {
  value = element(data.aws_autoscaling_groups.ig.names, 0)
}

output "spec-template" {
  value = yamldecode(data.template_file.ig-spec.rendered)
}

output "spec-var" {
  value = local.ig_spec
}
