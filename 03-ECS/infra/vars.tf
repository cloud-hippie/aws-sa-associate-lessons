variable "aws_region" {
  default = "us-east-1"
}

variable "api_name" {
    default = "cloud-hippie-api"
    description = "The name of the API you want to deploy"
}

variable "api_version" {
    description = "The version of the API you want to deploy"
}

variable "image_name" {
    default = "docker.io/hippie/cloud-hippie-api"
    description = "The name of the image you want to use"
}

variable "api_port" {
    default = 3000
    description = "The port you want to use"
}

variable "cpu" {
    default = 256
    description = "The CPU you want to use"
}

variable "memory" {
    default = 512
    description = "The memory you want to use"
}